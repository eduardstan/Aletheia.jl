using Test

const EXPECTED_OUTPUT_RE = r"(?ms)^# BEGIN EXPECTED OUTPUT\n(.*?)^# END EXPECTED OUTPUT\n?"
const ANSI_RE = r"\e\[[0-9;]*m"

function expected_output(script)
    source = replace(read(script, String), "\r\n" => "\n")
    found = Base.match(EXPECTED_OUTPUT_RE, source)
    @test found !== nothing
    found === nothing && return ""
    lines = split(found.captures[1], '\n'; keepempty=true)
    !isempty(lines) && isempty(lines[end]) && pop!(lines)
    lines = map(lines) do line
        startswith(line, "# ") ? line[3:end] : (line == "#" ? "" : line)
    end
    return join(lines, '\n')
end

@testset "runnable examples" begin
    root = dirname(@__DIR__)
    module_for_examples = Module(:AletheiaExamples)
    for name in sort(filter(endswith(".jl"), readdir(joinpath(root, "examples"))))
        script = joinpath(root, "examples", name)
        pipe = Pipe()
        redirect_stdout(pipe) do
            Base.include(module_for_examples, script)
        end
        close(pipe.in)
        output = read(pipe, String)
        output = replace(output, ANSI_RE => "")
        output = replace(output, "\r\n" => "\n")
        @test output == expected_output(script)
    end
end
