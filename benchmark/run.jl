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
println("samples: ", BENCH_SAMPLES, "; fixed-sample timing (legacy budget: ", BENCH_SECONDS,
    " s); hard per-call timeout: ", CASE_TIMEOUT, " s")
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
function add_section_rows!(section, labels, cases; note="")
    incumbent = section_measure(section, cases, "incumbent")
    aletheia = section_measure(section, cases, "aletheia")
    for i in eachindex(labels)
        addrow!(labels[i], incumbent[i], aletheia[i]; note=note)
    end
end
syntax_cases = Tuple{String,String}[]; syntax_labels = String[]
for depth in (DEEP ? (3, 6, 9) : (2,))
    for label in ("unshared", "shared")
        push!(syntax_cases, ("construction", "$label:$depth")); push!(syntax_labels, "construction/$label depth=$depth")
    end
    for (kind, name) in (("parsing", "parsing"), ("printing", "printing"), ("roundtrip", "round-trip"))
        push!(syntax_cases, (kind, "$depth")); push!(syntax_labels, "$name depth=$depth")
    end
end
for n in (DEEP ? (16, 128, 512) : (16,))
    push!(syntax_cases, ("equality", "$n")); push!(syntax_labels, "equality isequal chain=$n")
end
add_section_rows!("syntax", syntax_labels, syntax_cases)

println("[propositional check and extension]")
prop_cases = [("prop_check", string(depth)) for depth in (DEEP ? (2, 4, 6, 8) : (2, 4, 6))]
add_section_rows!("propositional check", ["propositional check depth=$(arg)" for (_, arg) in prop_cases], prop_cases)
ext_cases = [("prop_extension", "$n:$depth") for (n, depth) in (DEEP ? ((8, 3), (32, 4), (128, 5), (256, 6)) : ((8, 3), (32, 4)))]
add_section_rows!("extension", ["extension finite model worlds=$(split(arg, ':')[1]) depth=$(split(arg, ':')[2])" for (_, arg) in ext_cases], ext_cases;
    note="SoleLogics has no extension API; incumbent cell is the equivalent all-world check loop")

println("[random modal check; seed=$(SEED)]")
modal_cases = [("modal_check", "$n:$density:$depth") for n in (DEEP ? (8, 24, 64) : (8, 24)), density in (0.15, 0.50), depth in (DEEP ? (2, 4, 6) : (2, 4))]
add_section_rows!("random modal check", ["random modal check worlds=$(split(arg, ':')[1]) density=$(split(arg, ':')[2]) depth=$(split(arg, ':')[3])" for (_, arg) in modal_cases], modal_cases;
    note="fixed seed $(SEED); normalization disabled to isolate evaluator")

println("[interval / dimensional check]")
interval_cases = Tuple{String,String}[]; interval_labels = String[]
for n in (DEEP ? (6, 12, 24, 36) : (6,))
    push!(interval_cases, ("interval_adjacency", string(n))); push!(interval_labels, "interval adjacency n=$n")
    push!(interval_cases, ("interval_check", string(n))); push!(interval_labels, "Allen BEFORE check n=$n")
end
for name in ("ia3", "ia7", "rcc5")
    push!(interval_cases, ("interval_subset", "$name:6")); push!(interval_labels, "interval subset $name n=6")
end
add_section_rows!("interval / dimensional", interval_labels, interval_cases;
    note="Aletheia direct canonical traversal / SoleLogics arithmetic range traversal")

println("[many-valued check]")
mv_cases = [("many_check", "$algebra_name:$depth") for algebra_name in ("godel", "lukasiewicz", "h4"), depth in (DEEP ? (2, 4, 6) : (2,))]
mv_labels = String[]
for (_, arg) in mv_cases
    algebra, depth = split(arg, ':'); push!(mv_labels, "$(algebra == "h4" ? "non-chain H4" : "finite chain $algebra") value depth=$depth")
