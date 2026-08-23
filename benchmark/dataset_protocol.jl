# Stage-1 SoleData experiment.  It deliberately keeps SoleData in a temporary
# benchmark environment; Aletheia itself remains dependency-free.
import Pkg
using Printf
using Random
using Statistics

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOLEDATA_PATH = get(ENV, "SOLEDATA_PATH", "")
isdir(SOLEDATA_PATH) || error("set SOLEDATA_PATH to an installed SoleData checkout")

# A temporary environment lets the adapter use the installed package without
# editing either the repository Project.toml or the package checkout.
env = mktempdir()
Pkg.activate(env; io=devnull)
Pkg.develop(Pkg.PackageSpec(path=ROOT); io=devnull)
Pkg.develop(Pkg.PackageSpec(path=SOLEDATA_PATH); io=devnull)
Pkg.add(["BenchmarkTools", "SoleLogics", "Graphs", "DataFrames"]; io=devnull)
Pkg.instantiate(; io=devnull)

using Aletheia
using SoleData
using SoleLogics
using Graphs

include(joinpath(@__DIR__, "dataset_protocol_adapter.jl"))
include(joinpath(@__DIR__, "dataset_protocol_shared.jl"))

const GATE_SEED = DATASET_SEED

function run_gate()
    gate_shapes = ((1, 3, 1, 0.0, true), (3, 4, 3, 0.5, true),
        (4, 5, 4, 1.0, false), (7, 6, 5, 0.35, false))
    rng = MersenneTwister(GATE_SEED)
    formula_world_cases = 0
    formula_count = 0
    for (ninstances, nworlds, depth, modal_probability, uniform) in gate_shapes
        dataset = make_dataset(ninstances, nworlds; uniform=uniform)
        family = SoleDataFamily(dataset; vectorized=true)
        uniform == isuniform(family) || error("uniform-frame detection failed")
        for _ in 1:20
            formula_a, formula_s = make_pair(depth, modal_probability, rand(rng, 1:typemax(Int)))
            extension_a = Aletheia.extension(formula_a, family)
            formula_count += 1
            for i_instance in Aletheia.eachinstance(family)
                expected = sole_check_all(formula_s, dataset, i_instance)
                extension_a[i_instance] == expected || error("agreement disagreement in extension")
                for (slot, world) in enumerate(SoleLogics.allworlds(
                    SoleLogics.frame(dataset, i_instance)))
                    Aletheia.check(formula_a, family, i_instance, world) == expected[slot] ||
                        error("agreement disagreement at instance=$i_instance world=$world")
                    formula_world_cases += 1
                end
            end
        end
    end
    (formula_count=formula_count, formula_world_cases=formula_world_cases)
end

struct Measurement
    time::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
    note::String
end

function section_measure(cases, side; timeout=180)
    encoded = join(cases, ";")
    julia = Base.julia_cmd()
    worker = joinpath(@__DIR__, "dataset_protocol_worker.jl")
    command = `timeout -k 1s $(timeout)s $julia --startup-file=no --project=$env $worker $side $encoded`
    path, io = mktemp(); close(io)
    process = run(pipeline(command, stdout=path, stderr=devnull); wait=false)
    wait(process)
    output = read(path, String); rm(path; force=true)
    if process.exitcode == 124 || process.exitcode == 137
        return [Measurement(missing, missing, missing, "timeout ($(timeout)s)") for _ in cases]
    end
    result = Measurement[]
    for line in split(output, '\n')
        fields = split(strip(line))
        length(fields) == 3 || continue
        values = try parse.(Float64, fields) catch; nothing end
        values === nothing && continue
        push!(result, Measurement(values[1], round(Int, values[2]), round(Int, values[3]), ""))
    end
    note = length(result) < length(cases) ?
        "timeout/incomplete (exit code $(process.exitcode))" :
        process.exitcode == 0 ? "" : "unavailable (exit code $(process.exitcode))"
    while length(result) < length(cases)
        push!(result, Measurement(missing, missing, missing, note))
    end
    result[1:length(cases)]
end

function fmt(m)
    m.time === missing && return m.note
    @sprintf("%.3f ms; %d allocs / %d bytes", m.time / 1e6, m.allocs, m.memory)
end

result_path = get(ENV, "DATASET_PROTOCOL_RESULT", joinpath(ROOT, "data", "al-dataset-protocol", "run.txt"))
mkpath(dirname(result_path))
gate = run_gate()
open(result_path, "w") do io
    println(io, "seed=$(GATE_SEED)")
    println(io, "agreement formulas=$(gate.formula_count) formula-instance-world cases=$(gate.formula_world_cases)")
    println(io, "agreement=PASS")
end
println("agreement gate: PASS; seed=$(GATE_SEED); formulas=$(gate.formula_count); formula-instance-world cases=$(gate.formula_world_cases)")

# The sweep varies each requested driver.  Uniform and non-uniform frame cases
# are both included; modal probability is the target fraction of modal nodes.
quick = "--deep" in ARGS ? false : true
if get(ENV, "DATASET_PROTOCOL_SMALL", "") == "1"
    cases = ["1:4:2:0.0:1", "1:4:2:0.0:0"]
else
    cases = String[]
    for ninstances in (1, 8, 32)
        push!(cases, "$(ninstances):8:4:0.5:1")
    end
    for nworlds in (4, 16, 32)
        push!(cases, "8:$(nworlds):4:0.5:1")
    end
    for depth in (2, 4, 6)
        push!(cases, "8:16:$(depth):0.5:1")
    end
    for modal_probability in (0.0, 0.5, 1.0)
        push!(cases, "8:16:4:$(modal_probability):1")
    end
    for ninstances in (1, 8, 32)
        push!(cases, "$(ninstances):16:4:0.5:0")
    end
    for nworlds in (4, 16, 32)
        push!(cases, "8:$(nworlds):4:0.5:0")
    end
    for depth in (2, 4, 6)
        push!(cases, "8:16:$(depth):0.5:0")
    end
    for modal_probability in (0.0, 0.5, 1.0)
        push!(cases, "8:16:4:$(modal_probability):0")
    end
    if !quick
        append!(cases, ["96:64:6:0.5:1", "96:64:6:0.5:0",
            "32:64:8:1.0:1", "32:64:8:1.0:0"])
    end
end

sides = ("sole", "aletheia-batch", "aletheia-scalar")
measurements = Dict(side => section_measure(cases, side) for side in sides)
open(result_path, "a") do io
    println(io, "cases=$(length(cases))")
    println(io, "case | SoleData | Aletheia batch | Aletheia scalar")
    for (index, argument) in enumerate(cases)
        println(io, "$(argument) | $(fmt(measurements["sole"][index])) | " *
            "$(fmt(measurements["aletheia-batch"][index])) | " *
            "$(fmt(measurements["aletheia-scalar"][index]))")
    end
end
println("timing results written to $(result_path); cases=$(length(cases)); seed=$(GATE_SEED)")
