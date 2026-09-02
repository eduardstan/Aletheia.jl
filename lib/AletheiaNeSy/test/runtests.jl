using Aqua
using JET
using Test
using AletheiaCore
using AletheiaAudit
using AletheiaNeSy
net(x) = x > 0
v = neural_valuation(net, identity; algebra=BOOLEAN)
@test v(:p, 1) == true
@test v.vectorized(:p, [-1, 1]) == [false, true]
@test_throws InvalidNeuralValueError neural_valuation(x -> 2, identity; algebra=BOOLEAN)(
    :p, 1
)
rt = ske_roundtrip(net, identity, [-1, 1])
@test rt.verification.valid
@test rt.metrics.fidelity.value == 1.0
@test_throws SemanticLossError semantic_loss(atom(:p), v)
@test neural_choice_labels(x -> [1, 3], identity; profile=(finite=true,)) ≈ [0.25, 0.75]

@testset "AletheiaNeSy quality" begin
    Aqua.test_all(AletheiaNeSy)
    JET.test_package(
        AletheiaNeSy; target_modules=(AletheiaNeSy,), analyze_from_definitions=true
    )
end
