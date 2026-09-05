using Test
const Serialization = AletheiaCore.Serialization
using Random
using Aqua
using JET
using Supposition
using AletheiaCore
const Aletheia = AletheiaCore

include("syntax.jl")
include("prop.jl")
include("defaultpool.jl")
include("semantics.jl")
include("evaluation.jl")
include("algebras.jl")
include("relations.jl")
include("relation_properties.jl")
include("theory.jl")
include("presentation.jl")

@testset "AletheiaCore" begin
    Aqua.test_all(AletheiaCore)
    if pkgversion(JET) < v"0.11"
        JET.test_package(AletheiaCore; target_defined_modules=true)
    else
        JET.test_package(AletheiaCore; target_modules=(AletheiaCore,), analyze_from_definitions=true)
    end
end
