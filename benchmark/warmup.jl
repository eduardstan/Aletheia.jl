include(joinpath(@__DIR__, "common.jl"))
function run_case(mode, kind, side, argument)
    parts = split(argument, ':')

function execute(f; samples=BENCH_SAMPLES)
    if mode == "benchmark"
        m = measure_samples(f; samples=samples)
        load = try
            load_match = Base.match(r"load average: ([0-9.]+)", readchomp(`uptime`))
            load_match === nothing ? missing : parse(Float64, load_match.captures[1])
        catch
            missing
        end
        println(m.time, " ", m.allocs, " ", m.memory, " ", load === missing ? "missing" : load)
    else
        start = time_ns(); f(); println((time_ns() - start) / 1_000_000)
    end
end

if kind == "construction"
    label, depth_text = parts; depth = parse(Int, depth_text); r = label == "shared" ? seeded_shared(depth) : seeded_unshared(depth)
    execute(side == "incumbent" ? (() -> build_s(r)) : (() -> build_a(r, pool_a())))
elseif kind in ("parsing", "printing", "roundtrip")
    depth = parse(Int, argument); r = seeded_unshared(depth); pa = build_a(r, pool_a()); ps = build_s(r); text = Aletheia.syntaxstring(pa)
    if kind == "parsing"
        execute(side == "incumbent" ? (() -> SoleLogics.parseformula(SoleLogics.SyntaxTree, text)) : (() -> Aletheia.parse(pool_a(), text)))
    elseif kind == "printing"
        execute(side == "incumbent" ? (() -> SoleLogics.syntaxstring(ps)) : (() -> Aletheia.syntaxstring(pa)))
    else
        execute(side == "incumbent" ? (() -> SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, text))) :
            (() -> Aletheia.syntaxstring(Aletheia.parse(pool_a(), text))))
    end
elseif kind == "equality"
    n = parse(Int, argument); r = chain(n; seed=SEED)
    if side == "incumbent"
        s = build_s(r); t = build_s(r); execute(() -> isequal(s, t))
    else
        ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap); execute(() -> isequal(a, b))
    end
elseif kind == "prop_check"
    depth = parse(Int, argument); r = seeded_unshared(depth)
    if side == "incumbent"
        f = build_s(r); td = SoleLogics.TruthDict(Dict(name => isodd(i) for (i, name) in enumerate(recipe_atoms(r))))
        execute(() -> SoleLogics.check(f, td))
    else
        p = pool_a(); f = build_a(r, p); m = Aletheia.Model(Aletheia.Frame((1,); index=true), Aletheia.BOOLEAN,
            Dict(name => (isodd(i) ? Set([1]) : Set{Int}()) for (i, name) in enumerate(recipe_atoms(r))))
        execute(() -> Aletheia.check(f, m, 1))
    end
elseif kind == "prop_extension"
    n, depth = parse.(Int, parts); r = seeded_unshared(depth)
    if side == "incumbent"
        f = build_s(r); ws = SoleLogics.World.(1:n); names = recipe_atoms(r); td = Dict(w => SoleLogics.TruthDict(Dict(name => ((i + w.name) % 2 == 0) for (i, name) in enumerate(names))) for w in ws)
        k = SoleLogics.KripkeStructure(SoleLogics.SimpleModalFrame(ws, SoleLogics.Graphs.SimpleDiGraph(n)), td)
        # SoleLogics computes an extension internally; retain that memo across
        # the all-world loop so it is not rebuilt once per world.
        execute(() -> begin
            memo = Dict{SoleLogics.SyntaxTree,Vector{SoleLogics.World{Int}}}()
            [SoleLogics.check(f, k, w; use_memo=memo, perform_normalization=false) for w in ws]
        end)
    else
        p = pool_a(); f = build_a(r, p); m = Aletheia.Model(Aletheia.Frame(Tuple(1:n); index=true), Aletheia.BOOLEAN,
            Dict(name => Set(w for w in 1:n if ((i + w) % 2 == 0)) for (i, name) in enumerate(recipe_atoms(r))))
        execute(() -> Aletheia.extension(f, m))
    end
