struct TestSymbolAlgebra <: TruthAlgebra{Symbol} end
Aletheia.top(::TestSymbolAlgebra) = :top
Aletheia.bottom(::TestSymbolAlgebra) = :bottom
Aletheia.meet(::TestSymbolAlgebra, ::Symbol, ::Symbol) = :meet
Aletheia.join(::TestSymbolAlgebra, ::Symbol, ::Symbol) = :join
Aletheia.implication(::TestSymbolAlgebra, ::Symbol, ::Symbol) = :implication
Aletheia.negation(::TestSymbolAlgebra, ::Symbol) = :negation

@testset "truth algebras" begin
    b = BooleanAlgebra()
    @test b isa TruthAlgebra{Bool}
    @test truth_type(b) === Bool && truthtype(b) === Bool && carrier(b) === Bool
    @test top(b) && !bottom(b) && bot(b) == false
    @test meet(b, true, false) == false
    @test join(b, true, false) == true
    @test implication(b, true, false) == false
    @test implies(b, false, false) == true
    @test negation(b, true) == false && negate(b, false)
    @test domain(b) == (false, true)

    g = GodelAlgebra()
    @test g isa TruthAlgebra{Float64}
    @test top(g) == 1.0 && bottom(g) == 0.0
    @test Base.invokelatest(top, g) == 1.0 && Base.invokelatest(bottom, g) == 0.0
    @test meet(g, 0.2, 0.7) == 0.2 && join(g, 0.2, 0.7) == 0.7
    @test implication(g, 0.2, 0.7) == 1.0 && implication(g, 0.7, 0.2) == 0.2
    @test negation(g, 0.0) == 1.0 && negation(g, 0.2) == 0.0
    @test !isfinitechain(g) && domain(g) == (0.0, 1.0)
    @test_throws ArgumentError levels(g)
    @test GodelChain(3) isa GodelAlgebra{3}
    @test collect(levels(GodelAlgebra(3))) == [0.0, 0.5, 1.0]
    @test domain(GodelAlgebra(3)) == (0.0, 0.5, 1.0)
    @test isfinitechain(GodelAlgebra(3))

    l = LukasiewiczAlgebra()
    @test domain(l) == (0.0, 1.0)
    @test top(l) == 1.0 && bottom(l) == 0.0
    @test Base.invokelatest(top, l) == 1.0 && Base.invokelatest(bottom, l) == 0.0
    @test meet(l, 0.6, 0.6) ≈ 0.2 && join(l, 0.2, 0.6) ≈ 0.6
    @test implication(l, 0.7, 0.4) ≈ 0.7
    @test implication(l, 0.4, 0.7) == 1.0 && negation(l, 0.2) ≈ 0.8
    @test LukasiewiczChain(4) isa LukasiewiczAlgebra{4}
    @test collect(levels(LukasiewiczAlgebra(4))) == [0.0, 1 / 3, 2 / 3, 1.0]
    @test domain(LukasiewiczAlgebra(4)) == Tuple(collect(levels(LukasiewiczAlgebra(4))))

    @test GödelAlgebra === GodelAlgebra && ŁukasiewiczAlgebra === LukasiewiczAlgebra
    @test_throws ArgumentError GodelAlgebra(0)
    @test_throws ArgumentError GodelAlgebra(1)
    @test_throws ArgumentError LukasiewiczAlgebra(1)
    @test_throws ArgumentError meet(g, -0.1, 0.2)
    @test_throws ArgumentError meet(g, 0.2, 1.1)
    @test_throws ArgumentError meet(GodelAlgebra(3), 0.25, 0.5)
    @test meet(GodelAlgebra(3), 0.5, 1.0) == 0.5
    @test meet(LukasiewiczAlgebra(4), 1 / 3, 2 / 3) == 0.0
    @test_throws ArgumentError implication(LukasiewiczAlgebra(3), 0.25, 0.5)
    @test truth_type(TestSymbolAlgebra()) === Symbol
    @test top(TestSymbolAlgebra()) == :top
    @test bottom(TestSymbolAlgebra()) == :bottom
    @test meet(TestSymbolAlgebra(), :a, :b) == :meet
    @test join(TestSymbolAlgebra(), :a, :b) == :join
    @test implication(TestSymbolAlgebra(), :a, :b) == :implication
    @test negation(TestSymbolAlgebra(), :a) == :negation
    @test_throws MethodError top(TruthAlgebra{Int}())
end

struct BadIndexData end
Base.getindex(::BadIndexData, ::Any) = error("bad index")

