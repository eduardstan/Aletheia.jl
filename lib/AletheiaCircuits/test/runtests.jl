using Test
using Aqua
using JET
using Supposition
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "AletheiaCore"))
using AletheiaCircuits
using AletheiaCore

include("program.jl")
include("circuits.jl")
include("properties.jl")

@testset "AletheiaCircuits quality" begin
    Aqua.test_all(AletheiaCircuits)
    if pkgversion(JET) < v"0.11"
        JET.test_package(AletheiaCircuits; target_defined_modules=true)
    else
        JET.test_package(
            AletheiaCircuits;
            target_modules=(AletheiaCircuits,),
            analyze_from_definitions=true,
        )
    end
end
