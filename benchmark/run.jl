# Human-run benchmark command; intentionally not part of package CI.
import Pkg
using Printf

const BENCHMARK_START_NS = time_ns()
function progress(message)
    elapsed = (time_ns() - BENCHMARK_START_NS) / 1e9
    println("[progress +", @sprintf("%.1fs", elapsed), "] ", message)
    flush(stdout)
end
function stage_start(name)
    println("[", name, "]")
    progress(name * " started")
    time_ns()
end
function stage_finish(name, started)
    elapsed = (time_ns() - started) / 1e9
    progress(name * " finished in " * @sprintf("%.2fs", elapsed))
end

progress("checking SoleLogics checkout")
sole_path = get(ENV, "SOLELOGICS_PATH", "../SoleLogics.jl")
isdir(sole_path) || error("SoleLogics checkout not found at $sole_path; set SOLELOGICS_PATH")
progress("developing SoleLogics into the benchmark environment")
Pkg.develop(Pkg.PackageSpec(path=sole_path))
progress("instantiating benchmark dependencies")
Pkg.instantiate()
progress("loading benchmark helpers")
include(joinpath(@__DIR__, "common.jl"))

println("Aletheia vs SoleLogics benchmark")
println("Julia: ", VERSION)
println("CPU: ", Sys.CPU_NAME, " (", Sys.CPU_THREADS, " threads)")
println("SoleLogics checkout: ", sole_path)
println("mode: ", DEEP ? "deep" : SMOKE ? "smoke" : "quick")
println("BenchmarkTools samples: ", BENCH_SAMPLES, ", budget: ", BENCH_SECONDS, " s per case")
println("progress: stage and case elapsed times are reported on stdout")
println()
progress("benchmark measurements started")
smoke_skipped(note) = Measurement(missing, missing, missing, "smoke skipped (" * note * ")")

# Construction: balanced formulas, with and without repeated subterms.
stage_started = stage_start("construction")
construction_depths = DEEP ? (3, 6, 9) : SMOKE ? (2,) : (2, 4, 6)
for depth in construction_depths
    for (label, recipe_fn) in (("unshared", unshared), ("shared", shared))
        r = recipe_fn(depth)
        inc = guarded_measure("$label incumbent construction depth=$depth", "construction", "incumbent", "$label:$depth", () -> build_s(r))
        ale = guarded_measure("$label Aletheia construction depth=$depth", "construction", "aletheia", "$label:$depth", () -> build_a(r, pool_a()))
        addrow!("construction/$label depth=$depth", inc, ale)
    end
end
stage_finish("construction", stage_started)

# Parsing, printing, and round-trip over a size range.
stage_started = stage_start("parse/print")
parse_depths = DEEP ? (2, 5, 8) : SMOKE ? (2,) : (2, 4, 6)
# The text is generated
# once, outside the timed region, and is identical input for both parsers.
for depth in parse_depths
    r = unshared(depth)
    pa = build_a(r, pool_a())
    ps = build_s(r)
    text = Aletheia.syntaxstring(pa)
    inc_parse = guarded_measure("incumbent parsing depth=$depth", "parsing", "incumbent", "$depth", () -> SoleLogics.parseformula(SoleLogics.SyntaxTree, text))
    ale_parse = guarded_measure("Aletheia parsing depth=$depth", "parsing", "aletheia", "$depth", () -> Aletheia.parse(pool_a(), text))
    addrow!("parsing depth=$depth", inc_parse, ale_parse)
    addrow!("printing depth=$depth", guarded_measure("incumbent printing depth=$depth", "printing", "incumbent", "$depth", () -> SoleLogics.syntaxstring(ps)), guarded_measure("Aletheia printing depth=$depth", "printing", "aletheia", "$depth", () -> Aletheia.syntaxstring(pa)))
    addrow!("round-trip depth=$depth",
        guarded_measure("incumbent round-trip depth=$depth", "roundtrip", "incumbent", "$depth", () -> SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, text))),
        guarded_measure("Aletheia round-trip depth=$depth", "roundtrip", "aletheia", "$depth", () -> Aletheia.syntaxstring(Aletheia.parse(pool_a(), text))))
