# Reproducible apply-path benchmark against the deployed Sole stack.
# This script owns the temporary environment and never changes any dependency
# checkout. Every timed section runs in a reniced child whose output goes to a
# file, not a pipe.
ENV["OPENBLAS_NUM_THREADS"] = "1"
ENV["OMP_NUM_THREADS"] = "1"
ENV["MKL_NUM_THREADS"] = "1"
ENV["JULIA_NUM_PRECOMPILE_TASKS"] = "2"

import Pkg
using Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOLELOGICS_PATH = get(ENV, "SOLELOGICS_PATH", "")
const SOLEDATA_PATH = get(ENV, "SOLEDATA_PATH", "")
const SOLEMODELS_PATH = get(ENV, "SOLEMODELS_PATH", "")
const MODALDECISIONTREES_PATH = get(ENV, "MODALDECISIONTREES_PATH", "")
const APPLY_DATA_SEED = 0xDADA_C13E
const APPLY_TRAIN_SEED = 0x5EED_2025
const APPLY_NINSTANCES = 16
const APPLY_NPOINTS = 8
const APPLY_DEPTH = 5
for (name, path) in (("SOLELOGICS_PATH", SOLELOGICS_PATH), ("SOLEDATA_PATH", SOLEDATA_PATH),
                     ("SOLEMODELS_PATH", SOLEMODELS_PATH),
                     ("MODALDECISIONTREES_PATH", MODALDECISIONTREES_PATH))
    isdir(path) || error("set $name to a checkout or package source directory")
end

function uptime_line()
    try readchomp(`uptime`) catch; "unavailable" end
end
function load_value(line)
    m = match(r"load average: ([0-9]+(?:\.[0-9]+)?)", line)
    m === nothing ? missing : parse(Float64, m.captures[1])
end
function quiet_check(line)
    load = load_value(line)
    # The published harness midpoint is the hard upper boundary; the final
    # run-level gate below also checks peak load and load rise.
    load !== missing && load <= 7.175 || error("quiet-machine gate failed: $line")
    line
end

# Package setup is outside the measurement sections.
environment = mktempdir(ROOT)
result_path = get(ENV, "DEPLOYED_APPLY_RESULT",
    joinpath(ROOT, "data", "benchmark-run", "deployed-apply.txt"))
mkpath(dirname(result_path))
sections = ("supported-construction", "sole-formula-check", "supported-cold",
    "supported-warm", "deployed-modal-tree", "decision-list-apply",
    "aletheia-scalar-construction", "aletheia-scalar",
    "aletheia-vectorized-construction", "aletheia-vectorized")
