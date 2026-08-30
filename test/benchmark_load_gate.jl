include(joinpath(@__DIR__, "..", "benchmark", "load_gate.jl"))

@testset "benchmark load publishability gate" begin
    quiet = benchmark_load_verdict(3.76, 2.98, [4.81], 12)
    @test quiet.publishable
    @test quiet.reason == :acceptable

    # These are the recorded contaminated-run start/end and a real seed load
    # from its artefact; its ending load alone is already disqualifying.
    contaminated = benchmark_load_verdict(3.64, 9.54, [4.55, 5.02, 7.63], 12)
    @test !contaminated.publishable
    @test contaminated.reason == :peak_load

    # Midpoint boundaries are inclusive, while either side of either boundary
    # refuses publication.
    @test benchmark_load_verdict(0.0, 0.0, [7.175], 12).publishable
    @test benchmark_load_verdict(0.0, 2.56, Float64[], 12).publishable
    @test benchmark_load_verdict(0.0, 0.0, [7.176], 12).reason == :peak_load
    @test benchmark_load_verdict(0.0, 2.561, Float64[], 12).reason == :load_rise

    @test !benchmark_load_verdict(missing, 2.0, Float64[], 12).publishable
    @test !benchmark_load_verdict(2.0, missing, Float64[], 12).publishable
    @test parse_load_average("12:00 up 1 day, load average: 3.76, 2.0, 1.0") == 3.76
    @test parse_load_average("unavailable") === missing
end
