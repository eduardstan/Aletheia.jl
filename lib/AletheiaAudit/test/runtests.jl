using Aqua
using JET
using Supposition
using Test
using AletheiaAudit

struct UnsupportedAuditArtifact <: SymbolicArtifact end

@testset "typed artifact protocol" begin
    @test test_interface(RuleArtifact)
    @test test_interface(TreeArtifact)
    rule = RuleArtifact([1 => :one, 2 => :two])
    tree = TreeArtifact([1 => :one, 2 => :two])
    for artifact in (rule, tree)
        for state in (1, 2, 3)
            output, trace = eval_artifact(artifact, state; profile=:exact)
            restored = deserialize_trace(serialize_trace(trace))
            @test replay(restored, state).valid
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
    @test global_metrics.fidelity.denominator == 1
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
    tampered_step = TraceStep(:forged, (selected=999, payload=:tampered), :forged_input, original.output)
    tampered = ExecutionTrace([tampered_step], trace.provenance, trace.reported_result,
        trace.input_hash, trace.output_hash, trace.scope)
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
    @test_throws ArgumentError metric_bundle(artifact, [ArtifactCase(1, true)]; scope=:bogus)
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
    forged = ExecutionTrace([TraceStep(:artifact_evaluation,
        (artifact="RuleArtifact", selected=999, profile=nothing), stable_hash(:yes), false)],
        trace.provenance, false, stable_hash(:yes), stable_hash(false), :global)
    @test !replay(forged, :yes).valid
end