records = String[]
errors = String[]
run_start_uptime = "unavailable"
try
    Pkg.activate(environment; io=devnull)
    for path in (ROOT, SOLELOGICS_PATH, SOLEDATA_PATH, SOLEMODELS_PATH,
                 MODALDECISIONTREES_PATH)
        Pkg.develop(Pkg.PackageSpec(path=path); io=devnull)
    end
    Pkg.add(["BenchmarkTools", "DataFrames", "Graphs"]; io=devnull)
    Pkg.instantiate(; io=devnull)

    global run_start_uptime = uptime_line()
    open(result_path, "w") do io
        println(io, "publishable=pending")
        println(io, "julia=$(VERSION)")
        println(io, "cpu=$(Sys.CPU_NAME)")
        println(io, "cpu_threads=$(Sys.CPU_THREADS)")
        println(io, "openblas_threads=$(get(ENV, "OPENBLAS_NUM_THREADS", ""))")
        println(io, "julia_num_precompile_tasks=$(get(ENV, "JULIA_NUM_PRECOMPILE_TASKS", ""))")
        println(io, "child_nice=15")
        println(io, "solelogics_path=$(SOLELOGICS_PATH)")
        println(io, "soledata_path=$(SOLEDATA_PATH)")
        println(io, "solemodels_path=$(SOLEMODELS_PATH)")
        println(io, "modaldecisiontrees_path=$(MODALDECISIONTREES_PATH)")
        println(io, "seeds=0xA1E7_2024,0x5EED_2025,0xC0FF_EE42,0x1234_5678,0x9ABC_DEF0 data_seed=$(APPLY_DATA_SEED) train_seed_default=$(APPLY_TRAIN_SEED)")
        println(io, "workload=instances=$(APPLY_NINSTANCES),points=$(APPLY_NPOINTS),depth=$(APPLY_DEPTH)")
        println(io, "sole_controls=full_memo=true one_step_memo=true global_precompute=true relational_precompute=false")
        println(io, "sole_paths=formula-check=SoleData.check; modal-tree=ModalDecisionTrees.apply/modalstep/checkcondition; decision-list=SoleModels.apply/SoleLogics.check")
        println(io, "aletheia_path=DecisionListBatchAdapter prepared model family; scalar or vectorized ValuationCallback; conversion outside apply timing")
        for package_name in ("Aletheia", "SoleLogics", "SoleData", "SoleModels", "ModalDecisionTrees")
            dependency = first(filter(dep -> dep.name == package_name,
                collect(values(Pkg.dependencies()))))
            println(io, "package_$(lowercase(package_name))_version=$(dependency.version)")
        end
        println(io, "uptime_before_differential=$(run_start_uptime)")
    end

    # Differential parity is a hard gate and precedes every timed section.
    differential_out, differential_out_io = mktemp(ROOT); close(differential_out_io)
    differential_error, differential_error_io = mktemp(ROOT); close(differential_error_io)
    julia = Base.julia_cmd()
    differential_command = `$(julia) --startup-file=no --project=$environment $(joinpath(@__DIR__, "deployed_apply_differential.jl"))`
    differential_process = run(pipeline(differential_command, stdout=differential_out,
        stderr=differential_error); wait=false)
    wait(differential_process)
    differential_text = read(differential_out, String)
    differential_stderr = read(differential_error, String)
    rm(differential_out; force=true); rm(differential_error; force=true)
    differential_process.exitcode == 0 || begin
        push!(errors, "differential failed: $(strip(differential_stderr))")
        error("differential parity gate failed")
    end
    push!(records, "differential=$(strip(differential_text))")

    for section in sections
        before = quiet_check(uptime_line())
        outpath, outio = mktemp(ROOT); close(outio)
        errpath, errio = mktemp(ROOT); close(errio)
        command = `timeout -k 1s 300s nice -n 15 $(julia) --startup-file=no --project=$environment $(joinpath(@__DIR__, "deployed_apply_worker.jl")) $section`
        process = run(pipeline(command, stdout=outpath, stderr=errpath); wait=false)
        wait(process)
        output = read(outpath, String)
        stderr = read(errpath, String)
        rm(outpath; force=true); rm(errpath; force=true)
        after = uptime_line()
        push!(records, "section=$(section) uptime_before=$(before) uptime_after=$(after)")
        if process.exitcode != 0
            push!(errors, "section=$section exit=$(process.exitcode): $(strip(stderr))")
        else
            lines = [strip(line) for line in split(output, '\n') if startswith(strip(line), "result ")]
            isempty(lines) && push!(errors, "section=$section emitted no result")
            append!(records, ["$line uptime_before=$(before) uptime_after=$(after)" for line in lines])
        end
    end
finally
    rm(environment; recursive=true, force=true)
end

run_end_uptime = uptime_line()
load_samples = Float64[]
for record in records
    match_load = match(r"load average: ([0-9]+(?:\.[0-9]+)?)", record)
    match_load === nothing || push!(load_samples, parse(Float64, match_load.captures[1]))
end
for line in (run_start_uptime, run_end_uptime)
    match_load = match(r"load average: ([0-9]+(?:\.[0-9]+)?)", line)
    match_load === nothing || push!(load_samples, parse(Float64, match_load.captures[1]))
end
start_load = load_value(run_start_uptime)
end_load = load_value(run_end_uptime)
peak_load = isempty(load_samples) ? missing : maximum(load_samples)
load_gate_pass = start_load !== missing && end_load !== missing && peak_load !== missing &&
    peak_load <= 7.175 && end_load - start_load <= 2.56
load_gate_pass || push!(errors, "load gate failed: start=$(start_load) end=$(end_load) peak=$(peak_load)")

open(result_path, "a") do io
    println(io, "uptime_after_run=$(run_end_uptime)")
    println(io, "load_gate=$(load_gate_pass ? "PASS" : "FAIL") start=$(start_load) end=$(end_load) peak=$(peak_load)")
    if isempty(errors)
        println(io, "publishable=true")
        println(io, "differential=PASS")
    else
        println(io, "publishable=false")
        for failure in errors
            println(io, "failure=$(failure)")
        end
    end
    for record in records
        println(io, record)
    end
end
isempty(errors) || error("apply benchmark is not publishable")
println("deployed apply benchmark: PASS; artifact=$(result_path)")
