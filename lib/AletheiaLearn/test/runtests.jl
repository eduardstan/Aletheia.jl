using Test
using Aqua
using JET
using AletheiaLearn
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "AletheiaCore"))
using AletheiaCore
const Aletheia = AletheiaCore
const FOFunction = AletheiaCore.FOFunction
const FOAnd = AletheiaCore.FOAnd
const FOOr = AletheiaCore.FOOr
const FOImplies = AletheiaCore.FOImplies
const FONot = AletheiaCore.FONot
include("ilp.jl")

@testset "AletheiaLearn quality" begin
    Aqua.test_all(AletheiaLearn)
    if pkgversion(JET) < v"0.11"
        JET.test_package(AletheiaLearn; target_defined_modules=true)
    else
        JET.test_package(
            AletheiaLearn; target_modules=(AletheiaLearn,), analyze_from_definitions=true
        )
    end
end
