using Test

@testset "one-dataset showcase" begin
    script = joinpath(dirname(@__DIR__), "examples", "showcase", "showcase.jl")
    Base.include(Main, script)
    showcase = Main.AletheiaShowcase
    output = IOBuffer()
    elapsed = @elapsed result = showcase.run_showcase(; io=output)
    @test elapsed < 180.0
    @test result.cross_checks.plain
    @test result.cross_checks.many_valued
    @test result.cross_checks.circuits
    @test result.cross_checks.graph
    @test result.cross_checks.neural
    @test result.crisp_labels == [:alert, :review, :calm, :calm]
    @test result.metrics.fidelity.value == 0.8
    @test result.metrics.coverage.value == 0.8
    @test !result.metrics.constraints.applicable
    @test result.trace_replay.valid
    @test length(result.roundtrip.audit.input_hashes) == 4
    text = String(take!(output))
    @test occursin("extension/check cross-check: true", text)
    @test occursin("certified-circuit/total-choice cross-check: true", text)
    @test occursin(
        "graph/path-oracle cross-check: true; provenance trace replay: true", text
    )
    @test occursin("direct-network/neural-leaf cross-check: true", text)
end
