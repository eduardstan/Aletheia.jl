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
    "aletheia-vectorized-construction", "aletheia-vectorized",
    "aletheia-data-bridge-scalar-construction", "aletheia-data-bridge-scalar",
    "aletheia-data-bridge-vectorized-construction", "aletheia-data-bridge-vectorized",
    "aletheia-data-scalar-construction", "aletheia-data-scalar",
    "aletheia-data-vectorized-construction", "aletheia-data-vectorized")
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
        println(io, "scale_cases=32:8,64:8,128:8,256:8,512:8; scale_modes=decision-list-apply,aletheia-scalar,aletheia-vectorized; scale_timeout_s=900; scale_samples=3; scale_address_space_kb=6000000")
        println(io, "profile=Profile.Allocs sample_rate=1 on one never-used fresh-dataset churn apply; vectorized callback versus native decision-list apply")
        println(io, "sole_controls=full_memo=true one_step_memo=true global_precompute=true relational_precompute=false")
        println(io, "sole_paths=formula-check=SoleData.check; modal-tree=ModalDecisionTrees.apply/modalstep/checkcondition; decision-list=SoleModels.apply/SoleLogics.check")
        println(io, "aletheia_path=DecisionListBatchAdapter prepared model family; callback scalar/vectorized and DenseFeatureStore scalar/vectorized paths; conversion outside apply timing")
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

    # Scaling compares only native decision-list apply with the two prepared
    # Aletheia callbacks. Each case retains all five seeded rows.
    for (ninstances, npoints) in ((32, 8), (64, 8), (128, 8), (256, 8), (512, 8))
        before = quiet_check(uptime_line())
        outpath, outio = mktemp(ROOT); close(outio)
        errpath, errio = mktemp(ROOT); close(errio)
        command = `timeout -k 1s 900s systemd-run --user --scope -q -p MemoryMax=6G
            /usr/bin/time -v nice -n 15 $(julia) --startup-file=no --project=$environment
            $(joinpath(@__DIR__, "deployed_apply_scale_worker.jl")) $ninstances $npoints`
        process = run(pipeline(command, stdout=outpath, stderr=errpath); wait=false)
        wait(process)
        output = read(outpath, String)
        stderr = read(errpath, String)
        rm(outpath; force=true); rm(errpath; force=true)
        after = uptime_line()
        maxrss_match = match(r"Maximum resident set size \(kbytes\):\s*(\d+)", stderr)
        maxrss = maxrss_match === nothing ? "unavailable" : maxrss_match.captures[1]
        push!(records, "scale-section=instances=$(ninstances),points=$(npoints) maxrss_kb=$(maxrss) uptime_before=$(before) uptime_after=$(after)")
        scale_lines = [strip(line) for line in split(output, '\n')
            if startswith(strip(line), "scale-result ") || startswith(strip(line), "scale-parity=")]
        if process.exitcode == 124
            push!(records, "scale-skip=instances=$(ninstances),points=$(npoints),reason=timeout maxrss_kb=$(maxrss) uptime_before=$(before) uptime_after=$(after)")
        elseif process.exitcode in (137, 9) || occursin("Killed process", stderr) ||
                occursin("Cannot allocate memory", stderr) || occursin("Resource temporarily unavailable", stderr)
            push!(records, "scale-skip=instances=$(ninstances),points=$(npoints),reason=memory maxrss_kb=$(maxrss) uptime_before=$(before) uptime_after=$(after)")
        elseif process.exitcode != 0
            push!(errors, "scale section instances=$(ninstances),points=$(npoints) exit=$(process.exitcode): $(strip(stderr))")
        elseif isempty(scale_lines)
            push!(errors, "scale section instances=$(ninstances),points=$(npoints) emitted no result")
        else
            append!(records, ["$line uptime_before=$(before) uptime_after=$(after)" for line in scale_lines])
        end
    end

    before = quiet_check(uptime_line())
    outpath, outio = mktemp(ROOT); close(outio)
    errpath, errio = mktemp(ROOT); close(errio)
    profile_command = `timeout -k 1s 180s nice -n 15 $(julia) --startup-file=no --project=$environment $(joinpath(@__DIR__, "deployed_apply_profile_worker.jl"))`
    profile_process = run(pipeline(profile_command, stdout=outpath, stderr=errpath); wait=false)
    wait(profile_process)
    profile_output = read(outpath, String)
    profile_stderr = read(errpath, String)
    rm(outpath; force=true); rm(errpath; force=true)
    after = uptime_line()
    push!(records, "profile-section uptime_before=$(before) uptime_after=$(after)")
    profile_lines = [strip(line) for line in split(profile_output, '\n')
        if startswith(strip(line), "profile ") || startswith(strip(line), "profile-site ") || startswith(strip(line), "profile-site-source ") || startswith(strip(line), "profile-top-source ") || startswith(strip(line), "profile-cold ") || startswith(strip(line), "profile-note=")]
    profile_process.exitcode == 0 || push!(errors, "profile section exit=$(profile_process.exitcode): $(strip(profile_stderr))")
    isempty(profile_lines) && push!(errors, "profile section emitted no attribution")
    append!(records, ["$line uptime_before=$(before) uptime_after=$(after)" for line in profile_lines])
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