@testset "frames and lazy accessibility" begin
    f = Frame((:w1, :w2), Dict(:G => Dict(:w1 => [:w2], :w2 => [:w2]),
                               :H => [(:w1, :w1)]); index=true)
    @test worlds(f) == (:w1, :w2) && length(f) == 2 && collect(f) == [:w1, :w2]
    @test relations(f) isa Dict && hasworldindex(f)
    @test world_index(f)[:w2] == 2 && world_position(f, :w1) == 1 && world_position(f, :w2) == 2
    successors = accessible(f, :w1, :G)
    @test successors isa Base.Generator && collect(successors) == [:w2]
    @test collect(accessible(f, :w2, :G)) == [:w2]
    @test collect(accessible(f, :w1, :missing)) == []
    @test collect(accessible(f, :w1, :H)) == [:w1]
    @test_throws KeyError accessible(f, :missing, :G)

    plain = Frame([1, 2], Dict(:R => Dict(1 => [2])); index=false)
    @test !hasworldindex(plain) && world_position(plain, 2) == 2
    @test world_index(plain) === nothing
    @test collect(accessible(plain, 2, :R)) == []
    indexed = Frame([1, 2], Dict(); world_index=Dict(1 => 1, 2 => 2))
    @test hasworldindex(indexed)
    @test Frame((:only,)).worlds == (:only,)
    @test Frame((:only,), Dict(); index=true).index[:only] == 1
    @test_throws KeyError world_position(indexed, 3)
    @test_throws KeyError world_position(plain, 3)
    @test_throws ArgumentError Frame(())
    @test_throws ArgumentError Frame((1, 1), Dict())
    @test_throws ArgumentError Frame((1,), Dict(:R => Dict(2 => [1])))
    @test_throws ArgumentError Frame((1,), Dict(:R => Dict(1 => [2])))
    @test_throws ArgumentError Frame((1,), Dict(:R => 1))
    @test_throws ArgumentError Frame((1,), Dict(:R => Dict(1 => [1])); index=:bad)
    @test_throws ArgumentError Frame((1,), Dict(:R => Dict(1 => [1])); index=Dict())

    function relation_function(world, rel)
        rel == :R ? (world == 1 ? (2,) : ()) : ()
    end
    function adjacency_function(world)
        world == 1 ? [2] : Int[]
    end
    ff = Frame((1, 2), relation_function)
    fg = Frame((1, 2), Dict(:R => adjacency_function))
    @test collect(accessible(ff, 1, :R)) == [2]
    @test collect(accessible(fg, 1, :R)) == [2]
    @test Frame((1,), (x -> x)).worlds == (1,)
    @test collect(accessible(Frame((1,), (x,y)->()), 1, :R)) == []
    reverse_relation(rel::Symbol, world::Int) = world == 1 ? (1,) : ()
    @test collect(accessible(Frame((1,), reverse_relation), 1, :R)) == [1]
    @test_throws ArgumentError accessible(Frame((1,), x -> x), 1, :R)
    @test Aletheia._targets((:w,), :other) == (:other,)
    @test Aletheia._targets((:w,), BadIndexData()) == (BadIndexData(),)
    @test_throws ArgumentError Aletheia._nested_value(BadIndexData(), :w)
    @test !(accessible(Frame((1,), Dict(:R=>Dict(1=>[1]))), 1, :R) isa Vector)
end

@testset "models and atom interpretation" begin
    sig = Signature((¬, ∧, Diamond(:G)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    f = Frame((:w1, :w2), Dict(:G => Dict(:w1 => [:w2], :w2 => [:w2])))
    boolmodel = Model(f, BooleanAlgebra(), Dict("p" => Set([:w1])))
    @test frame(boolmodel) === f && algebra(boolmodel) isa BooleanAlgebra
    @test valuation(boolmodel)["p"] == Set([:w1])
    @test interpret(p, boolmodel, :w1) === true
    @test interpret(p, boolmodel, :w2) === false
    @test collect(accessible(boolmodel, :w1, :G)) == [:w2]
    oneworld = Frame((:only,); index=true)
    propositional = Model(oneworld, BooleanAlgebra(), Dict("p" => Set([:only])))
    @test interpret(p, propositional, :only) === true

    gmodel = Model(f, Dict("p" => Dict(:w1 => 0.5, :w2 => 1.0)); algebra=GodelAlgebra())
    @test interpret(p, gmodel, :w1) === 0.5
    @test interpret(p, Model(f, Dict(("p", :w1) => 0.75), GodelAlgebra()), :w1) === 0.75
    @test interpret(p, Model(f, Dict((:w1, "p") => 0.25), GodelAlgebra()), :w1) === 0.25
    @test interpret(p, Model(f, Dict(:w1 => Dict("p" => 0.4)), GodelAlgebra()), :w1) === 0.4
    @test interpret(p, Model(f, Dict("p" => world -> 0.5), GodelAlgebra()), :w1) === 0.5
    @test interpret(p, Model(f, Dict("p" => 0.4), GodelAlgebra()), :w2) === 0.4
    wrapped = Valuation(Dict("p" => Dict(:w1 => 0.6)))
    @test wrapped("p", :w1) === 0.6
    @test interpret(p, Model(f, wrapped, GodelAlgebra()), :w1) === 0.6
    @test interpret(p, Model(f, (value, world) -> 0.3, GodelAlgebra()), :w1) === 0.3
    @test interpret(p, Model(f, Dict("p" => :yes), TestSymbolAlgebra()), :w1) === :yes
    @test_throws KeyError interpret(p, boolmodel, :missing)
    @test_throws KeyError interpret(p, Model(f, Dict("q"=>Set([:w1]))), :w1)
    @test_throws ArgumentError interpret(p, Model(f, Dict("p"=>Set([:w1])), GodelAlgebra()), :w1)
    @test interpret(p, Model(f, Dict("p"=>Set([:w1]))), :w1) === true
    @test interpret(p, Model(f, Dict(p => Set([:w1]))), :w1) === true
    @test interpret(p, Model(f, Dict((p, :w1) => true)), :w1) === true
    @test interpret(p, Model(f, Valuation(Dict(p => Dict(:w1 => true)))), :w1) === true
    @test_throws ArgumentError interpret(p, Model(f, 1), :w1)
    @test_throws ArgumentError interpret(p, Model(f, Dict("p"=>Dict(:w1=>true)), GodelAlgebra()), :w1)
    @test_throws MethodError interpret(branch(pool, ¬, p), boolmodel, :w1)
end
