# Stage-1 follow-up: the default scalarlogiset -> SupportedLogiset path.
import Pkg
using Printf
using Random
using Statistics

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOLEDATA_PATH = get(ENV, "SOLEDATA_PATH", "")
isdir(SOLEDATA_PATH) || error("set SOLEDATA_PATH to an installed SoleData checkout")

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
using DataFrames

include(joinpath(@__DIR__, "dataset_protocol_shared.jl"))

const GATE_SEED = DATASET_SEED

function run_gate()
    gate_shapes = ((1, 3, 1, 0.0), (3, 4, 3, 0.5),
        (4, 5, 4, 1.0), (7, 6, 5, 0.35))
    rng = MersenneTwister(GATE_SEED + 17)
    formula_count = 0
    formula_world_cases = 0
    for (ninstances, npoints, depth, modal_probability) in gate_shapes
        dataset = make_supported_dataset(ninstances, npoints)
        family = SoleDataFamily(dataset; vectorized=true, relation=SoleLogics.IA_L)
        isuniform(family) || error("SupportedLogiset family should have a uniform frame")
        for _ in 1:20
            formula_a, formula_s = make_pair(depth, modal_probability,
                rand(rng, 1:typemax(Int)); supported=true)
            extension_a = Aletheia.extension(formula_a, family)
            formula_count += 1
            for i_instance in Aletheia.eachinstance(family)
                expected = sole_check_all(formula_s, dataset, i_instance)
                extension_a[i_instance] == expected || error("cold agreement disagreement")
                for (slot, world) in enumerate(SoleLogics.allworlds(
                    SoleLogics.frame(dataset, i_instance)))
                    Aletheia.check(formula_a, family, i_instance, world) == expected[slot] ||
                        error("cold agreement disagreement at instance=$i_instance world=$world")
                    formula_world_cases += 1
                end
                # The same formula is checked again after SupportedLogiset's full
                # memo has been populated; its answer must remain exact.
                warm = sole_check_all(formula_s, dataset, i_instance)
                warm == expected || error("warm agreement disagreement")
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

function section_measure(cases, side; timeout=300)
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

result_path = get(ENV, "DATASET_PROTOCOL_SUPPORTED_RESULT",
    joinpath(ROOT, "data", "soledata-protocol", "run-supported.txt"))
mkpath(dirname(result_path))
gate = run_gate()
open(result_path, "w") do io
    println(io, "seed=$(GATE_SEED)")
    println(io, "agreement formulas=$(gate.formula_count) formula-instance-world cases=$(gate.formula_world_cases)")
    println(io, "agreement=PASS")
end
println("SupportedLogiset agreement gate: PASS; seed=$(GATE_SEED); formulas=$(gate.formula_count); formula-instance-world cases=$(gate.formula_world_cases)")

# The numeric world axis is the number of points used to construct the real
# interval dataset.  A p-point interval frame has p*(p-1)/2 worlds.
cases = String[]
for ninstances in (1, 8, 32)
    push!(cases, "$(ninstances):4:4:0.5:1")
end
for npoints in (3, 5, 7)
    push!(cases, "8:$(npoints):4:0.5:1")
end
for depth in (2, 4, 6)
    push!(cases, "8:6:$(depth):0.5:1")
end
for modal_probability in (0.0, 0.5, 1.0)
    push!(cases, "8:6:4:$(modal_probability):1")
end
append!(cases, ["32:6:4:0.5:1", "16:8:6:0.5:1", "8:8:6:1.0:1"])

sides = ("supported-cold", "supported-warm", "supported-aletheia-batch", "supported-aletheia-scalar")
measurements = Dict(side => section_measure(cases, side) for side in sides)
open(result_path, "a") do io
    println(io, "cases=$(length(cases))")
    println(io, "case(points) | Supported cold first-check | Supported warm repeated-check | Aletheia batch | Aletheia scalar")
    for (index, argument) in enumerate(cases)
        println(io, "$(argument) | $(fmt(measurements["supported-cold"][index])) | " *
            "$(fmt(measurements["supported-warm"][index])) | " *
            "$(fmt(measurements["supported-aletheia-batch"][index])) | " *
            "$(fmt(measurements["supported-aletheia-scalar"][index]))")
    end
end
println("SupportedLogiset timing results written to $(result_path); cases=$(length(cases)); seed=$(GATE_SEED)")
