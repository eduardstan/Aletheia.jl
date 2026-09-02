struct EmptyFamily <: AbstractModelFamily end

@testset "instance families and vectorized valuation callbacks" begin
    sig = Signature((¬, ∧, Diamond(:R)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    modal = branch(pool, Diamond(:R), p)
    frame = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [2])); index=true)
    calls = Ref(0)
    batches = Ref(0)
    callback = Aletheia.ValuationCallback(
        (name, world) -> begin
            calls[] += 1
            name == "p" && world == 2
        end;
        vectorized=(name, worlds) -> begin
            batches[] += 1
            BitVector([name == "p" && world == 2 for world in worlds])
        end,
    )
    first_model = Model(frame, BOOLEAN, callback)
    second_frame = Frame((1, 2), Dict(:R => Dict(1 => [1], 2 => [1])); index=true)
    second_model = Model(second_frame, BOOLEAN, Dict("p" => Set([1])))
    family = ModelFamily([first_model, second_model])

    @test instance_count(family) == 2
    @test collect(eachinstance(family)) == [1, 2]
    @test instance_model(family, 1) === first_model
    @test instance_frame(family, 1) === frame
    @test !isuniform(family)
    @test uniform_frame(family) === nothing

    @test extension(modal, family, 1) == BitVector([true, true])
    @test batches[] == 1
    @test check(modal, family, 1, 1) === true
    @test interpret(p, first_model, 1) === false
    @test calls[] == 1
    @test extension(p, family) == [BitVector([false, true]), BitVector([true, false])]

    uniform = ModelFamily((first_model, Model(frame, BOOLEAN, Dict("p" => Set([2])))))
    @test isuniform(uniform)
    @test uniform_frame(uniform) == frame
    @test extension(p, uniform) == [BitVector([false, true]), BitVector([false, true])]

    gcallback = Aletheia.ValuationCallback((name, world) -> 0.5;
        vectorized=(name, worlds) -> [0.5, 1.0])
    gmodel = Model(frame, GodelAlgebra(3), gcallback)
    @test extension(p, gmodel) == [0.5, 1.0]

    @test uniform_frame(ModelFamily(Model[])) === nothing
    bad = Aletheia.ValuationCallback((name, world) -> true; vectorized=(name, worlds) -> Bool[])
    @test_throws ArgumentError extension(p, Model(frame, BOOLEAN, bad))

    @test_throws MethodError instance_count(EmptyFamily())
    @test_throws MethodError instance_model(EmptyFamily(), 1)
end


@testset "family apply allocation budget" begin
    sig = Signature((¬, Diamond(:R)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    modal = branch(pool, Diamond(:R), p)
    formulas = Formula[modal, p]
    frame = Frame(1:8, Dict(:R => Dict(world => (world == 8 ? (8,) : (world + 1,))
        for world in 1:8)); index=true)
    callback = Aletheia.ValuationCallback((name, world) -> name == "p" && iseven(world);
        vectorized=(name, worlds) -> BitVector(name == "p" && iseven(world) for world in worlds))
    family = ModelFamily([Model(frame, BOOLEAN, callback) for _ in 1:16])
    @test extension(formulas, family) ==
        [extension(formulas[1], family), extension(formulas[2], family)]
    # Recorded on Julia 1.10–1.12 for one fresh 16-instance, 8-world apply.
    # The ceiling leaves room for allocator and minor-version variation while
    # catching the former per-instance evaluator-plan growth.
    fresh_frame = Frame(1:8, Dict(:R => Dict(world => (world == 8 ? (8,) : (world + 1,))
        for world in 1:8)); index=true)
    fresh_family = ModelFamily([Model(fresh_frame, BOOLEAN, callback) for _ in 1:16])
    fresh_bytes = @allocated extension(formulas, fresh_family)
    @test fresh_bytes <= 1_500_000
end


@testset "dense scalar family apply allocation budget" begin
    sig = Signature((¬, Diamond(:R)))
    pool = FormulaPool(sig)
    condition = ThresholdCondition(:x, >, 0.5)
    atom_formula = atom(pool, condition)
    modal_formula = branch(pool, Diamond(:R), atom_formula)
    formulas = Formula[modal_formula, atom_formula]
    relation = Dict(:R => Dict(world => (world == 8 ? (8,) : (world + 1,))
        for world in 1:8))
    values = reshape(Float64.(iseven.(1:8 * 16)), 8, 16, 1)
    store = DenseFeatureStore(values, 1:8, [:x]; instances=1:16)
    frames = [Frame(1:8, relation; index=true) for _ in 1:16]
    prepared = prepare_scalar(store; features=[:x], frames=frames, relations=(:R,))
    family = scalar_family(prepared; vectorized=true)
    @test all(instance_frame(family, instance) === instance_frame(family, 1)
        for instance in 1:16)
    @test isuniform(family)
    @test uniform_frame(family) === instance_frame(family, 1)
    other_relation = Dict(:R => Dict(world => (world,) for world in 1:8))
    nonuniform = prepare_scalar(store; features=[:x],
        frames=[frames[1], Frame(1:8, other_relation; index=true)],
        relations=(:R,), instances=1:2)
    nonuniform_family = scalar_family(nonuniform; vectorized=true)
    @test instance_frame(nonuniform_family, 1) !==
        instance_frame(nonuniform_family, 2)
    @test !isuniform(nonuniform_family)
    # Warm compilation before measuring the fresh apply.
    extension(formulas, family)
    # Recorded on Julia 1.10–1.12 for one fresh 16-instance, 8-world apply.
    # This catches rebuilding the pooled evaluator plan for each equal frame.
    fresh_bytes = @allocated extension(formulas, family)
    @test fresh_bytes <= 1_500_000
end