elseif kind == "modal_check"
    n, density, depth = parse(Int, parts[1]), parse(Float64, parts[2]), parse(Int, parts[3]); case_seed = SEED + n + depth; edges = edge_data(n, density, case_seed); r = random_recipe(MersenneTwister(case_seed), depth; modal=true); sets = seeded_sets(recipe_atoms(r), n, case_seed)
    if side == "incumbent"
        f = build_s(r); m = s_boolean_model(n, edges; sets=sets); w = first(SoleLogics.allworlds(SoleLogics.frame(m)))
        execute(() -> SoleLogics.check(f, m, w; perform_normalization=false))
    else
        p = modal_pool_a(); f = build_a(r, p); m = a_boolean_model(n, edges; sets=sets)
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
        hs = [build_s(random_recipe(MersenneTwister(SEED + i), 1 + mod(i, 4); modal=true)) for i in 1:hypothesis_count]
        examples = Tuple[]
        names = unique(vcat((recipe_atoms(random_recipe(MersenneTwister(SEED + i), 1 + mod(i, 4); modal=true)) for i in 1:hypothesis_count)...))
        for i in 1:model_count
            n = 4 + mod(i, 4); case_seed = SEED + i * UInt64(7919); m = s_boolean_model(n, edge_data(n, 0.35, case_seed); sets=seeded_sets(names, n, case_seed)); push!(examples, (m, first(SoleLogics.allworlds(SoleLogics.frame(m))), isodd(i)))
        end
        execute(() -> score_s(hs, examples))
    else
        hs = Aletheia.Formula[]; p = modal_pool_a(); append!(hs, [build_a(random_recipe(MersenneTwister(SEED + i), 1 + mod(i, 4); modal=true), p) for i in 1:hypothesis_count])
        examples = Aletheia.InterpretationExample[]
        names = unique(vcat((recipe_atoms(random_recipe(MersenneTwister(SEED + i), 1 + mod(i, 4); modal=true)) for i in 1:hypothesis_count)...))
        for i in 1:model_count
            n = 4 + mod(i, 4); case_seed = SEED + i * UInt64(7919); m = a_boolean_model(n, edge_data(n, 0.35, case_seed); sets=seeded_sets(names, n, case_seed));
            # This is the ILP learning-from-interpretations constructor; the
            # score loop below is the learner's eval/check hot path.
            push!(examples, Aletheia.learning_from_interpretations(m; positive=isodd(i)))
        end
        execute(() -> score_a(hs, examples))
    end
elseif kind in ("contraction_cost", "contraction_orig", "contraction_quot", "contraction_batch_orig", "contraction_batch_quot")
    n, q = parse.(Int, parts[1:2]); count = length(parts) >= 3 ? parse(Int, parts[3]) : 8; k = length(parts) >= 4 ? parse(Int, parts[4]) : count
    model, atoms = contraction_model(n, q, SEED); pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.Diamond(:R), Aletheia.Box(:R)))); fs = contraction_formulas(pool, atoms, max(count, k))
    if kind == "contraction_cost"
        execute(() -> Aletheia.bisimulation_contraction(model; atoms=atoms, relations=[:R]); samples=2000)
    elseif kind == "contraction_orig"
        i = min(count, length(fs)); execute(() -> Aletheia.check(fs[i], model, 1); samples=2000)
    elseif kind == "contraction_quot"
        qmodel = Aletheia.bisimulation_contraction(model; atoms=atoms, relations=[:R]); qw = Aletheia.contraction_world(qmodel, 1); i = min(count, length(fs)); execute(() -> Aletheia.check(fs[i], Aletheia.model(qmodel), qw); samples=2000)
    elseif kind == "contraction_batch_orig"
        execute(() -> begin for i in 1:k; Aletheia.check(fs[1 + mod(i - 1, length(fs))], model, 1); end; nothing end; samples=2000)
    else
        qmodel = Aletheia.bisimulation_contraction(model; atoms=atoms, relations=[:R]); qm = Aletheia.model(qmodel); qw = Aletheia.contraction_world(qmodel, 1)
        execute(() -> begin for i in 1:k; Aletheia.check(fs[1 + mod(i - 1, length(fs))], qm, qw); end; nothing end; samples=2000)
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
            if occursin("@", argument)
                argument, seed_text = rsplit(argument, "@"; limit=2)
                global SEED = parse_seed(seed_text)
            end
            run_case("benchmark", kind, side, argument)
        end
    else
        mode, kind, side, argument = ARGS[1:4]
        run_case(mode, kind, side, argument)
    end
end
main()