end
add_section_rows!("many-valued", mv_labels, mv_cases; note="finite designated check; H4 is the landed non-chain FLew algebra")

println("[learning from interpretations]")
ilp_cases = [("ilp_score", "$model_count:$hypothesis_count") for (model_count, hypothesis_count) in (DEEP ? ((8, 4), (32, 12), (64, 24)) : ((8, 4),))]
add_section_rows!("ILP interpretation scoring", ["ILP interpretation scoring models=$(split(arg, ':')[1]) hypotheses=$(split(arg, ':')[2])" for (_, arg) in ilp_cases], ilp_cases;
    note="seeded learning_from_interpretations examples; hypotheses × interpretations check/eval hot path")

println("[bisimulation contraction amortisation]")
println("incumbent: unsupported — SoleLogics v0.13.7 has no bisimulation contraction API")
println("n | quotient | ratio | C | P_orig | P_quot | K* | measured crossover (K: orig ms / quotient ms)")
contraction_cases = Tuple{String,String}[]; contraction_ranges = NamedTuple[]
contraction_models = DEEP ? (96, 192, 384) : (48,); contraction_counts = DEEP ? 5 : 2
contraction_curve = DEEP ? (1, 2, 4, 8, 16, 32, 64) : (1, 8, 32)
for n in contraction_models, q in (DEEP ? (1, 4, 16, n) : (1, n))
    q > n && continue
    cindex = length(contraction_cases) + 1; push!(contraction_cases, ("contraction_cost", "$n:$q"))
    orig_indices = Int[]; quot_indices = Int[]; curve_orig = Int[]; curve_quot = Int[]
    for i in 1:contraction_counts
        push!(contraction_cases, ("contraction_orig", "$n:$q:$i:8")); push!(orig_indices, length(contraction_cases))
    end
    for i in 1:contraction_counts
        push!(contraction_cases, ("contraction_quot", "$n:$q:$i:8")); push!(quot_indices, length(contraction_cases))
    end
    for k in contraction_curve
        push!(contraction_cases, ("contraction_batch_orig", "$n:$q:8:$k")); push!(curve_orig, length(contraction_cases))
        push!(contraction_cases, ("contraction_batch_quot", "$n:$q:8:$k")); push!(curve_quot, length(contraction_cases))
    end
    push!(contraction_ranges, (n=n, q=q, c=cindex, orig=orig_indices, quot=quot_indices, curve_orig=curve_orig, curve_quot=curve_quot))
end
contraction_measurements = section_measure("contraction", contraction_cases, "aletheia"; timeout=DEEP ? 180 : 120)
contraction_records = NamedTuple[]
for entry in contraction_ranges
    c = contraction_measurements[entry.c]; po = parse_ratio_measurements(contraction_measurements[entry.orig]); pq = parse_ratio_measurements(contraction_measurements[entry.quot])
    ratio = entry.q / entry.n; delta = po.time === missing || pq.time === missing ? missing : po.time - pq.time
    kstar = delta === missing || delta <= 0 ? Inf : c.time / delta
    kstar_text = isfinite(kstar) ? @sprintf("%.1f", kstar) : "∞"
    println("$(entry.n) | $(entry.q) | $(@sprintf("%.3f", ratio)) | $(fmt_measure(c)) | $(fmt_measure(po)) | $(fmt_measure(pq)) | $kstar_text | ")
    push!(contraction_records, (n=entry.n, q=entry.q, c=c, po=po, pq=pq, kstar=kstar))
    for (k, oi, qi) in zip(contraction_curve, entry.curve_orig, entry.curve_quot)
        bo, bq = contraction_measurements[oi], contraction_measurements[qi]
        println("  K=$k: $(bo.time === missing ? "timeout" : @sprintf("%.3f", bo.time / 1e6)) ms / $(bq.time === missing || c.time === missing ? "timeout" : @sprintf("%.3f", (c.time + bq.time) / 1e6)) ms (quotient includes C)")
    end
