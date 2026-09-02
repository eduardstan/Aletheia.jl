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
    templated = collect(downward_refinements(Clause(Predicate(:p, Constant(:a)));
        literals=[Predicate(:q, X)], substitutions=Substitution(:X => Constant(:b))))
    @test templated == [Clause(Predicate(:p, Constant(:a)), Predicate(:q, Constant(:b)))]
    horn = HornClause(Predicate(:head, X), Literal(Predicate(:body, X), false))
    horn_negative = collect(downward_refinements(horn; literals=[Literal(Predicate(:newbody, X), false)]))
    @test !isempty(horn_negative) && all(candidate isa HornClause && ishorn(candidate) for candidate in horn_negative)
    @test all(subsumes(horn, candidate) && !subsumes(candidate, horn) for candidate in horn_negative)
    @test all(candidate isa HornClause for candidate in collect(downward_refinements(horn; substitutions=[Substitution(:X => Constant(:a))])))
    upward_horn = HornClause(Predicate(:head, FunctionTerm(:f, X)), Literal(Predicate(:body, X), false))
    upward_horn_candidates = collect(upward_refinements(upward_horn))
    @test !isempty(upward_horn_candidates) && all(candidate isa HornClause for candidate in upward_horn_candidates)
    @test_throws ArgumentError collect(downward_refinements(horn; literals=[Predicate(:newhead, X)]))
    substitution = Substitution(:X => Constant(:a))
    @test isempty(collect(downward_refinements(base; substitutions=[substitution], max_literals=0)))
    @test_throws ArgumentError collect(downward_refinements(base; substitutions=[substitution], max_literals=-1))
    bounded = collect(downward_refinements(base; substitutions=[substitution], max_literals=1))
    @test !isempty(bounded) && all(length(candidate) <= 1 for candidate in bounded)
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
    first_order = FirstOrderInterpretation((1,), Dict())
    @test_throws ArgumentError interpretation_example(first_order)
    @test_throws ArgumentError learning_from_interpretations(first_order)
end


@testset "ILP hypothesis scoring" begin
    function labelled_model(value; algebra=BOOLEAN, world=:w)
        model = Model(Frame((world,), Dict()), Dict("p" => Dict(world => value)); algebra=algebra)
        model
    end

    hypothesis = atom("p")
    positive_covered = InterpretationExample(labelled_model(true); positive=true)
    negative_covered = InterpretationExample(labelled_model(true); positive=false)
    negative_uncovered = InterpretationExample(labelled_model(false); positive=false)
    positive_uncovered = InterpretationExample(labelled_model(false); positive=true)

    # Each confusion cell is independently represented in this hand-counted set.
    result = score(hypothesis, [positive_covered, negative_covered,
                                negative_uncovered, positive_uncovered])
    @test result.true_positives == 1
    @test result.false_positives == 1
    @test result.true_negatives == 1
    @test result.false_negatives == 1
    @test result.accuracy == 0.5

    no_positives = score(hypothesis, [negative_covered, negative_uncovered])
    @test (no_positives.true_positives, no_positives.false_positives,
           no_positives.true_negatives, no_positives.false_negatives) == (0, 1, 1, 0)
    @test no_positives.accuracy == 0.5

    no_negatives = score(hypothesis, [positive_covered, positive_uncovered])
    @test (no_negatives.true_positives, no_negatives.false_positives,
           no_negatives.true_negatives, no_negatives.false_negatives) == (1, 0, 0, 1)
    @test no_negatives.accuracy == 0.5

    empty_result = score(hypothesis, InterpretationExample[])
    @test empty_result.true_positives == 0
    @test empty_result.false_positives == 0
    @test empty_result.true_negatives == 0
    @test empty_result.false_negatives == 0
    @test ismissing(empty_result.accuracy)

    covered_by_none = score(hypothesis, [positive_uncovered, negative_uncovered])
    @test (covered_by_none.true_positives, covered_by_none.false_positives,
           covered_by_none.true_negatives, covered_by_none.false_negatives) == (0, 0, 1, 1)
    @test covered_by_none.accuracy == 0.5

    partial = Model(Frame((:w,), Dict()), Dict("q" => Set([:w])); algebra=BOOLEAN)
    @test_throws KeyError check(hypothesis, partial, AnyWorld())
    partial_result = score(hypothesis, [InterpretationExample(partial; positive=true),
                                         InterpretationExample(partial; positive=false)])
    @test (partial_result.true_positives, partial_result.false_positives,
           partial_result.true_negatives, partial_result.false_negatives) == (0, 0, 1, 1)

    # AnyWorld is existential and does not depend on a first-world/index=1 convention.
    arbitrary_worlds = Model(Frame((:dead, :true), Dict()), Dict("p" => Set([:true])); algebra=BOOLEAN)
    arbitrary_world_result = score(hypothesis, [InterpretationExample(arbitrary_worlds)])
    @test (arbitrary_world_result.true_positives, arbitrary_world_result.false_positives,
           arbitrary_world_result.true_negatives, arbitrary_world_result.false_negatives) == (1, 0, 0, 0)

    malformed = Model(Frame((:w,), Dict()), Dict("p" => Dict(:w => 1)); algebra=BOOLEAN)
    @test_throws ArgumentError score(hypothesis, [InterpretationExample(malformed)])

    # A many-valued model covers only at the algebra's top value.
    many_valued_top = labelled_model(top(G3); algebra=G3)
    many_valued_middle = labelled_model(FiniteTruth(3); algebra=G3)
    many_valued = score(hypothesis, [InterpretationExample(many_valued_top; positive=true),
                                      InterpretationExample(many_valued_middle; positive=false)])
    @test (many_valued.true_positives, many_valued.false_positives,
           many_valued.true_negatives, many_valued.false_negatives) == (1, 0, 1, 0)
    @test many_valued.accuracy == 1.0

    @test_throws ArgumentError score(hypothesis, [positive_covered.interpretation])
    @test_throws ArgumentError score(hypothesis, [InterpretationExample(:not_a_model)])
    @test_throws ArgumentError HypothesisScore(-1, 0, 0, 0)
end
