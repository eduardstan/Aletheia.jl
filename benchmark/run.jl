# Reproducible, human-run evaluation benchmark.  It is intentionally outside CI.
import Pkg
sole_path = get(ENV, "SOLELOGICS_PATH", "../SoleLogics.jl")
isdir(sole_path) || error("SoleLogics checkout not found at $sole_path; set SOLELOGICS_PATH")
Pkg.develop(Pkg.PackageSpec(path=sole_path)); Pkg.instantiate()
include(joinpath(@__DIR__, "common.jl"))
const RUN_START_NS = time_ns()

println("Aletheia vs SoleLogics evaluation benchmark")
println("Julia: ", VERSION)
println("CPU: ", Sys.CPU_NAME, " (", Sys.CPU_THREADS, " threads)")
println("SoleLogics checkout: ", sole_path)
println("mode: ", DEEP ? "deep" : "quick", "; seed: ", SEED)
println("samples: ", BENCH_SAMPLES, "; sampling budget: ", BENCH_SECONDS,
    " s; hard per-call timeout: ", CASE_TIMEOUT, " s")
println()

println("[correctness gate: differential semantic cases]")
# This is deliberately run before any timing.  It checks the comparable
# endpoint, per world, and catches representation mistakes in the harness.
for depth in (2, 4, 6)
    r = shared(depth); ap = pool_a(); a = build_a(r, ap); s = build_s(r)
    am = a_boolean_model(1, Tuple{Int,Int}[]); sm = s_boolean_model(1, Tuple{Int,Int}[])
    @assert Aletheia.check(a, am, 1) == SoleLogics.check(s, sm, first(SoleLogics.allworlds(SoleLogics.frame(sm))); perform_normalization=false)
end
rng_gate = MersenneTwister(SEED)
for trial in 1:(DEEP ? 192 : 96)
    n = rand(rng_gate, 2:10); density = rand(rng_gate); edges = edge_data(n, density, rand(rng_gate, 1:typemax(Int)))
    sets = Dict("p$(i)" => Set(w for w in 1:n if rand(rng_gate, Bool)) for i in 1:6)
    model = a_boolean_model(n, edges; sets=sets)
    p = modal_pool_a()
    quotient = Aletheia.bisimulation_contraction(model; atoms=collect(keys(sets)), relations=[:R])
    qmodel = Aletheia.model(quotient)
    for _ in 1:(DEEP ? 24 : 16)
        formula = build_a(random_recipe(rng_gate, rand(rng_gate, 1:5); modal=true), p)
        for world in Aletheia.worlds(Aletheia.frame(model))
            @assert Aletheia.check(formula, model, world) == Aletheia.check(formula, qmodel, Aletheia.contraction_world(quotient, world))
        end
    end
end
println("semantic differential: PASS; seed=$(SEED)")
println("contraction gate: PASS; models=$(DEEP ? 192 : 96)")

println("[syntax]")
for depth in (DEEP ? (3, 6, 9) : (2, 4))
    for (label, recipe_fn) in (("unshared", unshared), ("shared", shared))
        r = recipe_fn(depth)
        addrow!("construction/$label depth=$depth",
            guarded_measure("Sole construction $label depth=$depth", "construction", "incumbent", "$label:$depth"),
            guarded_measure("Aletheia construction $label depth=$depth", "construction", "aletheia", "$label:$depth"))
    end
    r = unshared(depth); pa = build_a(r, pool_a()); ps = build_s(r); text = Aletheia.syntaxstring(pa)
    addrow!("parsing depth=$depth", guarded_measure("Sole parsing depth=$depth", "parsing", "incumbent", "$depth"), guarded_measure("Aletheia parsing depth=$depth", "parsing", "aletheia", "$depth"))
    addrow!("printing depth=$depth", guarded_measure("Sole printing depth=$depth", "printing", "incumbent", "$depth"), guarded_measure("Aletheia printing depth=$depth", "printing", "aletheia", "$depth"))
    addrow!("round-trip depth=$depth", guarded_measure("Sole round-trip depth=$depth", "roundtrip", "incumbent", "$depth"), guarded_measure("Aletheia round-trip depth=$depth", "roundtrip", "aletheia", "$depth"))
end
for n in (DEEP ? (16, 128, 512) : (16, 64))
    addrow!("equality isequal chain=$n", guarded_measure("Sole isequal chain=$n", "equality", "incumbent", "$n"), guarded_measure("Aletheia equality chain=$n", "equality", "aletheia", "$n"))
end

println("[propositional check and extension]")
for depth in (DEEP ? (2, 4, 6, 8) : (2, 4, 6))
    addrow!("propositional check depth=$depth", guarded_measure("Sole propositional check depth=$depth", "prop_check", "incumbent", "$depth"), guarded_measure("Aletheia propositional check depth=$depth", "prop_check", "aletheia", "$depth"))
end
for (n, depth) in (DEEP ? ((8, 3), (32, 4), (128, 5), (256, 6)) : ((8, 3), (32, 4)))
    addrow!("extension finite model worlds=$n depth=$depth", guarded_measure("Sole all-world extension worlds=$n depth=$depth", "prop_extension", "incumbent", "$n:$depth"), guarded_measure("Aletheia BitVector extension worlds=$n depth=$depth", "prop_extension", "aletheia", "$n:$depth"), note="SoleLogics has no extension API; incumbent cell is the equivalent all-world check loop")
end

