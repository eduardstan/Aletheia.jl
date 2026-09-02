using Aqua
using JET
using Supposition
using Test
using AletheiaCore
using AletheiaAudit
using AletheiaNeSy

"A fixed two-input one-layer network used as a transparent reference."
struct FixedMLP
    weights::NTuple{2,Float64}
    bias::Float64
end
function (m::FixedMLP)(x::Tuple{<:Real,<:Real})
    return m.weights[1] * x[1] + m.weights[2] * x[2] + m.bias > 0
end

mlp = FixedMLP((1.0, -1.0), 0.0)
encoder = (atom, x) -> x
valuation = neural_valuation(mlp, encoder; algebra=BOOLEAN)

@testset "neural leaves are differential in scalar and batch modes" begin
    @test valuation(:p, (0.0, 0.0)) == mlp((0.0, 0.0))
    @test valuation.vectorized(:p, [(1.0, -1.0), (-1.0, 1.0)]) ==
          [mlp((1.0, -1.0)), mlp((-1.0, 1.0))]
    @check function direct_network_property(
        a=Supposition.Data.Integers{Int8}(), b=Supposition.Data.Integers{Int8}()
    )
        x = (Float64(a), Float64(b))
        return valuation(:p, x) == mlp(x) && valuation.vectorized(:p, [x])[1] == mlp(x)
    end
end

@testset "known finite rule set round trip" begin
    domain = [(a, b) for a in (-1.0, 0.0, 1.0, 2.0) for b in (-1.0, 0.0, 1.0, 2.0)]
    cases = [
        ArtifactCase(x, nothing, mlp(x), iseven(i) ? :global : :local) for
        (i, x) in enumerate(domain)
    ]
    artifact = extract_artifact(
        mlp,
        cases;
        encoder=encoder,
        artifact=RuleArtifact,
        provenance=Provenance(;
            versions=(model=1,), sources=(test=true,), hashes=(model="fixed",)
        ),
    )
    known = [ArtifactRule(x, mlp(x)) for x in domain]
    @test artifact isa RuleArtifact
    @test rules(artifact) == known
    roundtrip = ske_roundtrip(mlp, encoder, cases)
    @test roundtrip.verification.valid
    @test roundtrip.metrics.fidelity.numerator == length(domain)
    @test roundtrip.metrics.fidelity.denominator == length(domain)
    @test roundtrip.metrics.fidelity.value == 1.0
    @test roundtrip.metrics.coverage.numerator == length(domain)
    @test roundtrip.metrics.coverage.denominator == length(domain)
    @test roundtrip.metrics.coverage.scope == :all
end

@testset "independent predictor and perturbations" begin
    fixed = [(1.0, 0.2), (0.2, 1.0), (-0.5, -0.25)]
    perturbations = [(x[1] + d, x[2] - d) for x in fixed for d in (-0.1, 0.1)]
    cases = [ArtifactCase(x, nothing, mlp(x), :global) for x in vcat(fixed, perturbations)]
    artifact = extract_artifact(mlp, cases; encoder=encoder)
    @test all(eval_artifact(artifact, x)[1] == mlp(x) for x in vcat(fixed, perturbations))
end

@testset "validation and not-applicable results" begin
    bad = neural_valuation(x -> 2, identity; algebra=BOOLEAN)
    @test_throws InvalidNeuralValueError bad(:p, 1)
    @test_throws MalformedCaseError ske_roundtrip(mlp, encoder, nothing)
    @test_throws MalformedCaseError ske_roundtrip(mlp, encoder, [(; state=1)])
    @test_throws ChoiceLabelError neural_choice_labels(
        x -> [0, 0], identity; profile=(finite=true,)
    )
    artifact = extract_artifact(mlp, [(-1.0, -1.0)]; encoder=encoder)
    unknown = eval_artifact(artifact, (100.0, 100.0))[1]
    @test unknown === missing
    metrics = metric_bundle(
        artifact, [ArtifactCase((100.0, 100.0), nothing, false, :global)]
    )
    @test !metrics.coverage.applicable
    @test metrics.coverage.value === missing
    @test !metrics.fidelity.applicable
end

