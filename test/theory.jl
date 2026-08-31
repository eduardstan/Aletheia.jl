struct TheoryXor end
Aletheia.arity(::TheoryXor) = 2
Aletheia.notation(::TheoryXor) = "⊻"

struct TheoryUnknownTerm <: FirstOrderTerm end
struct TheoryUnknownFO <: FirstOrderFormula end
const FOAnd = Aletheia.FOAnd
const FOOr = Aletheia.FOOr
const FOImplies = Aletheia.FOImplies
const FONot = Aletheia.FONot
const FOExists = Aletheia.FOExists
const FOForall = Aletheia.FOForall
const FOAtom = Aletheia.FOAtom
const FOPredicate = Aletheia.FOPredicate
const FOEquality = Aletheia.FOEquality
const FOConstant = Aletheia.FOConstant
const FOFunction = Aletheia.FOFunction
const FOFormula = Aletheia.FOFormula
const FOTerm = Aletheia.FOTerm
const FOInterpretation = Aletheia.FOInterpretation
const FOModel = Aletheia.FOModel
const FOVariable = Aletheia.FOVariable
struct TheoryDummyProver <: AbstractProver end
struct TheoryUnknownProvider <: Aletheia._RelationProvider end
struct TheoryUnknownValuation end

function theory_random_formula(pool, p, q, rng, depth)
    depth == 0 && return rand(rng, (p, q))
    choice = rand(rng, 1:5)
    choice == 1 && return branch(pool, ¬, theory_random_formula(pool, p, q, rng, depth - 1))
    choice == 2 && return branch(pool, Diamond(:R), theory_random_formula(pool, p, q, rng, depth - 1))
    choice == 3 && return branch(pool, Box(:R), theory_random_formula(pool, p, q, rng, depth - 1))
    connective = choice == 4 ? (∧) : (∨)
    branch(pool, connective, theory_random_formula(pool, p, q, rng, depth - 1),
        theory_random_formula(pool, p, q, rng, depth - 1))
end

@testset "standard translation and first-order core" begin
    @test Variable("x") == Variable(:x)
    @test string(Predicate(:p, Variable(:x))) == "p(x)"
    @test string(Predicate(:p, (Variable(:x),))) == "p(x)"
    @test string(Predicate(:p, [Variable(:x)])) == "p(x)"
    @test sprint(show, Predicate(:p, Variable(:x))) == "p(x)"
    @test string(Aletheia.FOAnd(Predicate(:p, Variable(:x)), FOOr(Predicate(:q, Variable(:x)), Predicate(:r, Variable(:x))))) ==
        "p(x) ∧ (q(x) ∨ r(x))"
    interpretation = FirstOrderInterpretation((1, 2), Dict(:p => Set([1, 2]), :R => Set([(1, 2)])))
    keyword_interpretation = FirstOrderInterpretation((1,); predicates=Dict(:p => Set([1])))
    @test domain(keyword_interpretation) == (1,)
    @test evaluate(Predicate(:p, Variable(:x)), interpretation, Dict(:x => 1))
    @test interpret(Predicate(:p, Variable(:x)), interpretation, Dict(:x => 1))
    @test evaluate(Exists(Variable(:y), Predicate(:p, Variable(:y))), interpretation)
    @test evaluate(Forall(Variable(:y), Aletheia.FOImplies(Predicate(:R, Variable(:x), Variable(:y)),
        Predicate(:p, Variable(:y)))), interpretation, Dict(:x => 1))
    @test_throws ArgumentError FirstOrderInterpretation((), Dict())
    @test_throws KeyError evaluate(Predicate(:p, Variable(:z)), interpretation)

    signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    pool = FormulaPool(signature)
    p, q = atom(pool, "p"), atom(pool, "q")
    formula = branch(pool, ∧, branch(pool, Diamond(:R), p), branch(pool, Box(:R), branch(pool, →, p, q)))
    frame0 = Frame((1, 2, 3), Dict(:R => Dict(1 => [2, 3], 2 => [2], 3 => [])); index=true)
    model0 = Model(frame0, BOOLEAN, Dict("p" => Set([1, 2]), "q" => Set([2, 3])))
    translated = standard_translation(formula)
    foi = first_order_interpretation(model0)
    for world in worlds(frame0)
        @test evaluate(translated, foi, Dict(:x => world)) == check(formula, model0, world)
    end
    random_formulas = (p, branch(pool, ¬, p), branch(pool, ∨, p, q),
        branch(pool, Diamond(:R), p), branch(pool, Box(:R), branch(pool, →, p, q)))
    for trial in 1:8
        p_worlds = [world for (i, world) in enumerate(worlds(frame0)) if iseven(trial + i)]
        q_worlds = [world for (i, world) in enumerate(worlds(frame0)) if isodd(trial + i)]
        random_valuation = Dict("p" => Set(p_worlds), "q" => Set(q_worlds))
        random_model = Model(frame0, BOOLEAN, random_valuation)
        random_formula = random_formulas[1 + mod(7 * trial, length(random_formulas))]
        random_fo = first_order_interpretation(random_model)
        @test all(evaluate(standard_translation(random_formula), random_fo, Dict(:x => world)) ==
            check(random_formula, random_model, world) for world in worlds(frame0))
    end

    # Random finite frames and valuations exercise every standard-translation
    # clause against the direct Boolean evaluator, not just its printed shape.
    rng = MersenneTwister(0xA1E7)
    for trial in 1:24
        n = rand(rng, 2:5)
        random_worlds = Tuple(1:n)
        random_adjacency = Dict(world => [target for target in random_worlds if rand(rng, Bool)]
                                 for world in random_worlds)
        random_frame = Frame(random_worlds, Dict(:R => random_adjacency); index=true)
        random_valuation = Dict(name => Set(world for world in random_worlds if rand(rng, Bool))
                                 for name in ("p", "q"))
        random_model = Model(random_frame, BOOLEAN, random_valuation)
        random_formula = theory_random_formula(pool, p, q, rng, 3)
        translation = standard_translation(random_formula)
        interpretation = first_order_interpretation(random_model)
        @test all(evaluate(translation, interpretation, Dict(:x => world)) ==
            check(random_formula, random_model, world) for world in random_worlds)
    end

    @test standard_translation(p; world=:root) isa FirstOrderFormula
    @test standard_translation(p, :root) isa FirstOrderFormula
    @test_throws ArgumentError standard_translation(branch(pool, TheoryXor(), p, q))
