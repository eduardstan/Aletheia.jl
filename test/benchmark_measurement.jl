include(joinpath(@__DIR__, "..", "benchmark", "measurement.jl"))

@testset "benchmark outcomes" begin
    measured = Measurement(1.0, 2, 3)
    timed_out = Measurement(missing, missing, missing, "timeout (120s)")
    failed = Measurement(missing, missing, missing,
        "failed (exit code 1): UndefVarError: stale_name")

    @test measured.status === :measured
    @test timed_out.status === :timeout
    @test failed.status === :failed
    @test is_measured(measured)
    @test !is_measured(timed_out)
    @test !is_measured(failed)
    @test all(is_timeout_exitcode, (124, 137, 143))
    @test !is_timeout_exitcode(1)

    @test occursin("timed out", outcome_summary([measured, timed_out]))
    failure_summary = outcome_summary([measured, timed_out, failed])
    @test occursin("failed", failure_summary)
    @test occursin("UndefVarError: stale_name", failure_summary)
    @test !occursin("1.0", failure_summary)

    source = read(joinpath(@__DIR__, "..", "benchmark", "warmup.jl"), String)
    @test occursin("Aletheia.RCC5_RELATIONS", source)
    @test !occursin("Aletheia.RCC5Relations", source)
end
