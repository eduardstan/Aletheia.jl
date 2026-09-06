@testset "evaluation performance budgets" begin
    # Budgets are recorded from the benchmark-sized steady-state calls on the
    # office host. They intentionally leave headroom for Julia minor releases.
    signature = Signature((¬, ∧, ∨, →))
    pool = FormulaPool(signature)
    atom_p = atom(pool, :p)
    propositional_formula = atom_p
    for _ in 1:6
        propositional_formula = branch(pool, ∧, propositional_formula, propositional_formula)
    end
    one_world = Model(
        Frame((1,); index=true), BOOLEAN, Dict(:p => Set([1]))
    )
    check(propositional_formula, one_world, 1)
    extension(propositional_formula, one_world)
    prop_check_allocations = @allocated check(propositional_formula, one_world, 1)
    prop_extension_allocations = @allocated extension(propositional_formula, one_world)
    @test prop_check_allocations ≤ 10_000
    @test prop_extension_allocations ≤ 10_000

    worlds_32 = Tuple(1:32)
    adjacency = Dict(world => (world < 32 ? (world + 1,) : ()) for world in worlds_32)
    frame_32 = Frame(worlds_32, Dict(:R => adjacency); index=true)
    modal_signature = Signature((¬, ∧, ∨, →, Box(:R), Diamond(:R)))
    modal_pool = FormulaPool(modal_signature)
    modal_formula = branch(modal_pool, Box(:R), atom(modal_pool, :p))
    modal_model = Model(
        frame_32, BOOLEAN, Dict(:p => Set(worlds_32[2:2:32]))
    )
    check(modal_formula, modal_model, 1)
    extension(modal_formula, modal_model)
    modal_check_allocations = @allocated check(modal_formula, modal_model, 1)
    modal_extension_allocations = @allocated extension(modal_formula, modal_model)
    frame_allocations = @allocated Frame(worlds_32, Dict(:R => adjacency); index=true)
    @test modal_check_allocations ≤ 1_500_000
    @test modal_extension_allocations ≤ 1_500_000
    @test frame_allocations ≤ 500_000

    @test (@elapsed for _ in 1:100
        check(propositional_formula, one_world, 1)
    end) < 5.0
    @test (@elapsed for _ in 1:100
        extension(propositional_formula, one_world)
    end) < 5.0
    @test (@elapsed for _ in 1:100
        check(modal_formula, modal_model, 1)
    end) < 5.0
    @test (@elapsed for _ in 1:100
        extension(modal_formula, modal_model)
    end) < 5.0
    @test (@elapsed for _ in 1:25
        Frame(worlds_32, Dict(:R => adjacency); index=true)
    end) < 5.0
end