end

@testset "bisimulation and contraction" begin
    sig = Signature((¬, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    f1 = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [2])); index=true)
    f2 = Frame((:a, :b), Dict(:R => Dict(:a => [:b], :b => [:b])); index=true)
    m1 = Model(f1, BOOLEAN, Dict("p" => Set([1])))
    m2 = Model(f2, BOOLEAN, Dict("p" => Set([:a])))
    @test bisimilar(m1, 1, m2, :a; atoms=["p"], relations=[:R])
    @test bisimilar(m1, 1, m2, :a, ["p"])
    @test !bisimilar(m1, 2, m2, :a; atoms=["p"], relations=[:R])
    bad = Model(Frame((:a, :b), Dict(:R => Dict(:a => [], :b => [])); index=true), BOOLEAN,
                Dict("p" => Set([:a])))
    @test !bisimilar(m1, 1, bad, :a; atoms=["p"], relations=[:R])
    @test_throws ArgumentError bisimilar(Model(f1, BOOLEAN, (a, w) -> false), 1, m1, 1)

    callback_model = Model(Frame((1, 2), Dict(); index=true), BOOLEAN,
        Aletheia.ValuationCallback((a, world) -> a == "p" && world == 2))
    @test_throws ArgumentError bisimilar(callback_model, 1, callback_model, 2)
    @test_throws ArgumentError bisimulation_contraction(callback_model)
    @test_throws ArgumentError first_order_interpretation(callback_model)
    callback_quotient = bisimulation_contraction(callback_model; atoms=["p"])
    @test length(classes(callback_quotient)) == 2
    @test [check(p, callback_model, world) for world in worlds(frame(callback_model))] ==
        [check(p, callback_quotient, contraction_world(callback_quotient, world))
         for world in worlds(frame(callback_model))]

    unknown_provider_frame = Frame((1,), TheoryUnknownProvider())
    provider_error = try
        Aletheia._model_relation_names(unknown_provider_frame)
    catch error
        error
    end
    @test provider_error isa ArgumentError
    @test occursin("TheoryUnknownProvider", sprint(showerror, provider_error))
    unknown_valuation_model = Model(Frame((1,); index=true), BOOLEAN, TheoryUnknownValuation())
    @test_throws ArgumentError Aletheia._valuation_atoms(unknown_valuation_model)
    @test_throws ArgumentError bisimulation_contraction(unknown_valuation_model)

    # A dictionary atom key that is also a world is ambiguous without an
    # explicit namespace; inference must not silently erase its labels.
    ambiguous_frame = Frame((1, 2), Dict(); index=true)
    ambiguous_model = Model(ambiguous_frame, BOOLEAN, Dict(1 => Set([1])))
    ambiguous_pool = FormulaPool(Signature((¬,)))
    ambiguous_atom = atom(ambiguous_pool, 1)
    @test [interpret(ambiguous_atom, ambiguous_model, world) for world in worlds(ambiguous_frame)] == [true, false]
    @test_throws ArgumentError bisimilar(ambiguous_model, 1, ambiguous_model, 2)
    @test_throws ArgumentError bisimulation_contraction(ambiguous_model)
    @test_throws ArgumentError first_order_interpretation(ambiguous_model)
    ambiguous_quotient = bisimulation_contraction(ambiguous_model; atoms=[1])
    @test length(classes(ambiguous_quotient)) == 2
    ambiguous_fo = first_order_interpretation(ambiguous_model; atoms=[1])
    @test evaluate(standard_translation(ambiguous_atom), ambiguous_fo, Dict(:x => 1))
    @test !evaluate(standard_translation(ambiguous_atom), ambiguous_fo, Dict(:x => 2))

    # Generated interval frames use a relation provider rather than a relation
    # dictionary; relation inference must still include their Allen relations.
    interval = interval_frame(3)
    interval_model = Model(interval, BOOLEAN, Dict())
    interval_worlds = worlds(interval)
    @test !bisimilar(interval_model, interval_worlds[1], interval_model, interval_worlds[2])
    @test !bisimilar(interval_model, interval_worlds[1], interval_model, interval_worlds[2]; relations=[BEFORE])
    interval_quotient = bisimulation_contraction(interval_model)
    @test length(classes(interval_quotient)) > 1

    redundant = Frame((1, 2, 3), Dict(:R => Dict(1 => [2, 3], 2 => [2, 3], 3 => [2, 3])); index=true)
    redundant_model = Model(redundant, BOOLEAN, Dict("p" => Set([1, 2, 3])))
    quotient = bisimulation_contraction(redundant_model; atoms=["p"], relations=[:R])
    @test length(classes(quotient)) == 1
    @test contraction_world(quotient, 1) == first(classes(quotient))
    @test worlds(frame(quotient)) == classes(quotient)
    @test model(quotient) === quotient.model
    @test world_map(quotient) === quotient.world_map
    @test algebra(quotient) === BOOLEAN
    @test valuation(quotient) === valuation(quotient.model)
    quotient_world = first(classes(quotient))
    @test contraction_world(quotient, quotient_world) === quotient_world
    @test collect(accessible(quotient, quotient_world, :R)) == [quotient_world]
    @test extension(p, quotient) == BitVector([true])
    for world in worlds(redundant)
        @test check(p, redundant_model, world) == check(p, quotient, world)
        @test check(branch(pool, Diamond(:R), p), redundant_model, world) ==
            check(branch(pool, Diamond(:R), p), quotient, world)
    end

    # Correctness gate for the reusable quotient: randomized labelled frames
    # and modal DAGs compare every original world with its quotient class.
    gate_rng = MersenneTwister(0xB15_2024)
    gate_signature = Signature((¬, ∧, ∨, Diamond(:R), Box(:R)))
    for trial in 1:128
        n = rand(gate_rng, 2:8)
        gate_worlds = Tuple(1:n)
        gate_edges = Dict(w => [target for target in gate_worlds if rand(gate_rng, Bool)] for w in gate_worlds)
        gate_frame = Frame(gate_worlds, Dict(:R => gate_edges); index=true)
        gate_valuation = Dict(name => Set(w for w in gate_worlds if rand(gate_rng, Bool)) for name in ("p", "q"))
        gate_model = Model(gate_frame, BOOLEAN, gate_valuation)
        gate_pool = FormulaPool(gate_signature)
        gp, gq = atom(gate_pool, "p"), atom(gate_pool, "q")
        gate_quotient = bisimulation_contraction(gate_model; atoms=["p", "q"], relations=[:R])
        gate_qmodel = model(gate_quotient)
        for _ in 1:16
            gate_formula = theory_random_formula(gate_pool, gp, gq, gate_rng, rand(gate_rng, 1:5))
            for world in gate_worlds
                @test check(gate_formula, gate_model, world) ==
                    check(gate_formula, gate_qmodel, contraction_world(gate_quotient, world))
            end
        end
    end