end
stage_finish("parse/print", stage_started)

# Equality is measured on equal deep chains.
stage_started = stage_start("equality")
# This is deliberately a range,
# not a cherry-picked size.  Both sides are independently constructed.
equality_isequal_sizes = DEEP ? (16, 128, 512, 1024) : SMOKE ? (16,) : (16, 64, 256)
for n in equality_isequal_sizes
    r = chain(n)
    ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap)
    s = build_s(r); t = build_s(r)
    addrow!("equality isequal chain=$n",
        guarded_measure("incumbent isequal chain=$n", "equality", "incumbent", "$n", () -> isequal(s, t)),
        guarded_measure("Aletheia equality chain=$n", "equality", "aletheia", "$n", () -> isequal(a, b)))
end
# SoleLogics has a striking, separately reported == pathology: its generic
# structural == can fail to return even where its explicit isequal does.
equality_operator_sizes = DEEP ? (8, 16, 24, 32, 64, 128) : SMOKE ? (8,) : (8, 16, 24, 32, 64)
for n in equality_operator_sizes
    r = chain(n); ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap)
    s = build_s(r); t = build_s(r)
    addrow!("equality == chain=$n",
        guarded_pair("incumbent == chain=$n", "equality_eq", "incumbent", "$n"),
        guarded_pair("Aletheia == chain=$n", "equality_eq", "aletheia", "$n"))
end
stage_finish("equality", stage_started)

# Modal breadth now has one deterministic interval-temporal case. Both sides
# go through the process-boundary timeout guard; the incumbent's structural
# operations are never allowed to hang the benchmark process.
stage_started = stage_start("interval-temporal")
interval_n = DEEP ? 12 : SMOKE ? 4 : 6
interval_inc = guarded_measure("SoleLogics interval relation", "interval", "incumbent", string(interval_n),
    () -> begin
        sf = SoleLogics.FullDimensionalFrame((interval_n,), SoleLogics.Interval{Int})
        sw = first(SoleLogics.allworlds(sf))
        collect(SoleLogics.accessibles(sf, sw, SoleLogics.IA_L))
    end)
interval_ale = guarded_measure("Aletheia interval relation", "interval", "aletheia", string(interval_n),
    () -> begin
        af = Aletheia.interval_frame(interval_n)
        aw = first(Aletheia.worlds(af))
        collect(Aletheia.accessible(af, aw, Aletheia.BEFORE))
    end)
addrow!("interval-temporal / generated IA-before", interval_inc, interval_ale)

# The single-query footnote above is followed by evaluator-relevant rows.
# Adjacency rows isolate the one-time graph build; check rows create a fresh
# model per evaluation so that model-local adjacency construction is included.
interval_sizes = DEEP ? (8, 16, 32) : SMOKE ? (4,) : (6, 12, 24)
for n in interval_sizes
    af, aws, aformula, aval = interval_check_a_setup(n)
    sf, sws, sformula, sval = interval_check_s_setup(n)
    adjacency_inc = guarded_measure("SoleLogics full interval adjacency n=$n",
        "interval_adjacency", "incumbent", string(n),
        () -> interval_adjacency_s(sf, SoleLogics.IA_L, sws))
    adjacency_ale = guarded_measure("Aletheia full interval adjacency n=$n",
        "interval_adjacency", "aletheia", string(n),
        () -> interval_adjacency_a(af, Aletheia.BEFORE, aws))
    addrow!("interval-temporal / full adjacency n=$n", adjacency_inc, adjacency_ale)
    check_inc = guarded_measure("SoleLogics end-to-end interval check n=$n",
        "interval_check", "incumbent", string(n),
        () -> SoleLogics.check(sformula, SoleLogics.KripkeStructure(sf, sval), first(sws)))
    check_ale = guarded_measure("Aletheia end-to-end interval check n=$n",
        "interval_check", "aletheia", string(n),
        () -> Aletheia.check(aformula, Aletheia.Model(af, Aletheia.BOOLEAN, aval), first(aws)))
    addrow!("interval-temporal / end-to-end check n=$n", check_inc, check_ale)
