# Human-run benchmark command; intentionally not part of package CI.
import Pkg
sole_path = get(ENV, "SOLELOGICS_PATH", "/home/eduard/Dropbox/Projects/firstmate/projects/SoleLogics.jl")
isdir(sole_path) || error("SoleLogics checkout not found at $sole_path; set SOLELOGICS_PATH")
Pkg.develop(Pkg.PackageSpec(path=sole_path))
Pkg.instantiate()
include(joinpath(@__DIR__, "common.jl"))

println("Aletheia vs SoleLogics benchmark")
println("Julia: ", VERSION)
println("CPU: ", Sys.CPU_NAME, " (", Sys.CPU_THREADS, " threads)")
println("SoleLogics checkout: ", sole_path)
println("mode: ", DEEP ? "deep" : "quick")
println("BenchmarkTools samples: ", BENCH_SAMPLES, ", budget: ", BENCH_SECONDS, " s per case")
println()

# Construction: balanced formulas, with and without repeated subterms.
println("[construction]")
for depth in (DEEP ? (3, 6, 9) : (2, 4, 6))
    for (label, recipe_fn) in (("unshared", unshared), ("shared", shared))
        r = recipe_fn(depth)
        inc = guarded_measure("$label incumbent construction depth=$depth", "construction", "incumbent", "$label:$depth", () -> build_s(r))
        ale = guarded_measure("$label Aletheia construction depth=$depth", "construction", "aletheia", "$label:$depth", () -> build_a(r, pool_a()))
        addrow!("construction/$label depth=$depth", inc, ale)
    end
end

# Parsing, printing, and round-trip over a size range.
println("[parse/print]")
# The text is generated
# once, outside the timed region, and is identical input for both parsers.
for depth in (DEEP ? (2, 5, 8) : (2, 4, 6))
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

# Equality is measured on equal deep chains.
println("[equality]")
# This is deliberately a range,
# not a cherry-picked size.  Both sides are independently constructed.
for n in (DEEP ? (16, 128, 512, 1024) : (16, 64, 256))
    r = chain(n)
    ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap)
    s = build_s(r); t = build_s(r)
    addrow!("equality isequal chain=$n",
        guarded_measure("incumbent isequal chain=$n", "equality", "incumbent", "$n", () -> isequal(s, t)),
        guarded_measure("Aletheia equality chain=$n", "equality", "aletheia", "$n", () -> isequal(a, b)))
end
# SoleLogics has a striking, separately reported == pathology: its generic
# structural == can fail to return even where its explicit isequal does.
for n in (DEEP ? (8, 16, 24, 32, 64, 128) : (8, 16, 24, 32, 64))
    r = chain(n); ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap)
    s = build_s(r); t = build_s(r)
    addrow!("equality == chain=$n",
        guarded_pair("incumbent == chain=$n", "equality_eq", "incumbent", "$n"),
        guarded_pair("Aletheia == chain=$n", "equality_eq", "aletheia", "$n"))
end

# Modal breadth now has one deterministic interval-temporal case. Both sides
# go through the process-boundary timeout guard; the incumbent's structural
# operations are never allowed to hang the benchmark process.
println("[interval-temporal]")
interval_n = DEEP ? 12 : 6
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
interval_sizes = DEEP ? (8, 16, 32) : (6, 12, 24)
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

# Remaining semantic extensions are intentionally named, so future benchmark
# reports do not silently imply coverage that has not landed yet.
for suite in ("propositional checking (stage 2: semantics)",
              "modal checking / random Kripke structures (later stage)",
              "many-valued checking (later stage)")
    addrow!(suite, missing, missing)
end

println("[cold load]")
# Cold-process timings are intentionally not BenchmarkTools trials: a package
# must be loaded in a fresh Julia process to measure load and first result.
load_a = raw"""t0=time_ns(); using Aletheia; t1=time_ns(); s=Aletheia.Signature((Aletheia.NEGATION,Aletheia.CONJUNCTION,Aletheia.DISJUNCTION,Aletheia.IMPLICATION)); p=Aletheia.FormulaPool(s); Aletheia.syntaxstring(Aletheia.parse(p, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
load_s = raw"""t0=time_ns(); using SoleLogics; t1=time_ns(); SoleLogics.syntaxstring(SoleLogics.parseformula("p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
la = external_measure(load_a)
ls = external_measure(load_s)
cold_measure(x, i) = x === nothing ? missing : Measurement(x[i] * 1e6, missing, missing)
addrow!("cold package load", cold_measure(ls, 1), cold_measure(la, 1); allocations=false)
addrow!("cold time-to-first-result", cold_measure(ls, 2), cold_measure(la, 2); allocations=false)

println()
print_report()
