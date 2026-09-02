struct SymbolAlgebra <: TruthAlgebra{Symbol} end
Aletheia.top(::SymbolAlgebra) = :top
Aletheia.bottom(::SymbolAlgebra) = :bottom
Aletheia.meet(::SymbolAlgebra, ::Symbol, ::Symbol) = :meet
Aletheia.fusion(::SymbolAlgebra, ::Symbol, ::Symbol) = :fusion
Aletheia.join(::SymbolAlgebra, ::Symbol, ::Symbol) = :join
Aletheia.implication(::SymbolAlgebra, ::Symbol, ::Symbol) = :implication
Aletheia.negation(::SymbolAlgebra, ::Symbol) = :negation

struct VectorAlgebra <: TruthAlgebra{BitVector} end
Aletheia.top(::VectorAlgebra) = trues(2)
Aletheia.bottom(::VectorAlgebra) = falses(2)
Aletheia.meet(::VectorAlgebra, left::BitVector, right::BitVector) = left .& right
Aletheia.fusion(::VectorAlgebra, left::BitVector, right::BitVector) = left .& right
Aletheia.join(::VectorAlgebra, left::BitVector, right::BitVector) = left .| right
Aletheia.implication(::VectorAlgebra, left::BitVector, right::BitVector) = (.!left) .| right
Aletheia.negation(::VectorAlgebra, value::BitVector) = .!value