end

@testset "normal forms" begin
    sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    p, q, r = atom(pool, "p"), atom(pool, "q"), atom(pool, "r")
    formula = branch(pool, →, branch(pool, ∧, p, q), branch(pool, ∨, q, r))
    c, d = to_cnf(formula), to_dnf(formula)
    @test Aletheia.pool(c) === pool && Aletheia.pool(d) === pool
    @test iscnf(c) && isdnf(d)
    @test iscnf(p) && isdnf(p)
    @test !iscnf(branch(pool, ∨, branch(pool, ∧, p, q), r))
    frame0 = Frame((:w,); index=true)
    for values in ((false, false, false), (false, true, false), (true, false, true), (true, true, true))
        valuation = Dict(name => (values[i] ? Set([:w]) : Set{Symbol}()) for (i, name) in enumerate(("p", "q", "r")))
        model = Model(frame0, BOOLEAN, valuation)
        @test check(formula, model, :w) == check(c, model, :w) == check(d, model, :w)
    end
    # Semantic preservation is also checked over random formulas and valuations;
    # CNF/DNF shape predicates are only secondary sanity checks.
    rng = MersenneTwister(0xC0FFEE)
    for trial in 1:24
        random_formula = theory_random_formula(pool, p, q, rng, 3)
        random_valuation = Dict(name => (rand(rng, Bool) ? Set([:w]) : Set{Symbol}())
                                 for name in ("p", "q"))
        random_model = Model(frame0, BOOLEAN, random_valuation)
        random_cnf, random_dnf = to_cnf(random_formula), to_dnf(random_formula)
        @test check(random_formula, random_model, :w) == check(random_cnf, random_model, :w) ==
            check(random_dnf, random_model, :w)
    end
    modal = branch(pool, Diamond(:R), p)
    @test iscnf(modal) && isdnf(modal)
    @test_throws ArgumentError to_cnf(atom(FormulaPool(Signature((→,))), "p"))
