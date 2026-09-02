using Test
using Aqua
using JET
using Random
using AletheiaSole
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "AletheiaCore"))
push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "AletheiaData"))
using AletheiaCore
using AletheiaData
const Aletheia = AletheiaSole

for name in (:IA_A, :IA_L, :IA_B, :IA_E, :IA_D, :IA_O, :IA_Ai, :IA_Li, :IA_Bi, :IA_Ei, :IA_Di, :IA_Oi,
             :IA_AorO, :IA_DorBorE, :IA_AiorOi, :IA_DiorBiorEi, :IA_I, :IA7Relations, :IA3Relations,
             :IA72IARelations, :IA32IARelations, :Point2DRelation, :POINT2D_RELATIONS, :Point2DRelations,
             :FullDimensionalFrame, :Full1DFrame, :Full2DFrame, :Full1DPointFrame, :Full2DPointFrame,
             :CL_N, :CL_S, :CL_E, :CL_W, :CL_NE, :CL_NW, :CL_SE, :CL_SW)
    @eval const $name = AletheiaCore.$name
end
const Topo_DR = AletheiaCore.DR
const Topo_PP = AletheiaCore.PPi
const Topo_PPi = AletheiaCore.PP
const Topo_DC = AletheiaCore.DC
const Topo_EC = AletheiaCore.EC
const Topo_PO = AletheiaCore.PO
const Topo_TPP = AletheiaCore.TPPi
const Topo_TPPi = AletheiaCore.TPP
const Topo_NTPP = AletheiaCore.NTPPi
const Topo_NTPPi = AletheiaCore.NTPP
include("compatibility.jl")
include("vocabulary.jl")

@testset "AletheiaSole quality" begin
    Aqua.test_all(AletheiaSole)
    if pkgversion(JET) < v"0.11"
        JET.test_package(AletheiaSole; target_defined_modules=true)
    else
        JET.test_package(AletheiaSole; target_modules=(AletheiaSole,), analyze_from_definitions=true)
    end
end
