# Human-run benchmark command; intentionally not part of package CI.
import Pkg
sole_path = get(ENV, "SOLELOGICS_PATH", "../SoleLogics.jl")
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

# Deliberately empty extension points.  A row is printed rather than silently
# omitted, so a report cannot imply that later semantic stages were measured.
for suite in ("propositional checking (stage 2: semantics)",
              "modal checking / random Kripke structures (stage 2)",
              "interval-temporal checking / dimensional frames (stage 2)",
              "many-valued checking (stage 2)")
    addrow!(suite, missing, missing)
end

println("[cold load]")
# Cold-process timings are intentionally not BenchmarkTools trials: a package
# must be loaded in a fresh Julia process to measure load and first result.
load_a = raw"""t0=time_ns(); using Aletheia; t1=time_ns(); s=Aletheia.Signature((Aletheia.NEGATION,Aletheia.CONJUNCTION,Aletheia.DISJUNCTION,Aletheia.IMPLICATION)); p=Aletheia.FormulaPool(s); Aletheia.syntaxstring(Aletheia.parse(p, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
load_s = raw"""t0=time_ns(); using SoleLogics; t1=time_ns(); SoleLogics.syntaxstring(SoleLogics.parseformula("p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
la = external_measure(load_a)
ls = external_measure(load_s)
addrow!("cold package load", Measurement(ls[1] * 1e6, missing, missing), Measurement(la[1] * 1e6, missing, missing); allocations=false)
addrow!("cold time-to-first-result", Measurement(ls[2] * 1e6, missing, missing), Measurement(la[2] * 1e6, missing, missing); allocations=false)

println()
print_report()
