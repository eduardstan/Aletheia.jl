include(joinpath(@__DIR__, "common.jl"))
function run_case(mode, kind, side, argument)
    parts = split(argument, ':')

function execute(f)
    if mode == "benchmark"
        trial = run(@benchmarkable $f() seconds=BENCH_SECONDS samples=BENCH_SAMPLES evals=1)
        m = median(trial)
        println(m.time, " ", m.allocs, " ", m.memory)
    else
        start = time_ns(); f(); println((time_ns() - start) / 1_000_000)
    end
end

if kind == "construction"
    label, depth_text = parts; depth = parse(Int, depth_text); r = label == "shared" ? shared(depth) : unshared(depth)
    execute(side == "incumbent" ? (() -> build_s(r)) : (() -> build_a(r, pool_a())))
elseif kind in ("parsing", "printing", "roundtrip")
    depth = parse(Int, argument); r = unshared(depth); pa = build_a(r, pool_a()); ps = build_s(r); text = Aletheia.syntaxstring(pa)
    if kind == "parsing"
        execute(side == "incumbent" ? (() -> SoleLogics.parseformula(SoleLogics.SyntaxTree, text)) : (() -> Aletheia.parse(pool_a(), text)))
    elseif kind == "printing"
        execute(side == "incumbent" ? (() -> SoleLogics.syntaxstring(ps)) : (() -> Aletheia.syntaxstring(pa)))
    else
        execute(side == "incumbent" ? (() -> SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, text))) :
            (() -> Aletheia.syntaxstring(Aletheia.parse(pool_a(), text))))
    end
elseif kind == "equality"
    n = parse(Int, argument); r = chain(n)
    if side == "incumbent"
        s = build_s(r); t = build_s(r); execute(() -> isequal(s, t))
    else
        ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap); execute(() -> isequal(a, b))
    end
elseif kind == "prop_check"
    depth = parse(Int, argument); r = unshared(depth)
    if side == "incumbent"
        f = build_s(r); td = SoleLogics.TruthDict(Dict("p$(i)" => isodd(i) for i in 1:8))
        execute(() -> SoleLogics.check(f, td))
    else
        p = pool_a(); f = build_a(r, p); m = Aletheia.Model(Aletheia.Frame((1,); index=true), Aletheia.BOOLEAN,
            Dict("p$(i)" => (isodd(i) ? Set([1]) : Set{Int}()) for i in 1:8))
        execute(() -> Aletheia.check(f, m, 1))
    end
elseif kind == "prop_extension"
    n, depth = parse.(Int, parts); r = unshared(depth)
    if side == "incumbent"
        f = build_s(r); ws = SoleLogics.World.(1:n); td = Dict(w => SoleLogics.TruthDict(Dict("p$(i)" => ((i + w.name) % 2 == 0) for i in 1:8)) for w in ws)
        k = SoleLogics.KripkeStructure(SoleLogics.SimpleModalFrame(ws, SoleLogics.Graphs.SimpleDiGraph(n)), td)
        execute(() -> [SoleLogics.check(f, k, w) for w in ws])
    else
        p = pool_a(); f = build_a(r, p); m = Aletheia.Model(Aletheia.Frame(Tuple(1:n); index=true), Aletheia.BOOLEAN,
            Dict("p$(i)" => Set(w for w in 1:n if ((i + w) % 2 == 0)) for i in 1:8))
        execute(() -> Aletheia.extension(f, m))
    end
elseif kind == "modal_check"
    n, density, depth = parse(Int, parts[1]), parse(Float64, parts[2]), parse(Int, parts[3]); edges = edge_data(n, density, SEED + n + depth); r = modal_formula(depth)
    if side == "incumbent"
        f = build_s(r); m = s_boolean_model(n, edges); w = first(SoleLogics.allworlds(SoleLogics.frame(m)))
        execute(() -> SoleLogics.check(f, m, w; perform_normalization=false))
    else
        p = modal_pool_a(); f = build_a(r, p); m = a_boolean_model(n, edges)
        execute(() -> Aletheia.check(f, m, 1))
    end
elseif kind == "interval_adjacency"
    n = parse(Int, argument)
    if side == "incumbent"
        frame = SoleLogics.FullDimensionalFrame((n,), SoleLogics.Interval{Int}); ws = collect(SoleLogics.allworlds(frame)); execute(() -> interval_adjacency_s(frame, ws))
    else
        frame = Aletheia.interval_frame(n); ws = collect(Aletheia.worlds(frame)); execute(() -> interval_adjacency_a(frame, Aletheia.BEFORE, ws))
    end
