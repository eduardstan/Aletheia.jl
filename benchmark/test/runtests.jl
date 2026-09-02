using Test
include(joinpath(@__DIR__, "..", "common.jl"))

@testset "published benchmark seed spellings round-trip" begin
    spellings = ("0xA1E7_2024", "0x5EED_2025", "0xC0FF_EE42", "0x1234_5678", "0x9ABC_DEF0")
    for (spelling, seed) in zip(spellings, DEFAULT_SEEDS)
        @test parse_seed(spelling) == seed
    end
end
