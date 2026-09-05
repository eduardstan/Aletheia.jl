using Aqua
using JET
using Supposition
using Test
using AletheiaAudit
using AletheiaCore

struct UnsupportedAuditArtifact <: SymbolicArtifact end

struct AuditCopyProbe
    value::Int
end
mutable struct MutableAuditPayload
    value::Int
end
const AUDIT_COPY_PROBES = Ref(0)
function Base.deepcopy_internal(value::AuditCopyProbe, ::IdDict)
    AUDIT_COPY_PROBES[] += 1
    return value
end

@testset "typed artifact protocol" begin
    @test test_interface(RuleArtifact)
    @test test_interface(TreeArtifact)
    rule = RuleArtifact([1 => :one, 2 => :two])
    tree = TreeArtifact([1 => :one, 2 => :two])
    for artifact in (rule, tree)
        for state in (1, 2, 3)
            output, trace = eval_artifact(artifact, state; profile=:exact)
            restored = deserialize_trace(serialize_trace(trace))
            @test replay(restored, state; profile=:exact).valid
            @test isequal(restored.reported_result, output)
            tampered = ExecutionTrace(
                trace.steps,
                trace.provenance,
                :tampered,
                trace.input_hash,
                trace.output_hash,
                trace.scope,
            )
            @test !replay(tampered, state).valid
        end
    end
    @test test_interface(RuleArtifact; artifact=rule, cases=[1, 2, 3])
    @test test_interface(rule, [1, 2, 3])
end

@testset "metrics retain population semantics" begin
    artifact = RuleArtifact([:a => true])
    cases = [
        ArtifactCase(:a, nothing, true, :global),
        ArtifactCase(:b, nothing, false, :global),
        ArtifactCase(:a, nothing, true, :local),
    ]
    global_metrics = metric_bundle(artifact, cases; scope=:global)
    @test global_metrics.fidelity.numerator == 1
    @test global_metrics.fidelity.denominator == 2
    @test global_metrics.fidelity.value == 0.5
    @test global_metrics.coverage.numerator == 1
    @test global_metrics.coverage.denominator == 2
    @test global_metrics.coverage.scope == :global
    @test global_metrics.constraints.value === missing
    @test global_metrics.trace_validity.applicable
    @test global_metrics.trace_completeness.denominator == 2
    unknown = metric_bundle(artifact, [ArtifactCase(:z, nothing, missing, :global)])
    @test unknown.coverage.value === missing
    @test !unknown.coverage.applicable
    @check function metric_algebra(
        n=Supposition.Data.Integers{Int8}(), d=Supposition.Data.Integers{Int8}()
    )
        denominator = abs(Int(d)) % 9 + 1
        numerator = abs(Int(n)) % (denominator + 1)
        value = MetricValue(numerator / denominator, numerator, denominator, :local, true)
        return value.numerator <= value.denominator &&
               value.applicable &&
               value.denominator > 0 &&
               value.scope == :local
    end
end

@testset "fidelity includes uncovered selected cases" begin
    rule = ArtifactRule(s -> haskey(s, :p) && s[:p], true)
    artifact = RuleArtifact([rule]; default=missing)
    cases = [ArtifactCase(:in, Dict(:p => false), true) for _ in 1:9]
    push!(cases, ArtifactCase(:in, Dict(:p => true), true))
    metrics = metric_bundle(artifact, cases)
    @test metrics.fidelity.numerator == 1
    @test metrics.fidelity.denominator == 10
    @test metrics.coverage.numerator == 1
    @test metrics.coverage.denominator == 10
end

@testset "verification, audit rendering, and injection" begin
    artifact = RuleArtifact([1 => true]; default=false)
    cases = [ArtifactCase(1, true), ArtifactCase(2, false)]
    verified = verify_artifact(artifact, cases)
    @test verified.valid
    @test verified.claims.applicability == [true, true]
    failed = verify_artifact(artifact, [ArtifactCase(1, false)])
    @test !failed.valid
    record = audit(
        artifact,
        cases;
        provenance=Provenance(; versions=(model=1,), sources=(:test,), hashes=(:x,)),
    )
    io = IOBuffer()
    @test audit(record, io) === record
    @test occursin("AuditRecord", String(take!(io)))
    target = Any[]
    @test inject!(target, artifact; mode=:hard) === target
    @test inject!(target, artifact; mode=:soft, weight=0.5) === target
    @test_throws ArgumentError inject!(target, artifact; mode=:invalid)
    @test_throws ArgumentError inject!(nothing, artifact)
