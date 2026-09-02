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