@testset "traces, deterministic serialization, and interface laws" begin
    artifact = TreeArtifact([:yes => true, :no => false])
    for state in (:yes, :no, :other)
        output, trace = eval_artifact(artifact, state)
        replayed = replay(deserialize_trace(serialize_trace(trace)), state)
        @test replayed.valid
        @test isequal(replayed.claims.reported_result, output)
        tampered = ExecutionTrace(
            trace.steps,
            trace.provenance,
            !isequal(output, true),
            trace.input_hash,
            trace.output_hash,
            trace.scope,
        )
        @test !replay(tampered, state).valid
    end
    @test test_interface(RuleArtifact; artifact=RuleArtifact([1 => true]), cases=[1])
    @test test_interface(TreeArtifact; artifact=artifact, cases=[:yes, :no])
end

@testset "metric algebra properties" begin
    @check function metric_property(
        n=Supposition.Data.Integers{Int8}(), d=Supposition.Data.Integers{Int8}()
    )
        denominator = abs(Int(d)) % 10 + 1
        numerator = abs(Int(n)) % (denominator + 1)
        metric = MetricValue(numerator / denominator, numerator, denominator, :local, true)
        return metric.numerator <= metric.denominator &&
               metric.applicable &&
               metric.denominator > 0 &&
               metric.scope == :local
    end
end

@testset "neural contract edge paths" begin
    @test sprint(showerror, NeSyContractError(:encoder, "bad")) == "encoder: bad"
    @test occursin(
        "invalid neural truth value",
        sprint(showerror, InvalidNeuralValueError(:x, BOOLEAN)),
    )
    @test sprint(showerror, MalformedCaseError("bad")) == "malformed cases: bad"
    @test occursin("semantic loss requires", sprint(showerror, SemanticLossError(:x)))
    @test sprint(showerror, ChoiceLabelError("bad")) == "neural choice labels: bad"
    bad_encoder = neural_valuation(x -> true, (x, y) -> y; algebra=BOOLEAN)
    @test bad_encoder(:p, true)
    @test neural_valuation(
        x -> x, identity; algebra=BOOLEAN, vectorized=false
    ).vectorized === nothing
    thresholded = neural_valuation(x -> 0.75, identity; algebra=BOOLEAN, threshold=0.5)
    @test thresholded(:p, 1)
    @test_throws NeSyContractError neural_valuation(
        identity, (x, y, z) -> x; algebra=BOOLEAN
    )(
        :p, 1
    )
    @test neural_choice_labels(() -> [1, 3], nothing; profile=(finite=true,)) ==
          [0.25, 0.75]
    @test neural_choice_labels(
        () -> (1, 1), nothing; profile=Dict(:finite => true, :choices => [:out])
    )[:out] == [0.5, 0.5]
    @test neural_choice_labels(
        () -> Dict(:a => [1, 1], :b => (2, 2)), nothing; profile=(finite=true,)
    )[:b] == [0.5, 0.5]
    @test neural_choice_labels(() -> [1, 2], nothing; profile=:finite) == [1 / 3, 2 / 3]
    @test_throws ChoiceLabelError neural_choice_labels(
        () -> Dict(), nothing; profile=(finite=true,)
    )
    @test_throws ChoiceLabelError neural_choice_labels(
        () -> [1, 2], nothing; profile=(finite=true, choices=[:a, :b])
    )
    @test_throws ChoiceLabelError neural_choice_labels(
        () -> [1, -1], nothing; profile=(finite=true,)
    )
    @test_throws ChoiceLabelError neural_choice_labels(
        () -> [], nothing; profile=(finite=true,)
    )
    @test_throws ChoiceLabelError neural_choice_labels(
        () -> 1, nothing; profile=(finite=true,)
    )
    @test neural_choice_labels(x -> [1, 1], x -> x; profile=(finite=true,)) == [0.5, 0.5]
    @test_throws MalformedCaseError ske_roundtrip(mlp, encoder, ())
    @test_throws MalformedCaseError ske_roundtrip(mlp, encoder, [])
    named_cases = [(input=(1.0, 0.0), state=(1.0, 0.0), oracle_output=true, scope=:local)]
    @test ske_roundtrip(mlp, encoder, named_cases).verification.valid
    @test_throws SemanticLossError semantic_loss(
        atom(:p), valuation; algebra=BOOLEAN, gradient_profile=:disabled
    )
end

@testset "round trips share overloaded encoder dispatch" begin
    encoder(x::Symbol) = 1
    encoder(a, x::Symbol) = 2
    network(x) = x == 1
    result = ske_roundtrip(network, encoder, [:case])
    @test result.extracted(:case) == false
    @test result.verification.valid
end

@testset "AletheiaNeSy quality" begin
    Aqua.test_all(AletheiaNeSy)
    JET.test_package(
        AletheiaNeSy; target_modules=(AletheiaNeSy,), analyze_from_definitions=true
    )
end