elseif kind == "interval_subset"
    name, n_text = parts; n = parse(Int, n_text)
    if side == "incumbent"
        frame = SoleLogics.FullDimensionalFrame((n,), SoleLogics.Interval{Int}); ws = collect(SoleLogics.allworlds(frame))
        relation_set = name == "ia3" ? SoleLogics.IA3Relations : name == "ia7" ? SoleLogics.IA7Relations : SoleLogics.RCC5Relations
        execute(() -> interval_subset_s(frame, relation_set, ws))
    else
        frame = Aletheia.interval_frame(n); ws = collect(Aletheia.worlds(frame))
        relation_set = name == "ia3" ? Aletheia.IA3Relations : name == "ia7" ? Aletheia.IA7Relations : Aletheia.RCC5Relations
        execute(() -> interval_subset_a(frame, relation_set, ws))
    end
elseif kind == "interval_check"
    n = parse(Int, argument)
    if side == "incumbent"
        frame, ws, f, v = interval_check_s_setup(n); k = SoleLogics.KripkeStructure(frame, v); execute(() -> SoleLogics.check(f, k, first(ws); perform_normalization=false))
    else
        frame, ws, f, v = interval_check_a_setup(n); k = Aletheia.Model(frame, Aletheia.BOOLEAN, v); execute(() -> Aletheia.check(f, k, first(ws)))
    end
elseif kind == "many_check"
    algebra_name, depth_text = parts; depth = parse(Int, depth_text); f, data, alg = mv_setup(side, algebra_name, depth)
    if side == "incumbent"
        execute(() -> SoleLogics.check(f, data, alg))
    else
        execute(() -> Aletheia.check(f, data, 1) == Aletheia.top(alg))
    end
elseif kind == "ilp_score"
    model_count, hypothesis_count = parse.(Int, parts)
    if side == "incumbent"
        hs = [build_s(modal_formula(1 + mod(i, 4))) for i in 1:hypothesis_count]
        examples = Tuple[]
        for i in 1:model_count
            n = 4 + mod(i, 4); m = s_boolean_model(n, edge_data(n, 0.35, SEED + i)); push!(examples, (m, first(SoleLogics.allworlds(SoleLogics.frame(m))), isodd(i)))
        end
        execute(() -> score_s(hs, examples))
    else
        hs = Aletheia.Formula[]; p = modal_pool_a(); append!(hs, [build_a(modal_formula(1 + mod(i, 4)), p) for i in 1:hypothesis_count])
        examples = Aletheia.InterpretationExample[]
        for i in 1:model_count
            n = 4 + mod(i, 4); m = a_boolean_model(n, edge_data(n, 0.35, SEED + i));
            # This is the ILP learning-from-interpretations constructor; the
            # score loop below is the learner's eval/check hot path.
            push!(examples, Aletheia.learning_from_interpretations(m; positive=isodd(i)))
        end
        execute(() -> score_a(hs, examples))
    end
elseif kind in ("contraction_cost", "contraction_orig", "contraction_quot", "contraction_batch_orig", "contraction_batch_quot")
    n, q = parse.(Int, parts[1:2]); count = length(parts) >= 3 ? parse(Int, parts[3]) : 8; k = length(parts) >= 4 ? parse(Int, parts[4]) : count
    model, atoms = contraction_model(n, q); pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.Diamond(:R), Aletheia.Box(:R)))); fs = contraction_formulas(pool, atoms, max(count, k))
    if kind == "contraction_cost"
        execute(() -> Aletheia.bisimulation_contraction(model; atoms=atoms, relations=[:R]))
    elseif kind == "contraction_orig"
        i = min(count, length(fs)); execute(() -> Aletheia.check(fs[i], model, 1))
    elseif kind == "contraction_quot"
        qmodel = Aletheia.bisimulation_contraction(model; atoms=atoms, relations=[:R]); qw = Aletheia.contraction_world(qmodel, 1); i = min(count, length(fs)); execute(() -> Aletheia.check(fs[i], Aletheia.model(qmodel), qw))
    elseif kind == "contraction_batch_orig"
        execute(() -> begin for i in 1:k; Aletheia.check(fs[1 + mod(i - 1, length(fs))], model, 1); end; nothing end)
    else
        qmodel = Aletheia.bisimulation_contraction(model; atoms=atoms, relations=[:R]); qm = Aletheia.model(qmodel); qw = Aletheia.contraction_world(qmodel, 1)
        execute(() -> begin for i in 1:k; Aletheia.check(fs[1 + mod(i - 1, length(fs))], qm, qw); end; nothing end)
    end
else
    error("unknown warm-up case: $kind")
end

end

function main()
    if first(ARGS) == "section"
        side = ARGS[2]
        for item in split(ARGS[3], ';')
            kind, argument = split(item, '='; limit=2)
            run_case("benchmark", kind, side, argument)
        end
    else
        mode, kind, side, argument = ARGS
        run_case(mode, kind, side, argument)
    end
end
main()
