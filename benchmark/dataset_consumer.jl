# Stage 2a: one real SoleModels consumer, measured through checkantecedent.
# The script builds disposable package copies and removes them on exit.
import Pkg
using Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOLEDATA_PATH = get(ENV, "SOLEDATA_PATH", "")
const SOLEMODELS_PATH = get(ENV, "SOLEMODELS_PATH", "")
isdir(SOLEDATA_PATH) || error("set SOLEDATA_PATH to a SoleData checkout")
isdir(SOLEMODELS_PATH) || error("set SOLEMODELS_PATH to a SoleModels checkout")

struct Measurement
    time::Union{Missing,Float64}
    gctime::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
    minimum::Union{Missing,Float64}
    maximum::Union{Missing,Float64}
    max_gctime::Union{Missing,Float64}
    samples::Int
    note::String
end
Measurement(time, gctime, allocs, memory, minimum, maximum, max_gctime, samples;
            note="") = Measurement(time, gctime, allocs, memory, minimum, maximum,
                                    max_gctime, samples, note)

function copy_writable(source, destination)
    cp(source, destination; force=true)
    for (directory, subdirs, files) in walkdir(destination)
        chmod(directory, 0o755)
        for file in files
            chmod(joinpath(directory, file), 0o644)
        end
    end
end

function patch_consumer!(package, route_source)
    source = joinpath(package, "src", "SoleModels.jl")
    text = read(source, String)
    marker = "include(\"evaluate.jl\")"
    occursin(marker, text) || error("SoleModels source has no evaluate include")
    text = replace(text, marker => marker * "\ninclude(\"stage2a_route.jl\")"; count=1)
    write(source, text)
    cp(route_source, joinpath(package, "src", "stage2a_route.jl"); force=true)
    project = joinpath(package, "Project.toml")
    text = read(project, String)
    dep = "Aletheia = \"e607e82d-a9f6-4003-a879-d63c15235362\""
    text = replace(text, "[deps]\n" => "[deps]\n$dep\n"; count=1)
    write(project, text)
end

function setup_environment(environment, aletheia_root, consumer_package)
    Pkg.activate(environment; io=devnull)
    Pkg.develop(Pkg.PackageSpec(path=aletheia_root); io=devnull)
    Pkg.develop(Pkg.PackageSpec(path=consumer_package); io=devnull)
    Pkg.develop(Pkg.PackageSpec(path=SOLEDATA_PATH); io=devnull)
    Pkg.add(["BenchmarkTools", "DataFrames", "Graphs", "SoleLogics"]; io=devnull)
    Pkg.instantiate(; io=devnull)
end

function run_worker(environment, mode, arguments; timeout=300, allow_timeout=false)
    worker = joinpath(@__DIR__, "dataset_consumer_worker.jl")
    julia = Base.julia_cmd()
    command = `timeout -k 1s $(timeout)s $julia --startup-file=no --project=$environment $worker $mode $(split(arguments))`
    path, io = mktemp(ROOT); close(io)
    error_path, error_io = mktemp(ROOT); close(error_io)
    process = run(pipeline(command, stdout=path, stderr=error_path); wait=false)
    wait(process)
    output = read(path, String)
    error_output = read(error_path, String)
    rm(path; force=true); rm(error_path; force=true)
    if allow_timeout && process.exitcode in (124, 137)
        return output, "timeout ($(timeout)s)"
    end
    process.exitcode == 0 || error("worker failed (exit code $(process.exitcode)): $(error_output)")
    output, ""
end

