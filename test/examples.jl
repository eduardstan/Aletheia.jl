using Test

@testset "runnable examples" begin
    root = dirname(@__DIR__)
    module_for_examples = Module(:AletheiaExamples)
    for name in sort(filter(endswith(".jl"), readdir(joinpath(root, "examples"))))
        script = joinpath(root, "examples", name)
        redirect_stdout(devnull) do
            Base.include(module_for_examples, script)
        end
        @test true # reaching this point means the complete script executed
    end
end