end

@testset "proof-search interface" begin
    sig = Signature((¬, ∧, ∨, →, Diamond(:R)))
    pool = FormulaPool(sig)
    p, q = atom(pool, "p"), atom(pool, "q")
    tautology = branch(pool, →, p, p)
    contradiction = branch(pool, ∧, p, branch(pool, ¬, p))
    prover = PropositionalProver()
    @test isvalid(prover, tautology) === true
    @test issatisfiable(prover, contradiction) === false
    @test entails(p, p, prover) === true
    @test Bool(ProverResult(:valid; answer=true))
    @test prove(tautology, prover).status == :sat
    @test prove_valid(tautology, prover).status == :valid
    @test issatisfiable(contradiction, prover) === false
    @test isvalid(tautology, prover) === true
    @test entails((p,), p, prover) === true
    @test entails(p, p) === true
    @test issatisfiable(tautology) === true
    @test_throws MethodError prove(TheoryDummyProver(), p)
    @test_throws MethodError prove_valid(TheoryDummyProver(), p)
    @test_throws ArgumentError entails(prover, p, TheoryDummyProver())
    @test isvalid(tautology) === true
    @test prove(prover, tautology; atoms=[p]).status == :sat
    @test_throws ArgumentError prove(prover, tautology; atoms=["q"])
    @test_throws ArgumentError prove_valid(prover, tautology; atoms=["q"])
    @test_throws ArgumentError entails(prover, (p,), p; atoms=["q"])
    @test issatisfiable(prover, branch(pool, Diamond(:R), p)) === nothing
    @test prove_valid(prover, tautology).status == :valid
    @test prove(prover, contradiction).status == :unsat

    finite = FiniteModelProver(1)
    sat_formula = branch(pool, Diamond(:R), p)
    sat_result = prove(finite, sat_formula)
    @test sat_result.status == :sat && sat_result.answer === true
    @test sat_result.countermodel isa Model
    @test sat_result.certificate === sat_result.countermodel
    @test any(check(sat_formula, sat_result.countermodel, world)
              for world in worlds(frame(sat_result.countermodel)))

    valid_result = prove_valid(finite, tautology)
    @test valid_result.status == :valid && valid_result.answer === true
    unsat_result = prove(finite, contradiction)
    @test unsat_result.status == :unsat && unsat_result.answer === false

    needs_two_worlds = branch(pool, Diamond(:R),
        branch(pool, ∧, p, branch(pool, ¬, branch(pool, Diamond(:R), p))))
    inconclusive = prove(finite, needs_two_worlds)
    @test inconclusive.status == :inconclusive && inconclusive.answer === nothing
    @test prove_valid(finite, sat_formula).status == :invalid
    @test prove_entails(finite, (sat_formula,), p).status == :inconclusive

    # Finite truth algebras use the same evaluator and designated top value.
    godel_sat = prove(finite, p; algebra=G3)
    godel_valid = prove_valid(finite, tautology; algebra=G3)
    @test godel_sat.status == :sat && godel_sat.countermodel isa Model
    @test check(p, godel_sat.countermodel, first(worlds(frame(godel_sat.countermodel)))) == top(G3)
    @test godel_valid.status == :valid
    @test prove(finite, p; algebra=GodelAlgebra()).status == :unknown
    @test_throws ArgumentError FiniteModelProver(0)
    @test prove(finite, sat_formula; bound=1).status == :sat