function compare_gate(baseline, routed, shapes)
    baseline_lines = split(strip(baseline), '\n')
    routed_lines = split(strip(routed), '\n')
    baseline_lines == routed_lines || begin
        mismatch = findfirst(i -> baseline_lines[i] != routed_lines[i],
            1:min(length(baseline_lines), length(routed_lines)))
        mismatch === nothing && (mismatch = min(length(baseline_lines), length(routed_lines)) + 1)
        baseline_row = mismatch <= length(baseline_lines) ? baseline_lines[mismatch] : "missing"
        routed_row = mismatch <= length(routed_lines) ? routed_lines[mismatch] : "missing"
        error("mask disagreement at gate row $mismatch: baseline=$(repr(baseline_row)) routed=$(repr(routed_row))")
    end
    cases = sum(length(split(split(line, '\t')[3], ',')) for line in baseline_lines)
    (rows=length(baseline_lines), rule_instance_cases=cases,
        shapes=length(shapes))
end

function parse_measurement(fields, start; note="")
    values = split(fields[start], ',')
    values[1] == "NA" && return Measurement(missing, missing, missing, missing,
        missing, missing, missing, 0; note=note)
    length(values) == 8 || error("measurement must contain time, GC, paired allocations/bytes, range, and sample count")
    Measurement(parse(Float64, values[1]), parse(Float64, values[2]),
        parse(Int, values[3]), parse(Int, values[4]), parse(Float64, values[5]),
        parse(Float64, values[6]), parse(Float64, values[7]), parse(Int, values[8]);
        note=note)
end

function parse_timing(output, ncases, side; note="")
    rows = Dict{Int,Any}()
    for line in split(strip(output), '\n')
        fields = split(line, '\t')
        isempty(fields) && continue
        index = parse(Int, fields[1])
        first_use = parse_measurement(fields, 2; note=note)
        steady = parse_measurement(fields, 3; note=note)
        churn = parse_measurement(fields, 4; note=note)
        if side == "baseline"
            rows[index] = (first_use=first_use, steady=steady, churn=churn,
                adapter=missing, conversion=missing, extension=missing)
        else
            rows[index] = (first_use=first_use, steady=steady, churn=churn,
                adapter=parse_measurement(fields, 5; note=note),
                conversion=parse_measurement(fields, 6; note=note),
                extension=parse_measurement(fields, 7; note=note))
        end
    end
    missing_measurement = Measurement(missing, missing, missing, missing,
        missing, missing, missing, 0; note=note)
    missing_row = (first_use=missing_measurement, steady=missing_measurement,
        churn=missing_measurement, adapter=missing_measurement,
        conversion=missing_measurement, extension=missing_measurement)
    [get(rows, i, missing_row) for i in 1:ncases]
end

function fmt_measurement(m)
    m.time === missing && return isempty(m.note) ? "timeout/unavailable" : m.note
    @sprintf("%.3f ms; GC %.3f ms; %d allocs / %d bytes; sample %.3f–%.3f ms; max GC %.3f ms; n=%d",
        m.time / 1e6, m.gctime / 1e6, m.allocs, m.memory,
        m.minimum / 1e6, m.maximum / 1e6, m.max_gctime / 1e6, m.samples)
end

const GATE_SHAPES = [
    "1:3:2:0.0:0", "3:4:3:0.5:1", "8:5:4:1.0:0", "16:6:5:0.35:1",
    "4:7:6:0.75:1", "12:8:3:0.25:0",
]

# Rules sweep count, depth, dataset size, local modal share, and shared-subterm
# construction independently while retaining one mixed case in each section.
const TIMING_CASES = [
    "16:6:4:0.5:1:1", "16:6:4:0.5:1:4", "16:6:4:0.5:1:16", "16:6:4:0.5:1:64",
    "16:6:2:0.5:1:16", "16:6:4:0.5:1:16", "16:6:6:0.5:1:16",
    "4:6:4:0.5:1:16", "16:6:4:0.5:1:16", "32:6:4:0.5:1:16",
    "16:3:4:0.5:1:16", "16:6:4:0.5:1:16", "16:8:4:0.5:1:16",
    "16:6:4:0.0:1:16", "16:6:4:0.5:1:16", "16:6:4:1.0:1:16",
    "16:6:4:0.5:0:16", "16:6:4:0.5:1:16",
]