end

println("[cold package load]")
load_a = raw"""t0=time_ns(); using Aletheia; t1=time_ns(); s=Aletheia.Signature((Aletheia.NEGATION,Aletheia.CONJUNCTION,Aletheia.DISJUNCTION,Aletheia.IMPLICATION)); p=Aletheia.FormulaPool(s); Aletheia.syntaxstring(Aletheia.parse(p, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
load_s = raw"""t0=time_ns(); using SoleLogics; t1=time_ns(); SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, "p")); t2=time_ns(); println((t1-t0)/1e6, " ", (t2-t0)/1e6)"""
la = external_measure(load_a); ls = external_measure(load_s)
cold_measure(x, i) = x === nothing ? Measurement(missing, missing, missing, "unavailable") : Measurement(x[i] * 1e6, missing, missing)
addrow!("cold package load", cold_measure(ls, 1), cold_measure(la, 1); allocations=false)
addrow!("cold time-to-first-result", cold_measure(ls, 2), cold_measure(la, 2); allocations=false)

wall_clock = (time_ns() - RUN_START_NS) / 1e9
println(); print_report(); println("benchmark wall clock: ", @sprintf("%.1f s", wall_clock))

# Preserve the exact run provenance and values beside the published page.  The
# successful child measurements use a fixed count (not a time budget), while
# contraction checks deliberately use 2000 paired samples for a stable K*.
artifact = joinpath(normpath(joinpath(@__DIR__, "..")), "data", "benchmark-run", "run.txt")
mkpath(dirname(artifact))
load_average = try readchomp(`uptime`) catch; "unavailable" end
open(artifact, "w") do io
    println(io, "julia=$(VERSION)")
    println(io, "cpu=$(Sys.CPU_NAME)")
    println(io, "cpu_threads=$(Sys.CPU_THREADS)")
    println(io, "load_average=$(load_average)")
    println(io, "mode=$(DEEP ? "deep" : "quick")")
    println(io, "seed=$(SEED)")
    println(io, "default_samples=$(BENCH_SAMPLES)")
    println(io, "contraction_samples=2000")
    println(io, "cold_load_repetitions=$(DEEP ? 2 : 1)")
    println(io, "wall_clock_seconds=$(wall_clock)")
    println(io, "suite | SoleLogics | Aletheia | ratio | allocations | samples")
    for row in rows
        samples = occursin("cold", row.suite) ? (DEEP ? 2 : 1) : BENCH_SAMPLES
        println(io, row.suite, " | ", fmt_measure(row.incumbent), " | ",
            fmt_measure(row.aletheia), " | ",
            row.ratio === missing ? "—" : @sprintf("%.2fx", row.ratio), " | ",
            row.allocations ? fmt_alloc(row.incumbent) * " ; " * fmt_alloc(row.aletheia) : "—/—",
            " | ", samples)
    end
    for (entry, record) in zip(contraction_ranges, contraction_records)
        c, po, pq = record.c, record.po, record.pq
        println(io, "contraction n=$(record.n) q=$(record.q) | C=$(fmt_measure(c)) | P_orig=$(fmt_measure(po)) | P_quot=$(fmt_measure(pq)) | K*=$(isfinite(record.kstar) ? @sprintf("%.1f", record.kstar) : "∞") | samples=2000")
        for (k, oi, qi) in zip(contraction_curve, entry.curve_orig, entry.curve_quot)
            bo, bq = contraction_measurements[oi], contraction_measurements[qi]
            total = bq.time === missing || c.time === missing ? "timeout" : fmt_time(c.time + bq.time)
            println(io, "contraction_batch n=$(record.n) q=$(record.q) K=$k | original=$(fmt_measure(bo)) | quotient_total=$total | samples=2000")
        end
    end
end
println("raw provenance written to ", artifact)
