using BenchmarkTools
using Printf
using Random
using Statistics
using Aletheia
using SoleLogics

const DEEP = "--deep" in ARGS
# Quick mode is intentionally bounded for a human-run default.  --deep is an
# opt-in diagnostic mode, never used by the README's reproducibility command.
const BENCH_SECONDS = DEEP ? 0.05 : 0.01
const BENCH_SAMPLES = DEEP ? 15 : 5
const SIGNATURE = Aletheia.Signature((Aletheia.NEGATION, Aletheia.CONJUNCTION,
    Aletheia.DISJUNCTION, Aletheia.IMPLICATION))
const AOPS = Dict(:not => Aletheia.NEGATION, :and => Aletheia.CONJUNCTION,
    :or => Aletheia.DISJUNCTION, :implies => Aletheia.IMPLICATION)
const SOPS = Dict(:not => SoleLogics.:(¬), :and => SoleLogics.:(∧),
    :or => SoleLogics.:(∨), :implies => SoleLogics.:(→))

struct Recipe
    op::Symbol
    children::Tuple
    atom::Union{Nothing,String}
end
atomrecipe(name) = Recipe(:atom, (), String(name))
recipe(op, children...) = Recipe(op, children, nothing)

function unshared(depth, counter = Ref(0))
    depth == 0 && begin
        counter[] += 1
        return atomrecipe("p$(counter[])")
    end
    recipe(:and, unshared(depth - 1, counter), unshared(depth - 1, counter))
end
function shared(depth)
    depth == 0 && return atomrecipe("p")
    child = shared(depth - 1)
    recipe(:and, child, child)
end
function chain(n)
    result = atomrecipe("p")
    for i in 1:n
        result = recipe(:not, result)
    end
    result
end

function build_a(r::Recipe, pool)
    r.op === :atom && return Aletheia.atom(pool, r.atom)
    Aletheia.branch(pool, AOPS[r.op], (build_a(c, pool) for c in r.children)...)
end
function build_s(r::Recipe)
    r.op === :atom && return SoleLogics.Atom(r.atom)
    SoleLogics.SyntaxBranch(SOPS[r.op], (build_s(c) for c in r.children)...)
end

function pool_a()
    Aletheia.FormulaPool(SIGNATURE)
end

# A canonical representation independent of package-specific formula handles.
canonical(f::Aletheia.Atom) = (:atom, Aletheia.value(f))
function canonical(f::Aletheia.Branch)
    (:branch, Aletheia.notation(Aletheia.operator(f)), canonical.(Aletheia.children(f)))
end
canonical(f::SoleLogics.Atom) = (:atom, SoleLogics.value(f))
function canonical(f::SoleLogics.SyntaxBranch)
    (:branch, SoleLogics.syntaxstring(SoleLogics.token(f)), canonical.(SoleLogics.children(f)))
end

struct Measurement
    time::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
    note::String
end
Measurement(time, allocs, memory) = Measurement(time, allocs, memory, "")

function measure(f; seconds=BENCH_SECONDS, samples=BENCH_SAMPLES)
    trial = run(@benchmarkable $f() seconds=seconds samples=samples evals=1)
    m = median(trial)
    Measurement(Float64(m.time), Int(m.allocs), Int(m.memory))
end

# BenchmarkTools cannot preempt one evaluation.  A fresh helper process is the
# wall-clock guard: a pathological incumbent call is killed at ten seconds and
# the case is retained as an explicit unmeasured result.
function warmup_case(kind, side, argument)
    project = @__DIR__
    julia = Base.julia_cmd()
    helper = joinpath(@__DIR__, "warmup.jl")
    command = `timeout -k 1s 10s $julia --startup-file=no --project=$project $helper $kind $side $argument`
    path, io = mktemp()
    close(io)
    process = run(pipeline(command, stdout=path, stderr=devnull); wait=false)
    wait(process)
    output = read(path, String)
    rm(path; force=true)
    (process.exitcode, output)
end
function guarded_measure(label, kind, side, argument, f)
    println("[case] ", label)
    flush(stdout)
    status, _ = warmup_case(kind, side, argument)
    status == 124 && return Measurement(missing, missing, missing, ">10s (not sampled)")
    status == 0 || error("warm-up failed for $label (exit code $status)")
    measure(f)
end
function guarded_pair(label, kind, side, argument)
    println("[case] ", label)
    flush(stdout)
    status, output = warmup_case(kind, side, argument)
    status == 124 && return Measurement(missing, missing, missing, ">10s first call (second unavailable)")
    status == 0 || error("warm-up failed for $label (exit code $status)")
    values = parse.(Float64, split(strip(output)))
    length(values) == 2 || error("expected first/second timings for $label: $(repr(output))")
    first_ms, second_ms = values
    note = @sprintf("first %.3f ms; second %.3f ms; not sampled", first_ms, second_ms)
    Measurement(second_ms * 1_000_000, missing, missing, note)
end
function external_measure(code; reps=DEEP ? 2 : 1)
    project = @__DIR__
    julia = Base.julia_cmd()
    values = Tuple{Float64,Float64}[]
    for _ in 1:reps
        command = `timeout -k 1s 30s $julia --startup-file=no --project=$project -e $code`
        output = read(command, String)
        parts = split(strip(output))
        length(parts) >= 2 || error("cold-process timing failed: $(repr(output))")
        push!(values, (parse(Float64, parts[1]), parse(Float64, parts[2])))
    end
    (median(first.(values)), median(last.(values)))
end

function fmt_time(x)
    x === missing && return "empty"
    x < 1_000 ? @sprintf("%.1f ns", x) : x < 1_000_000 ? @sprintf("%.2f μs", x / 1_000) : @sprintf("%.2f ms", x / 1_000_000)
end
function fmt_measure(m)
    m.time === missing ? m.note : isempty(m.note) ? fmt_time(m.time) : "$(fmt_time(m.time)) [$(m.note)]"
end
function fmt_alloc(x)
    x === missing && return "—"
    "$(x) ($(Base.format_bytes(0))?)"
end

const rows = NamedTuple[]
function addrow!(suite, inc, ale; allocations=true)
    ratio = inc === missing || ale === missing ? missing : inc.time / ale.time
    push!(rows, (suite=suite, incumbent=inc, aletheia=ale, ratio=ratio, allocations=allocations))
end
function print_report()
    println("suite | SoleLogics median | Aletheia median | ratio (S/A) | allocations (Sole/Aletheia)")
    println("------|--------------------|-----------------|--------------|--------------------------")
    for row in rows
        if row.incumbent === missing
            println("$(row.suite) | empty (later stage) | empty (later stage) | — | —")
        else
            inc, ale = row.incumbent, row.aletheia
            alloc = row.allocations ? "$(inc.allocs === missing ? "—" : inc.allocs)/$(ale.allocs === missing ? "—" : ale.allocs)" : "—/—"
            println("$(row.suite) | $(fmt_measure(inc)) | $(fmt_measure(ale)) | $(row.ratio === missing ? "—" : @sprintf("%.2fx", row.ratio)) | $alloc")
        end
    end
end