end
stage_finish("interval-temporal", stage_started)

# Remaining semantic extensions are intentionally named, so future benchmark
# reports do not silently imply coverage that has not landed yet.

# Theory measurement: on a redundant dense frame, compare raw checking with
# contraction plus checking (including quotient construction); it does not call
# the incumbent.
stage_started = stage_start("theory contraction")
if SMOKE
    raw_theory = smoke_skipped("theory contraction")
    contracted_theory = smoke_skipped("theory contraction")
else
    theory_signature = Aletheia.Signature((Aletheia.NEGATION, Aletheia.CONJUNCTION,
        Aletheia.DISJUNCTION, Aletheia.IMPLICATION, Aletheia.Box(:R)))
    theory_pool = Aletheia.FormulaPool(theory_signature)
    theory_atom = Aletheia.atom(theory_pool, "p")
    theory_formula = Aletheia.branch(theory_pool, Aletheia.Box(:R),
        Aletheia.branch(theory_pool, Aletheia.Box(:R), theory_atom))
    theory_worlds = ntuple(identity, DEEP ? 800 : 600)
    theory_targets = Dict(world => theory_worlds for world in theory_worlds)
    theory_frame = Aletheia.Frame(theory_worlds, Dict(:R => theory_targets); index=true)
    theory_model = Aletheia.Model(theory_frame, Aletheia.BOOLEAN,
        Dict("p" => Set(theory_worlds)))
    raw_theory = measure(() -> Aletheia.check(theory_formula, theory_model, 1))
    contracted_theory = measure(() -> begin
        quotient = Aletheia.bisimulation_contraction(theory_model; atoms=["p"], relations=[:R])
        Aletheia.check(theory_formula, quotient, 1)
    end)
end
addrow!("theory raw check / contraction + check", raw_theory, contracted_theory)
stage_finish("theory contraction", stage_started)

# Deliberately empty extension points.  A row is printed rather than silently
# omitted, so a report cannot imply that later semantic stages were measured.
for suite in ("propositional checking (stage 2: semantics)",
              "modal checking / random Kripke structures (later stage)",
              "many-valued checking (later stage)")
    addrow!(suite, missing, missing)
end

stage_started = stage_start("cold load")
if SMOKE
    # Cold subprocess timing is intentionally omitted: smoke is a loaded-process
    # preflight, while the normal/deep path retains the cold-load rows.
    addrow!("cold package load", smoke_skipped("cold subprocess timing"), smoke_skipped("cold subprocess timing"); allocations=false)
    addrow!("cold time-to-first-result", smoke_skipped("cold subprocess timing"), smoke_skipped("cold subprocess timing"); allocations=false)
else
    # Cold-process timings are intentionally not BenchmarkTools trials: a package
    # must be loaded in a fresh Julia process to measure load and first result.
    load_a = raw"""t0=time_ns(); using Aletheia; t1=time_ns(); s=Aletheia.Signature((Aletheia.NEGATION,Aletheia.CONJUNCTION,Aletheia.DISJUNCTION,Aletheia.IMPLICATION)); p=Aletheia.FormulaPool(s); Aletheia.syntaxstring(Aletheia.parse(p, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
    load_s = raw"""t0=time_ns(); using SoleLogics; t1=time_ns(); SoleLogics.syntaxstring(SoleLogics.parseformula("p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
    la = external_measure(load_a)
    ls = external_measure(load_s)
    cold_measure(x, i) = x === nothing ? missing : Measurement(x[i] * 1e6, missing, missing)
    addrow!("cold package load", cold_measure(ls, 1), cold_measure(la, 1); allocations=false)
    addrow!("cold time-to-first-result", cold_measure(ls, 2), cold_measure(la, 2); allocations=false)
end
stage_finish("cold load", stage_started)

println()
print_report()
SMOKE && println("benchmark smoke: PASS (syntax/equality rows; interval/theory/cold rows skipped)")
progress("benchmark complete: $(length(rows)) rows; total elapsed " * @sprintf("%.2fs", (time_ns() - BENCHMARK_START_NS) / 1e9))