@testset "evaluation" begin
    sig = Signature((¬, ∧, ⊗, ∨, →, Diamond(:G), Box(:G), Diamond(:missing), Box(:missing)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    q = atom(pool, "q")
    notp = branch(pool, ¬, p)
    conjunction = branch(pool, ∧, p, q)
    fusion_formula = branch(pool, ⊗, p, q)
    disjunction = branch(pool, ∨, p, q)
    implication_formula = branch(pool, →, p, q)

    one = Frame((:only,); index=true)
    propositional = Model(one, BOOLEAN, Dict("p" => Set([:only]), "q" => Set{Symbol}()))
    @test @inferred(check(p, propositional, :only)) === true
    @test @inferred(check(conjunction, propositional, :only)) === false
    @test @inferred(check(fusion_formula, propositional, :only)) === false
    @test @inferred(extension(p, propositional)) == BitVector([true])
    @test extension(p, propositional) isa BitVector
    @test extension(notp, propositional) == BitVector([false])
    @test extension(disjunction, propositional) == BitVector([true])
    @test extension(implication_formula, propositional) == BitVector([false])
    @test_throws KeyError check(p, propositional, :missing)

    sparse_pool = FormulaPool(sig)
    atom(sparse_pool, "unused")
    sparse_p = atom(sparse_pool, "p")
    sparse_formula = branch(sparse_pool, ¬, sparse_p)
    @test extension(sparse_formula, propositional) == BitVector([false])

    frame = Frame(
        (:w1, :w2, :w3),
        Dict(:G => Dict(:w1 => [:w2, :w3], :w2 => [:w2], :w3 => []));
        index=true,
    )
    valuation = Dict("p" => Set([:w2]), "q" => Set([:w1, :w3]))
    boolean = Model(frame, BOOLEAN, valuation)
    diamond = branch(pool, Diamond(:G), p)
    box = branch(pool, Box(:G), p)
    @test extension(diamond, boolean) == BitVector([true, true, false])
    @test extension(box, boolean) == BitVector([false, true, true])
    @test check(diamond, boolean, :w1) === true
    @test check(box, boolean, :w3) === true
    missing_diamond = branch(pool, Diamond(:missing), p)
    missing_box = branch(pool, Box(:missing), p)
    @test check(missing_diamond, boolean, :w1) === false
    @test check(missing_box, boolean, :w3) === true
    dual = branch(pool, ¬, branch(pool, Diamond(:G), branch(pool, ¬, p)))
    @test extension(box, boolean) == extension(dual, boolean)
    nested = branch(pool, Box(:G), diamond)
    @test extension(nested, boolean) == BitVector([false, true, true])

    godel = Model(
        frame,
        GodelAlgebra(),
        Dict(
            "p" => Dict(:w1 => 0.9, :w2 => 0.2, :w3 => 0.7),
            "q" => Dict(:w1 => 0.4, :w2 => 0.8, :w3 => 0.1),
        ),
    )
    gdiamond = extension(diamond, godel)
    gbox = extension(box, godel)
    @test gdiamond isa Vector{Float64} && gdiamond == [0.7, 0.2, 0.0]
    @test gbox == [0.2, 0.2, 1.0]
    @test check(branch(pool, ∧, p, q), godel, :w1) === 0.4
    @test check(fusion_formula, godel, :w1) === 0.4
    @test check(branch(pool, ∨, p, q), godel, :w1) === 0.9
    @test check(branch(pool, →, p, q), godel, :w1) === 0.4
    @test check(notp, godel, :w1) === 0.0
    @test extension(dual, godel) != gbox
    @test extension(missing_diamond, godel) == [0.0, 0.0, 0.0]
    @test extension(missing_box, godel) == [1.0, 1.0, 1.0]

    lukasiewicz = Model(
        frame, LukasiewiczAlgebra(), Dict("p" => Dict(:w1 => 0.9, :w2 => 0.2, :w3 => 0.7))
    )
    @test extension(diamond, lukasiewicz) == [0.7, 0.2, 0.0]
    @test extension(box, lukasiewicz) ≈ [0.2, 0.2, 1.0]
    @test check(branch(pool, ∧, p, p), lukasiewicz, :w1) === 0.9
    @test check(branch(pool, ⊗, p, p), lukasiewicz, :w1) === 0.8
    @test check(
        branch(pool, →, p, q),
        Model(
            frame,
            LukasiewiczAlgebra(),
            Dict(
                "p" => Dict(:w1 => 0.9, :w2 => 0.2, :w3 => 0.7),
                "q" => Dict(:w1 => 0.4, :w2 => 0.8, :w3 => 0.1),
            ),
        ),
        :w1,
    ) === 0.5

    shared = branch(pool, ∨, conjunction, conjunction)
    calls = Ref(0)
    counted = Model(
        frame,
        (value, world) -> (calls[] += 1; value == "p" ? world != :w3 : world != :w1),
        BOOLEAN,
    )
    @test extension(shared, counted) == BitVector([false, true, false])
    @test calls[] == 2 * length(worlds(frame))

    # A fixed seed keeps the batch exactness corpus reproducible.
    Random.seed!(0xA1E7)
    function batch_random_formula(rng, pool, p, q, depth)
        depth == 0 && return rand(rng, (p, q))
        connective = rand(rng, (¬, ∧, ∨, →, Diamond(:G), Box(:G)))
        return if arity(connective) == 1
            branch(pool, connective, batch_random_formula(rng, pool, p, q, depth - 1))
        else
            branch(
                pool,
                connective,
                batch_random_formula(rng, pool, p, q, depth - 1),
                batch_random_formula(rng, pool, p, q, depth - 1),
            )
        end
    end
    batch_rng = Random.default_rng()
    batch_forms = [
        batch_random_formula(batch_rng, pool, p, q, rand(batch_rng, 0:3)) for _ in 1:12
    ]
    batch_boolean = Model(
        frame,
        BOOLEAN,
        Dict(
            "p" => Set(world for world in worlds(frame) if rand(batch_rng, Bool)),
            "q" => Set(world for world in worlds(frame) if rand(batch_rng, Bool)),
        ),
    )
    batch_godel = Model(
        frame,
        GodelAlgebra(3),
        Dict(
            name =>
                Dict(world => rand(batch_rng, (0.0, 0.5, 1.0)) for world in worlds(frame))
            for name in ("p", "q")
        ),
    )
    @test extension(batch_forms, batch_boolean) ==
          [extension(formula, batch_boolean) for formula in batch_forms]
    @test extension(batch_forms, batch_godel) ==
          [extension(formula, batch_godel) for formula in batch_forms]
    batch_calls = Ref(0)
    counted_batch = Model(
        frame,
        BOOLEAN,
        Aletheia.ValuationCallback(
            (value, world) ->
                (batch_calls[] += 1; value == "p" ? world != :w3 : world != :w1),
        ),
    )
    batch_shared = [conjunction, disjunction, branch(pool, →, p, q)]
    batch_shared_result = extension(batch_shared, counted_batch)
    plain_counted = Model(
        frame, BOOLEAN, Dict("p" => Set([:w1, :w2]), "q" => Set([:w2, :w3]))
    )
    @test batch_shared_result ==
          [extension(formula, plain_counted) for formula in batch_shared]
    @test batch_calls[] == 2 * length(worlds(frame))

    batch_boolean_other = Model(
        frame,
        BOOLEAN,
        Dict(
            "p" => Set(world for world in worlds(frame) if rand(batch_rng, Bool)),
            "q" => Set(world for world in worlds(frame) if rand(batch_rng, Bool)),
        ),
    )
    @test_throws ArgumentError extension([p, atom(FormulaPool(sig), "p")], batch_boolean)
    @test_throws ArgumentError extension([p, :not_a_formula], batch_boolean)

    batch_cache = EvaluationCache(batch_boolean)
    batch_boolean_result = extension(batch_shared, batch_boolean)
    @test extension(batch_shared, batch_boolean; cache=batch_cache) == batch_boolean_result
    @test extension(batch_shared, batch_boolean; cache=batch_cache) == batch_boolean_result
    batch_new = branch(pool, ∧, p, branch(pool, ∨, q, p))
    @test extension([batch_shared[1], batch_new], batch_boolean; cache=batch_cache) ==
          [extension(formula, batch_boolean) for formula in [batch_shared[1], batch_new]]
    @test_throws ArgumentError extension(
        batch_shared, batch_boolean_other; cache=batch_cache
    )
    other_batch_pool = FormulaPool(sig)
    other_batch_p = atom(other_batch_pool, "p")
    @test_throws ArgumentError extension([other_batch_p], batch_boolean; cache=batch_cache)
    batch_cache.values[id(batch_shared[1])] = [0.5, 0.5, 0.5]
    @test_throws ArgumentError extension(
        [batch_shared[1]], batch_boolean; cache=batch_cache
    )
    @test clear!(batch_cache) === batch_cache
    @test_throws ArgumentError extension(p, batch_boolean; cache=:invalid)
    @test_throws ArgumentError extension([p], batch_boolean; cache=:invalid)

    symbolic = Model(one, SymbolAlgebra(), Dict("p" => :atom, "q" => :atom))
    @test check(p, symbolic, :only) === :atom
    @test check(notp, symbolic, :only) === :negation
    @test check(conjunction, symbolic, :only) === :meet
    @test check(fusion_formula, symbolic, :only) === :fusion
    @test check(disjunction, symbolic, :only) === :join
    @test check(implication_formula, symbolic, :only) === :implication
    @test check(branch(pool, Diamond(:G), p), symbolic, :only) === :bottom
    @test check(branch(pool, Box(:G), p), symbolic, :only) === :top
    @test extension(p, symbolic) isa Vector{Symbol}

    vector_model = Model(
        one,
        VectorAlgebra(),
        (value, world) ->
            value == "p" ? BitVector([true, false]) : BitVector([false, true]),
    )
    @test @inferred(check(conjunction, vector_model, :only)) == BitVector([false, false])
    @test @inferred(extension(conjunction, vector_model)) isa Vector{BitVector}
    @test extension(conjunction, vector_model) == [BitVector([false, false])]
    @test extension(conjunction, vector_model) == [BitVector([false, false])]
    @test extension(branch(pool, Box(:G), p), vector_model) == [trues(2)]

    # Box uses the lattice infimum, even when the monoid fusion is non-idempotent.
    lukasiewicz3_frame = Frame(
        (:source, :left, :right),
        Dict(:G => Dict(:source => [:left, :right], :left => [], :right => []));
        index=true,
    )
    lukasiewicz3 = Model(
        lukasiewicz3_frame,
        Ł3,
        Dict("p" => Dict(:source => UInt8(1), :left => UInt8(3), :right => UInt8(3))),
    )
    box3 = branch(pool, Box(:G), p)
    @test meet(Ł3, UInt8(3), UInt8(3)) == UInt8(3)
    @test fusion(Ł3, UInt8(3), UInt8(3)) == UInt8(2)
    @test check(box3, lukasiewicz3, :source) == UInt8(3)

    duplicate_frame = Frame((:a, :b), Dict(:G => [(:a, :b), (:a, :b)]); index=true)
    duplicate_model = Model(
        duplicate_frame, LukasiewiczAlgebra(), Dict("p" => Dict(:a => 0.0, :b => 0.6))
    )
    @test extension(box, duplicate_model)[1] ≈ 0.6

    relation_state = Ref(true)
    relation_frame = Frame(
        (:a, :b),
        (world, relation) -> relation_state[] && world == :a ? (:b,) : ();
        index=true,
    )
    relation_model = Model(relation_frame, BOOLEAN, Dict("p" => Set([:b])))
    @test extension(diamond, relation_model) == BitVector([true, false])
    relation_state[] = false
    @test extension(diamond, relation_model) == BitVector([false, false])

    custom_pool = FormulaPool(Signature((¬, ∧, ∨, →, Diamond(:G), Box(:G), TestXor())))
    cp = atom(custom_pool, "p")
    cq = atom(custom_pool, "q")
    @test_throws ArgumentError check(branch(custom_pool, TestXor(), cp, cq), boolean, :w1)

    # EvaluationCache is explicit, model-bound, and works for propositional
    # and modal formulas across the built-in algebra families.
    h4_model = Model(
        frame, H4, Dict("p" => Dict(:w1 => UInt8(3), :w2 => UInt8(4), :w3 => UInt8(2)))
    )
    for cached_model in (boolean, godel, lukasiewicz, h4_model)
        cache = EvaluationCache(cached_model)
        @test extension(nested, cached_model; cache=cache) ==
              extension(nested, cached_model)
        @test check(nested, cached_model, :w1; cache=cache) ==
              check(nested, cached_model, :w1)
        retained = extension(nested, cached_model; cache=cache)
        retained_value = retained[1]
        retained[1] = top(algebra(cached_model))
        @test extension(nested, cached_model; cache=cache)[1] == retained_value
        @test check(nested, cached_model, :w1; cache=cache) ==
              check(nested, cached_model, :w1)
        clear!(cache)
        @test extension(nested, cached_model; cache=cache) ==
              extension(nested, cached_model)
    end
    callback_calls = Ref(0)
    cached_callback_model = Model(
        frame, (value, world) -> (callback_calls[] += 1; world == :w2), BOOLEAN
    )
    callback_cache = EvaluationCache(cached_callback_model)
    @test check(nested, cached_callback_model, :w1; cache=callback_cache) === false
    cold_calls = callback_calls[]
    @test check(nested, cached_callback_model, :w1; cache=callback_cache) === false
    @test callback_calls[] == cold_calls
    @test_throws ArgumentError extension(nested, boolean; cache=EvaluationCache(godel))
    other_pool = FormulaPool(sig)
    other_p = atom(other_pool, "p")
    pool_cache = EvaluationCache(boolean)
    extension(p, boolean; cache=pool_cache)
    @test_throws ArgumentError extension(other_p, boolean; cache=pool_cache)
end
