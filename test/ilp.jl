@testset "ILP clauses and substitutions" begin
    X, Y, Z = Variable(:X), Variable(:Y), Variable(:Z)
    a, b = Constant(:a), Constant(:b)
    fX = FunctionTerm(:f, X)
    @test FOFunction(:f, [X]) == fX
    @test string(fX) == "f(X)"
    @test Predicate(:p) == Predicate(:p, ())
    @test evaluate(Predicate(:p, FunctionTerm(:f, Variable(:x))),
        FirstOrderInterpretation((1, 2), Dict(:p => Set([2]), (:f, 1) => Dict((1,) => 2));
                                 functions=Dict(:f => Dict((1,) => 2))), Dict(:x => 1))
    @test evaluate(Predicate(:p, FunctionTerm(:f, Variable(:x))),
        FirstOrderInterpretation((1, 2), Dict(:p => Set([2])); functions=(name, x...) -> 2), Dict(:x => 1))
    @test evaluate(Predicate(:p, FunctionTerm(:f, Variable(:x))),
        FirstOrderInterpretation((1, 2), Dict(:p => Set([2])); functions=Dict(:f => (x -> 2))), Dict(:x => 1))

    pxy = Predicate(:p, X, Y)
    pxx = Predicate(:p, X, X)
    neg = Literal(pxy, false)
    @test !positive_literal(neg) && negative_literal(neg)
    @test atoms(neg) == pxy
    @test literal(pxy) == positive_literal(pxy)
    @test negative_literal(pxy) == neg
    @test string(neg) == "¬p(X, Y)"
    @test_throws ArgumentError Literal(FONegation(FOAnd(pxy, pxx)))
    @test_throws ArgumentError Literal(Constant(:not_an_atom))

    c = Clause(pxy, neg, pxy)
    @test length(c) == 2
    @test c[1] isa Literal && eltype(typeof(c)) == Literal
    @test collect(c) == collect(literals(c))
    @test c == Clause(neg, pxy)
    @test isequal(c, Clause((pxy, neg)))
    @test hash(c) == hash(Clause((neg, pxy)))
    @test string(Clause()) == "⊥"
    @test literals(c) == c.literals
    @test_throws ArgumentError Clause(FONegation(FOAnd(pxy, pxx)))
    @test_throws ArgumentError Clause(Constant(:bad_literal))
    horn = HornClause(Predicate(:head, X), Predicate(:body, X), Predicate(:body, Y))
    @test ishorn(horn) && ishorn(horn.clause) && ishorn(Clause())
    @test length(horn) == 3
    @test HornClause(nothing, Predicate(:body, X)) == HornClause(Clause(Literal(Predicate(:body, X), false)))
    @test HornClause((Predicate(:head, X), Literal(Predicate(:body, X), false))) isa HornClause
    @test HornClause(Set([Predicate(:head, X)])) isa HornClause
    @test HornClause(Predicate(:head, X), Literal(Predicate(:body, X), false)) isa HornClause
    @test collect(horn) == collect(literals(horn)) && horn[1] isa Literal
    @test string(horn) isa String && hash(horn) isa UInt
    @test HornClause([Predicate(:head, X), Literal(Predicate(:body, X), false)]) == HornClause(Clause(Predicate(:head, X), Literal(Predicate(:body, X), false)))
    @test_throws ArgumentError HornClause(Clause(Predicate(:a, X), Predicate(:b, X)))

    knowledge = ClauseSet(c, horn, c)
    @test length(knowledge) == 2
    @test ClauseSet() isa ClauseSet
    @test ClauseSet([c]) == ClauseSet(Set([c]))
    @test knowledge[1] isa Clause && collect(knowledge) == collect(clauses(knowledge))
    @test hash(knowledge) isa UInt
    @test knowledge == ClauseSet(horn, c)
    @test clauses(knowledge) == knowledge.clauses
    @test string(knowledge) isa String

    θ = Substitution(:X => a, :Y => FunctionTerm(:g, b))
    @test θ[X] == a && haskey(θ, :Y)
    @test length(θ) == 2 && tuple(collect(θ)...) == θ.bindings
    @test substitute(X, θ) == a
    @test substitute(θ, X) == a
    @test substitute(FunctionTerm(:f, X), θ) == FunctionTerm(:f, a)
    @test substitute(pxy, θ) == Predicate(:p, a, FunctionTerm(:g, b))
    @test substitute(neg, θ) == Literal(Predicate(:p, a, FunctionTerm(:g, b)), false)
    @test substitute(c, θ) == Clause(Predicate(:p, a, FunctionTerm(:g, b)),
                                      Literal(Predicate(:p, a, FunctionTerm(:g, b)), false))
    @test substitute(horn, θ) isa HornClause
    @test substitute(knowledge, θ) isa ClauseSet
    @test_throws KeyError θ[:missing]
    @test_throws ArgumentError Substitution(:X => a, X => b)
    @test_throws ArgumentError Substitution(:X => :not_a_term)
    @test_throws ArgumentError Substitution(1 => a)
    @test !haskey(θ, :missing)
    @test_throws ArgumentError haskey(θ, 1)
    @test substitute(Equality(X, a), θ) == Equality(a, a)
    @test substitute(Substitution(Dict(:X => a)), X) == a
    @test substitute(Substitution([:X => a]), X) == a
    @test Clause(Set([pxy, neg])) == c
    @test subsumes(Clause(Equality(X, a)), Clause(Equality(b, a)))
    @test !subsumes(Clause(Equality(X, a)), Clause(Equality(b, b)))

    # Definition 5.3 and the worked family example in Muggleton--De Raedt (1994), p. 643.
    general = HornClause(Predicate(:father, X, Y), Predicate(:parent, X, Y), Predicate(:male, X))
    specific = Clause(Predicate(:father, a, b), Literal(Predicate(:parent, a, b), false),
                      Literal(Predicate(:parent, a, Constant(:ann)), false), Literal(Predicate(:male, a), false),
                      Predicate(:female, Constant(:ann)))
    @test subsumes(general, specific)
    @test more_general(general, specific)
    @test more_specific(specific, general)
    @test !subsumes(specific, general)

    # Quasi-order: distinct clauses can subsume each other after a substitution
    # identifies Z with Y (survey p. 643, equivalence discussion).
    q1 = Clause(Predicate(:parent, X, Y), Literal(Predicate(:mother, X, Y), false),
                Literal(Predicate(:mother, X, Z), false))
    q2 = Clause(Predicate(:parent, X, Y), Literal(Predicate(:mother, X, Y), false))
    @test q1 != q2
    @test subsumes(q1, q2) && subsumes(q2, q1)
    @test equivalent_under_subsumption(q1, q2)

    # Backtracking and repeated-variable constraints are essential.
    @test subsumes(Clause(Predicate(:p, X), Predicate(:q, X)),
                   Clause(Predicate(:p, a), Predicate(:p, b), Predicate(:q, b)))
    @test !subsumes(Clause(Predicate(:p, X, X)), Clause(Predicate(:p, a, b)))
    @test !subsumes(Clause(Predicate(:p, X)), Clause(Predicate(:p, a, b)))
    @test !subsumes(Clause(Predicate(:p, X)), Clause(Literal(Predicate(:p, a), false)))
    @test subsumes(Clause(), Clause(Predicate(:p, a)))
    @test !subsumes(Clause(Predicate(:p, X)), Clause())

    # Survey's implication counterexample (pp. 643, 648): c implies d by self-resolution,
    # but c does not θ-subsumes d.  This layer deliberately does not call a prover.
    recursive_c = HornClause(Predicate(:p, FunctionTerm(:f, X)), Predicate(:p, X))
    recursive_d = HornClause(Predicate(:p, FunctionTerm(:f, FunctionTerm(:f, Y))), Predicate(:p, Y))
    @test !subsumes(recursive_c, recursive_d)
    @test !subsumes(recursive_d, recursive_c)