end

@testset "protocol edge paths" begin
    @test ArtifactCase(:x, :state, :out; scope=:local).scope == :local
    @test_throws ArgumentError ArtifactCase(:x, nothing, :out; scope=:bad)
    @test provenance(RuleArtifact()) isa Provenance
    @test rules(RuleArtifact([ArtifactRule(:x, 1)])) isa Vector
    @test nodes(TreeArtifact([:x => 1])) isa Vector
    @test TreeArtifact([:x => 1]; default=:fallback)(:z) == :fallback
    @test RuleArtifact([ArtifactRule(x -> x > 0, true)]; default=false)(1)
    @test RuleArtifact([Dict(:x => true) => :hit])(:x) == :hit
    @test RuleArtifact([1 => (x -> x + 1)])(1) == 2
    scan_artifact = RuleArtifact([[AuditCopyProbe(i)] => i for i in 1:64])
    AUDIT_COPY_PROBES[] = 0
    @test scan_artifact([AuditCopyProbe(64)]) == 64
    @test AUDIT_COPY_PROBES[] == 0
    trace = ExecutionTrace([TraceStep(:test, nothing, nothing, :ok)], Provenance(), :ok)
    @test replay(trace, :anything).valid
    @test MetricValue(1, 1, 1, :global).applicable
    @test_throws ArgumentError eval_artifact(UnsupportedAuditArtifact(), 1)
    @test extract_artifact(x -> x, (x for x in [1]); artifact=:tree).nodes isa Vector
    @test extract_artifact(x -> x, [1]; artifact_type=RuleArtifact).rules[1].output == 1
    @test_throws ArgumentError extract_artifact(identity, [1]; artifact=:invalid)
    @test_throws ArgumentError extract_artifact(identity, [1]; encoder=(a, b, c) -> b)
    @test metric_bundle(
        RuleArtifact([1 => true]),
        [ArtifactCase(1, true, :global === :global ? true : false)];
        perturbations=[2],
    ).stability.applicable
end

@testset "verification and trace metadata are not silently trusted" begin
    artifact = RuleArtifact([:yes => true])
    uncovered = verify_artifact(artifact, [ArtifactCase(:no, true)])
    @test !uncovered.valid
    @test isequal(uncovered.claims.outputs, Any[missing])
    @test isequal(uncovered.claims.expected_outputs, Any[true])
    @test uncovered.claims.applicability == [false]
    _, trace = eval_artifact(artifact, :yes)
    original = trace.steps[1]
    tampered_step = TraceStep(
        :forged, (selected=999, payload=:tampered), :forged_input, original.output
    )
    tampered = ExecutionTrace(
        [tampered_step],
        trace.provenance,
        trace.reported_result,
        trace.input_hash,
        trace.output_hash,
        trace.scope,
    )
    @test !replay(tampered, :yes).valid
    _, no_trace = eval_artifact(artifact, :yes; trace=false)
    @test no_trace === nothing
end

@testset "metric scope and perturbation stability" begin
    artifact = RuleArtifact([1 => true]; default=false)
    changed = metric_bundle(artifact, [ArtifactCase(1, true)]; perturbations=[2])
    @test changed.stability.value == 0.0
    @test changed.stability.numerator == 0
    @test changed.stability.denominator == 1
    @test !metric_bundle(artifact, [ArtifactCase(1, true)]; scope=:local).stability.applicable
    @test !metric_bundle(artifact, [ArtifactCase(1, true)]; perturbations=()).stability.applicable
    @test_throws ArgumentError metric_bundle(
        artifact, [ArtifactCase(1, true)]; scope=:bogus
    )
end

@testset "AletheiaAudit quality" begin
    Aqua.test_all(AletheiaAudit)
    JET.test_package(
        AletheiaAudit; target_modules=(AletheiaAudit,), analyze_from_definitions=true
    )
end

@testset "stability baseline is permutation invariant and hashes identify states" begin
    artifact = RuleArtifact([1 => true]; default=false)
    first = [ArtifactCase(1, true), ArtifactCase(2, false)]
    second = reverse(first)
    @test metric_bundle(artifact, first; perturbations=[1]).stability ==
        metric_bundle(artifact, second; perturbations=[1]).stability
    record = audit(artifact, [ArtifactCase(:key, :state, true)])
    @test record.state_hashes[1] == record.trace[1].input_hash
    @test record.input_hashes[1] != record.state_hashes[1]
