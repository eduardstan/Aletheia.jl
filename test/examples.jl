using Test

@testset "runnable examples" begin
    root = dirname(@__DIR__)
    module_for_examples = Module(:AletheiaExamples)
    quickstart_markers = (
        "formula: ⟨R⟩p ∧ [R]q\nparse round-trip: true",
        "successors of w₁: [:w₂]\ncheck at w₁: true",
        "Extension (2 of 2 worlds satisfy)\n  Satisfied at: :w₁, :w₂\n  Unsatisfied at: (none)",
    )
    for name in sort(filter(endswith(".jl"), readdir(joinpath(root, "examples"))))
        script = joinpath(root, "examples", name)
        pipe = Pipe()
        redirect_stdout(pipe) do
            Base.include(module_for_examples, script)
        end
        close(pipe.in)
        output = read(pipe, String)
        if name == "quickstart.jl"
            for marker in quickstart_markers
                @test occursin(marker, output)
            end
        else
            @test true # reaching this point means the complete script executed
        end
    end
end
