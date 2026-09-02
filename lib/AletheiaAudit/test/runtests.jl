using Aqua
using JET
using Test
using AletheiaAudit
@test test_interface(RuleArtifact)
@test test_interface(TreeArtifact)
a = RuleArtifact([1 => :one, 2 => :two])
o, t = eval_artifact(a, 1)
@test o == :one
@test replay(t, 1).valid
@test deserialize_trace(serialize_trace(t)).reported_result == :one
m = metric_bundle(
    a,
    [
        ArtifactCase(1, :global === :global ? nothing : nothing, :one, :global),
        ArtifactCase(3, nothing, :x, :global),
    ],
)
@test m.coverage.applicable && m.coverage.numerator == 1
@test m.fidelity.applicable && m.fidelity.numerator == 1

@testset "AletheiaAudit quality" begin
    Aqua.test_all(AletheiaAudit)
    JET.test_package(
        AletheiaAudit; target_modules=(AletheiaAudit,), analyze_from_definitions=true
    )
end