println("[random modal check; seed=$(SEED)]")
for n in (DEEP ? (8, 24, 64) : (8, 24)), density in (0.15, 0.50), depth in (DEEP ? (2, 4, 6) : (2, 4))
    arg = "$n:$density:$depth"
    addrow!("random modal check worlds=$n density=$density depth=$depth", guarded_measure("Sole modal check $arg", "modal_check", "incumbent", arg), guarded_measure("Aletheia modal check $arg", "modal_check", "aletheia", arg), note="fixed seed $(SEED); normalization disabled to isolate evaluator")
end

println("[interval / dimensional check]")
for n in (DEEP ? (6, 12, 24, 36) : (6, 12))
    addrow!("interval adjacency n=$n", guarded_measure("Sole interval adjacency n=$n", "interval_adjacency", "incumbent", "$n"), guarded_measure("Aletheia interval adjacency n=$n", "interval_adjacency", "aletheia", "$n"))
    addrow!("Allen BEFORE check n=$n", guarded_measure("Sole Allen check n=$n", "interval_check", "incumbent", "$n"), guarded_measure("Aletheia Allen check n=$n", "interval_check", "aletheia", "$n"), note="Aletheia BEFORE / SoleLogics IA_L")
end

println("[many-valued check]")
for algebra_name in ("godel", "lukasiewicz"), depth in (DEEP ? (2, 4, 6) : (2, 4))
    addrow!("finite chain $algebra_name value depth=$depth", guarded_measure("Sole $algebra_name value depth=$depth", "many_check", "incumbent", "$algebra_name:$depth"), guarded_measure("Aletheia $algebra_name check depth=$depth", "many_check", "aletheia", "$algebra_name:$depth"), note="SoleLogics check is threshold-valued; comparable row uses its interpret value path (G3/Ł3)")
end
println("many-valued non-chain: pending — this checkout has no src/algebras.jl finite non-chain implementation; no row is fabricated")

println("[learning from interpretations]")
for (model_count, hypothesis_count) in (DEEP ? ((8, 4), (32, 12), (64, 24)) : ((8, 4), (32, 12)))
    arg = "$model_count:$hypothesis_count"
    addrow!("ILP interpretation scoring models=$model_count hypotheses=$hypothesis_count", guarded_measure("Sole interpretation scoring $arg", "ilp_score", "incumbent", arg), guarded_measure("Aletheia interpretation scoring $arg", "ilp_score", "aletheia", arg), note="same seeded models; loops hypotheses × interpretation examples through check/eval")
end

println("[bisimulation contraction amortisation]")
println("incumbent: unsupported — SoleLogics v0.13.7 has no bisimulation contraction API")
println("n | quotient | ratio | C | P_orig | P_quot | K* | measured crossover (K: orig ms / quotient ms)")
for n in (DEEP ? (96, 192, 384) : (48,)), q in (DEEP ? (1, 4, 16, n) : (1, 16, n))
    q > n && continue
    c = guarded_measure("contraction cost n=$n q=$q", "contraction_cost", "aletheia", "$n:$q")
    po = parse_ratio_measurements([guarded_measure("original check n=$n q=$q formula=$i", "contraction_orig", "aletheia", "$n:$q:$(i):8") for i in 1:5])
    pq = parse_ratio_measurements([guarded_measure("quotient check n=$n q=$q formula=$i", "contraction_quot", "aletheia", "$n:$q:$(i):8") for i in 1:5])
    ratio = q / n
    delta = po.time === missing || pq.time === missing ? missing : po.time - pq.time
    kstar = delta === missing || delta <= 0 ? Inf : c.time / delta
    println("$n | $q | $(@sprintf("%.3f", ratio)) | $(fmt_measure(c)) | $(fmt_measure(po)) | $(fmt_measure(pq)) | $(isfinite(kstar) ? @sprintf("%.1f", kstar) : "∞") | ")
    for k in (1, 2, 4, 8, 16, 32, 64)
        bo = guarded_measure("measured original curve n=$n q=$q K=$k", "contraction_batch_orig", "aletheia", "$n:$q:8:$k")
        bq = guarded_measure("measured quotient curve n=$n q=$q K=$k", "contraction_batch_quot", "aletheia", "$n:$q:8:$k")
        println("  K=$k: $(bo.time === missing ? "timeout" : @sprintf("%.3f", bo.time / 1e6)) ms / $(bq.time === missing ? "timeout" : @sprintf("%.3f", (c.time + bq.time) / 1e6)) ms (quotient includes C)")
    end
end

println("[cold package load]")
load_a = raw"""t0=time_ns(); using Aletheia; t1=time_ns(); s=Aletheia.Signature((Aletheia.NEGATION,Aletheia.CONJUNCTION,Aletheia.DISJUNCTION,Aletheia.IMPLICATION)); p=Aletheia.FormulaPool(s); Aletheia.syntaxstring(Aletheia.parse(p, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
load_s = raw"""t0=time_ns(); using SoleLogics; t1=time_ns(); SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
la = external_measure(load_a); ls = external_measure(load_s)
cold_measure(x, i) = x === nothing ? Measurement(missing, missing, missing, "unavailable") : Measurement(x[i] * 1e6, missing, missing)
addrow!("cold package load", cold_measure(ls, 1), cold_measure(la, 1); allocations=false)
addrow!("cold time-to-first-result", cold_measure(ls, 2), cold_measure(la, 2); allocations=false)

println(); print_report(); println("benchmark wall clock: ", @sprintf("%.1f s", (time_ns() - RUN_START_NS) / 1e9))