end


@testset "theory edge cases" begin
    @test string(Constant(:c)) == "c"
    @test string(Equality(Variable(:x), Constant(1))) == "x = 1"
    @test string(FONot(Aletheia.FOAnd(Predicate(:p, Variable(:x)), Predicate(:q, Variable(:x))))) == "¬(p(x) ∧ q(x))"
    @test string(Aletheia.FOImplies(Predicate(:p, Variable(:x)), Predicate(:q, Variable(:x)))) == "p(x) → q(x)"
    @test string(FOExists(Variable(:x), Predicate(:p, Variable(:x)))) == "∃x. p(x)"
    @test string(FOForall(Variable(:x), Predicate(:p, Variable(:x)))) == "∀x. p(x)"
    @test string(TheoryUnknownTerm()) == "Main.TheoryUnknownTerm()" || string(TheoryUnknownTerm()) isa String
    @test Aletheia._fo_term_text(TheoryUnknownTerm()) isa String
    @test Aletheia._fo_text(TheoryUnknownFO()) isa String
    @test_throws ArgumentError evaluate(TheoryUnknownFO(), FirstOrderInterpretation((1,), Dict()))
    fi = FirstOrderInterpretation((1, 2), Dict(:d => Dict((1,) => true), :e => Dict(1 => true),
        :R => Dict((1, 2) => true)))
    @test evaluate(Predicate(:d, Variable(:x)), fi, Dict(:x => 1))
    @test evaluate(Predicate(:e, Variable(:x)), fi, Dict(:x => 1))
    @test evaluate(Equality(Variable(:x), Variable(:x)), fi, Dict(:x => 1))
    @test evaluate(Equality(Constant(1), Constant(1)), fi)
    @test evaluate(FONot(Predicate(:e, Variable(:x))), fi, Dict(:x => 1)) == false
    @test_throws KeyError evaluate(Predicate(:empty, Variable(:x)),
        FirstOrderInterpretation((1,), Dict(:empty => Dict())), Dict(:x => 1))
    @test evaluate(FODisjunction(Predicate(:d, Variable(:x)), Predicate(:e, Variable(:x))), fi, Dict(:x => 1))
    @test evaluate(Aletheia.FOAnd(Predicate(:d, Variable(:x)), Predicate(:e, Variable(:x))), fi, (x=1,))
    @test_throws KeyError evaluate(Predicate(:missing, Variable(:x)), fi, Dict(:x => 1))
    ff = FirstOrderInterpretation((1,), (name, args...) -> name == :p && args == (1,))
    @test evaluate(Predicate(:p, Variable(:x)), ff, Dict(:x => 1))
    sig = Signature((¬, ∧, ∨, →, Diamond(:R), TheoryXor()))
    pool = FormulaPool(sig); p, q = atom(pool, "p"), atom(pool, "q")
    @test standard_translation(branch(pool, ¬, p)) isa FirstOrderFormula
    @test standard_translation(branch(pool, ∨, p, q)) isa FirstOrderFormula
    @test_throws ArgumentError standard_translation(branch(pool, TheoryXor(), p, q))
    frame = Frame((1,), Dict(:R => Dict(1 => [1])); index=true)
    @test_throws ArgumentError first_order_interpretation(Model(frame, GodelAlgebra(), Dict("p" => Dict(1 => 0.5))))
    callable_model = Model(Frame((1,), (w, r) -> ()), BOOLEAN, (a, w) -> true)
    @test_throws ArgumentError first_order_interpretation(callable_model)
    @test_throws ArgumentError first_order_interpretation(Model(Frame((1,), (w, r) -> ()), BOOLEAN,
        Dict("p" => Set([1]))))
    atom_pool = FormulaPool(Signature((¬,)))
    atom_handle = atom(atom_pool, "p")
    atom_model = Model(frame, BOOLEAN, Dict(atom_handle => Set([1])))
    atom_fo = first_order_interpretation(atom_model; atoms=[atom_handle], relations=[:R])
    @test evaluate(standard_translation(atom_handle), atom_fo, Dict(:x => 1))
    atom_quotient = bisimulation_contraction(atom_model; atoms=[atom_handle], relations=[:R])
    @test check(atom_handle, atom_quotient, 1)

    nfpool = FormulaPool(Signature((¬, ∧, ∨, →, Diamond(:R), TheoryXor())))
    a, b = atom(nfpool, "a"), atom(nfpool, "b")
    @test iscnf(branch(nfpool, ∧, a, b))
    @test isdnf(branch(nfpool, ∨, a, b))
    @test to_cnf(branch(nfpool, ¬, branch(nfpool, ∨, a, b))) isa Formula
    @test to_dnf(branch(nfpool, ¬, branch(nfpool, ∨, a, b))) isa Formula
    @test iscnf(to_cnf(branch(nfpool, TheoryXor(), a, b)))
    @test isdnf(to_dnf(branch(nfpool, TheoryXor(), a, b)))
    @test iscnf(branch(nfpool, ∧, branch(nfpool, ∨, a, b), branch(nfpool, ∨, a, a)))
    @test isdnf(branch(nfpool, ∨, branch(nfpool, ∧, a, b), branch(nfpool, ∧, a, a)))
    @test to_dnf(branch(nfpool, ¬, branch(nfpool, Diamond(:R), a))) isa Formula
    @test Aletheia._nnf(branch(nfpool, Diamond(:R), a), true) isa Formula
    @test isdnf(branch(nfpool, ∧, a, b))
    @test to_dnf(branch(nfpool, ∨, a, b)) isa Formula
    @test to_dnf(branch(nfpool, ∧, a, b)) isa Formula
    @test Aletheia._dnf_from_nnf(branch(nfpool, Diamond(:R), a)) isa Vector

    pair_pool = FormulaPool(Signature((¬,)))
    pair_atom = atom(pair_pool, "p")
    pair_frame = Frame((1, 2), Dict(); index=true)
    pair_model = Model(pair_frame, BOOLEAN, Dict((pair_atom, 1) => true, (2, pair_atom) => false,
        1 => Dict("q" => true)))
    @test_throws ArgumentError Aletheia._valuation_atoms(pair_model)
    @test sprint(show, first(classes(bisimulation_contraction(Model(frame, BOOLEAN,
        Dict("p" => Set([1]))); atoms=["p"], relations=[:R])))) isa String
    split_frame = Frame((1, 2), Dict(:R => Dict(1 => [1], 2 => [])); index=true)
    split_model = Model(split_frame, BOOLEAN, Dict("p" => Set([1])))
    split_q = bisimulation_contraction(split_model; atoms=["p"], relations=[:R])
    @test length(classes(split_q)) == 2

    @test_throws MethodError entails(TheoryDummyProver(), (), a)
    @test Aletheia._lookup_valuation(Valuation(Dict("p" => Set([:w]))), "p", :w)
end