end

@testset "replay requires artifact and graph context" begin
    artifact = RuleArtifact([:yes => true])
    _, trace = eval_artifact(artifact, :yes)
    forged = ExecutionTrace(
        [
            TraceStep(
                :artifact_evaluation,
                (artifact="RuleArtifact", selected=999, profile=nothing),
                stable_hash(:yes),
                false,
            ),
        ],
        trace.provenance,
        false,
        stable_hash(:yes),
        stable_hash(false),
        :global,
    )
    @test !replay(forged, :yes).valid
end

@testset "audit records and traces own their public sequences" begin
    record = audit(RuleArtifact([:yes => true]), [ArtifactCase(:yes, true)])
    @test record.input_hashes isa Vector
    @test record.output_hashes isa Vector
    @test record.state_hashes isa Vector
    @test record.trace isa Vector
    @test record.trace[1].steps isa Tuple
    inputs = record.input_hashes
    push!(inputs, "forged")
    @test length(record.input_hashes) == 1
    @test_throws MethodError push!(
        record.trace[1].steps, TraceStep(:forged, nothing, nothing, nothing)
    )
end

@testset "replay authenticates artifact identity and every step" begin
    original = RuleArtifact([:yes => true])
    substitute = RuleArtifact([:yes => true, :no => false])
    _, trace = eval_artifact(original, :yes)
    replaced = ExecutionTrace(
        trace.steps,
        trace.provenance,
        trace.reported_result,
        trace.input_hash,
        trace.output_hash,
        trace.scope;
        artifact=substitute,
    )
    @test !replay(replaced, :yes).valid
    combined = ExecutionTrace(
        [TraceStep(:forged, (anything="bad",), "bad", false), trace.steps[1]],
        trace.provenance,
        trace.reported_result,
        trace.input_hash,
        trace.output_hash,
        trace.scope;
        artifact=original,
    )
    @test !replay(combined, :yes).valid
end

@testset "public audit boundaries reject mutable opaque values" begin
    payload = MutableAuditPayload(1)
    @test_throws OwnershipError ArtifactCase(:input, payload, :output)

    provenance = Provenance(; hashes=Dict(:x => [1]))
    trace = ExecutionTrace(
        (TraceStep(:test, nothing, nothing, :ok),),
        provenance,
        :ok,
        "",
        "",
        :global,
        nothing,
    )
    @test getfield(trace, :provenance) === provenance
    @test_throws CanonicalIndexError (
        getfield(getfield(trace, :provenance), :hashes)[:x][1] = 2
    )
end

@testset "public audit boundaries own nested values" begin
    buffer = Int[]
    artifact = extract_artifact(x -> (push!(buffer, x); buffer), [1, 2])
    @test artifact.rules[1].output == [1]
    @test artifact.rules[2].output == [1, 2]
    @test artifact.rules[1].output !== artifact.rules[2].output

    mutable_provenance = Provenance(; hashes=Dict{Any,Any}(:tag => :original))
    owned_artifact = RuleArtifact([:x => 1]; provenance=mutable_provenance)
    _, trace = eval_artifact(owned_artifact, :x)
    @test replay(trace, :x).valid

    callable_artifact = RuleArtifact([((x) -> x == 1) => ((x) -> x + 1)])
    _, callable_trace = eval_artifact(callable_artifact, 1)
    @test_throws ArgumentError serialize_trace(callable_trace)

    output = [1]
    record = audit(RuleArtifact([:x => output]; provenance=mutable_provenance), [:x])
    exposed = record.trace[1].artifact
    exposed.rules[1].output[1] = 9
    exposed.provenance.hashes[:tag] = :changed
    @test record.trace[1].artifact.rules[1].output == [1]
    @test record.provenance.hashes[:tag] == :original
end


@testset "formula trace serialization" begin
    formula = atom(:trace_formula)
    artifact = RuleArtifact([formula => true])
    result, trace = eval_artifact(artifact, formula)
    restored = deserialize_trace(serialize_trace(trace))
    @test result
    restored_formula = restored.artifact.rules[1].condition
    @test replay(restored, restored_formula).valid
    @test syntaxstring(restored_formula) == syntaxstring(formula)
    @test restored_formula.pool !== formula.pool
end
