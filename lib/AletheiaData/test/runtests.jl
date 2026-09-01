using Test
using Aqua
using JET
using AletheiaData
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "AletheiaCore"))
using AletheiaCore
const Aletheia = AletheiaCore
include("dataset.jl")
include("scalar.jl")
include("scalar_extended.jl")

@testset "AletheiaData quality" begin
    Aqua.test_all(AletheiaData)
    if pkgversion(JET) < v"0.11"
        JET.test_package(AletheiaData; target_defined_modules=true)
    else
        JET.test_package(AletheiaData; target_modules=(AletheiaData,), analyze_from_definitions=true)
    end
end