# Reordering is an explicit diagnostic knob: the default preserves the
# published sweep, while a comma-separated permutation tests for run-position
# effects without changing any case's seed or shape.
function selected_timing_cases()
    encoded = get(ENV, "DATASET_CONSUMER_CASE_ORDER", "")
    isempty(encoded) && return TIMING_CASES
    order = parse.(Int, split(encoded, ','))
    sort(order) == collect(1:length(TIMING_CASES)) ||
        error("DATASET_CONSUMER_CASE_ORDER must be a permutation of 1:$(length(TIMING_CASES))")
    TIMING_CASES[order]
end

scratch = mktempdir(ROOT)
try
    baseline_package = joinpath(scratch, "SoleModels-baseline")
    routed_package = joinpath(scratch, "SoleModels-routed")
    copy_writable(SOLEMODELS_PATH, baseline_package)
    copy_writable(SOLEMODELS_PATH, routed_package)
    patch_consumer!(routed_package, joinpath(@__DIR__, "dataset_consumer_route.jl"))

    baseline_environment = joinpath(scratch, "environment-baseline")
    routed_environment = joinpath(scratch, "environment-routed")
    setup_environment(baseline_environment, ROOT, baseline_package)
    setup_environment(routed_environment, ROOT, routed_package)

    encoded_gate = join(GATE_SHAPES, ";")
    baseline_gate, baseline_gate_note = run_worker(baseline_environment, "gate", encoded_gate)
    routed_gate, routed_gate_note = run_worker(routed_environment, "gate", encoded_gate)
    isempty(baseline_gate_note) && isempty(routed_gate_note) || error("agreement gate timed out")
    gate = compare_gate(baseline_gate, routed_gate, GATE_SHAPES)
    println("mask gate: PASS; seed=0xDADA_2024; shapes=$(gate.shapes); " *
        "rule-instance masks=$(gate.rule_instance_cases)")

    timing_cases = selected_timing_cases()
    encoded_timing = join(timing_cases, ";")
    baseline_output, baseline_note = run_worker(baseline_environment, "timing",
        "baseline $encoded_timing"; allow_timeout=true)
    routed_output, routed_note = run_worker(routed_environment, "timing",
        "aletheia $encoded_timing"; allow_timeout=true)
    baseline_timing = parse_timing(baseline_output, length(timing_cases), "baseline";
        note=baseline_note)
    routed_timing = parse_timing(routed_output, length(timing_cases), "aletheia";
        note=routed_note)

    result_path = get(ENV, "DATASET_CONSUMER_RESULT",
        joinpath(ROOT, "data", "al-dataset-consumer", "run.txt"))
    mkpath(dirname(result_path))
    open(result_path, "w") do io
        println(io, "seed=0xDADA_2024")
        println(io, "case-order=$(get(ENV, "DATASET_CONSUMER_CASE_ORDER", "default"))")
        println(io, "gate=PASS shapes=$(gate.shapes) rule-instance-masks=$(gate.rule_instance_cases)")
        println(io, "case | baseline first use | routed first use | baseline steady | routed steady | baseline churn | routed churn | adapter | formula conversion | extension/mask")
        for (index, case) in enumerate(timing_cases)
            b, a = baseline_timing[index], routed_timing[index]
            println(io, "$(case) | $(fmt_measurement(b.first_use)) | $(fmt_measurement(a.first_use)) | " *
                "$(fmt_measurement(b.steady)) | $(fmt_measurement(a.steady)) | " *
                "$(fmt_measurement(b.churn)) | $(fmt_measurement(a.churn)) | " *
                "$(fmt_measurement(a.adapter)) | $(fmt_measurement(a.conversion)) | " *
                "$(fmt_measurement(a.extension))")
        end
    end
    println("timings written to $result_path")
finally
    rm(scratch; recursive=true, force=true)
end