end

@testset "ILP lazy refinements and learning settings" begin
    X, Y = Variable(:X), Variable(:Y)
    base = Clause(Predicate(:p, X))
    templates = (Predicate(:q, X), Literal(Predicate(:r, X), false))
    down = downward_refinements(base; literals=templates)
    @test Base.IteratorSize(typeof(down)) == Base.SizeUnknown()
    first_down = first(down)
    @test subsumes(base, first_down) && !subsumes(first_down, base)
    @test length(collect(downward_refinements(base; literals=templates))) == 2
    @test isempty(collect(downward_refinements(base; predicates=[:q => 1], max_literals=1)))
    @test !isempty(collect(downward_refinements(base; predicates=[:q => 1])))
    @test_throws ArgumentError collect(downward_refinements(base; predicates=[:q => -1]))
    predicate_stream = (item for item in (Literal(Predicate(:q, X)), Equality(X, X)))
    @test length(collect(downward_refinements(base; predicates=predicate_stream))) == 2
    @test_throws ArgumentError collect(downward_refinements(base; predicates=[:malformed]))
    @test_throws ArgumentError collect(downward_refinements(base; substitutions=[Dict(:X => :bad)]))
    @test !isempty(collect(downward_refinements(base; literals=[Predicate(:q, X)], substitutions=Dict(:X => Constant(:a)))))
    substitutions = [Substitution(:X => Constant(:a)), Substitution(:X => Constant(:b))]
    multi = collect(downward_refinements(base; literals=(Predicate(:q, Constant(i)) for i in 1:2), substitutions=substitutions))
    @test length(multi) == 6

    infinite_literals = (Literal(Predicate(:q, Constant(i))) for i in Iterators.countfrom(1))
    lazy = downward_refinements(base; literals=infinite_literals)
    first_three = collect(Iterators.take(lazy, 3))
    @test length(first_three) == 3
    @test all(subsumes(base, candidate) && !subsumes(candidate, base) for candidate in first_three)
    @test length(unique(first_three)) == 3

    up = collect(upward_refinements(Clause(Predicate(:p, FunctionTerm(:f, X)), Predicate(:q, X))))
    @test !isempty(up)
    @test all(subsumes(candidate, Clause(Predicate(:p, FunctionTerm(:f, X)), Predicate(:q, X))) &&
              !subsumes(Clause(Predicate(:p, FunctionTerm(:f, X)), Predicate(:q, X)), candidate) for candidate in up)
    @test isempty(collect(upward_refinements(Clause())))
    collision = Clause(Predicate(:p, FunctionTerm(:f, Variable(:_G1))), Equality(Constant(:a), X))
    @test !isempty(collect(upward_refinements(collision)))

    frame = Frame((:w1, :w2), Dict(:R => Dict(:w1 => [:w2], :w2 => [])); index=true)
    model = Model(frame, BOOLEAN, Dict("p" => Set([:w1])))
    example = interpretation_example(model)
    @test example isa InterpretationExample
    @test example.interpretation === model && example.positive
    @test model_example(model; positive=false).positive == false
    @test learning_from_interpretations(model).interpretation === model
    @test learning_from_entailment(Predicate(:p, Constant(:a))).example isa Predicate
    @test learning_from_proofs(:proof).proof == :proof
    @test_throws ArgumentError interpretation_example(FirstOrderInterpretation((1,), Dict()))
end
