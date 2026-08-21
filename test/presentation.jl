using Test
using Aletheia

@testset "presentation and rich display" begin
    # 1. Models & Frames
    f1 = Frame((:w1, :w2), Dict(:R => Dict(:w1 => [:w2], :w2 => [:w2])); index=true)
    @test sprint(show, f1) == "Frame(2 worlds)"
    s_f1 = sprint(show, MIME("text/plain"), f1)
    @test contains(s_f1, "Frame (2 worlds, 1 relation)")
    @test contains(s_f1, "Worlds (2): :w1, :w2")
    @test contains(s_f1, ":w1 → :w2")

    # Large frame
    large_worlds = tuple([Symbol("w", i) for i in 1:20]...)
    f_large = Frame(large_worlds, Dict(:R => Dict()); index=true)
    @test contains(sprint(show, MIME("text/plain"), f_large), "15 elided")

    # Model
    m1 = Model(f1, BOOLEAN, Dict("p" => Set([:w2]), "q" => Set([:w1, :w2])))
    @test sprint(show, m1) == "Model(2 worlds, BooleanAlgebra (carrier Bool: {false, true}))"
    s_m1 = sprint(show, MIME("text/plain"), m1)
    @test contains(s_m1, "Model (2 worlds, 1 relation")
    @test contains(s_m1, "p: {:w2}")
    @test contains(s_m1, "q: {:w1, :w2}")

    # Large model
    m_large = Model(f_large, BOOLEAN, Dict("p" => Set(large_worlds)))
    @test contains(sprint(show, MIME("text/plain"), m_large), "15 elided")

    # Callable relations / valuation
    f_callable = Frame((:w1, :w2), (w, r) -> (:w2,); index=true)
    m_callable = Model(f_callable, (a, w) -> true, BOOLEAN)
    @test contains(sprint(show, MIME("text/plain"), f_callable), "<callable>")
    @test contains(sprint(show, MIME("text/plain"), m_callable), "<callable>")

    # 2. Algebras
    @test sprint(show, MIME("text/plain"), BOOLEAN) == "BooleanAlgebra (carrier Bool: {false, true})"
    @test contains(sprint(show, MIME("text/plain"), GodelAlgebra(3)), "GodelAlgebra{3}")
    @test contains(sprint(show, MIME("text/plain"), LukasiewiczAlgebra(4)), "LukasiewiczAlgebra{4}")
    @test sprint(show, MIME("text/plain"), GodelAlgebra()) == "GodelAlgebra (unit interval [0.0, 1.0])"
    @test sprint(show, MIME("text/plain"), LukasiewiczAlgebra()) == "LukasiewiczAlgebra (unit interval [0.0, 1.0])"

    s_h4 = sprint(show, MIME("text/plain"), H4)
    @test contains(s_h4, "FiniteFLewAlgebra{4}")
    @test contains(s_h4, "Meet (∧)")
    @test contains(s_h4, "Join (∨)")
    @test contains(s_h4, "Implication (→)")

    # 3. Extensions
    sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    ext_bool = extension(p, m1)
    @test sprint(show, ext_bool) == "Extension(Bool[0, 1])"
    s_ext = sprint(show, MIME("text/plain"), ext_bool)
    @test contains(s_ext, "Extension (1 of 2 worlds satisfy)")
    @test contains(s_ext, "Satisfied at: :w2")
    @test contains(s_ext, "Unsatisfied at: :w1")

    # Non-boolean extension
    m_g = Model(f1, GodelAlgebra(3), Dict("p" => Dict(:w1 => 0.5, :w2 => 1.0)))
    ext_g = extension(p, m_g)
    s_ext_g = sprint(show, MIME("text/plain"), ext_g)
    @test contains(s_ext_g, "Extension (2 worlds)")
    @test contains(s_ext_g, ":w1 => 0.5")

    # 4. Bisimulation Quotients
    q = bisimulation_contraction(m1)
    @test contains(sprint(show, q), "BisimulationContraction")
    s_q = sprint(show, MIME("text/plain"), q)
    @test contains(s_q, "BisimulationContraction (2 →")
    @test contains(s_q, "Classes (")

    # 5. ILP types
    x = Variable(:x)
    y = Variable(:y)
    px = Predicate(:p, (x,))
    qy = Predicate(:q, (y,))
    hc1 = HornClause(px, qy) # p(x) :- q(y)
    @test sprint(show, hc1) == "p(x) :- q(y)"
    hc2 = HornClause(px) # p(x)
    @test sprint(show, hc2) == "p(x)"
    hc3 = HornClause(nothing, qy) # :- q(y)
    @test sprint(show, hc3) == ":- q(y)"

    cs = ClauseSet([hc1, hc2])
    s_cs = sprint(show, MIME("text/plain"), cs)
    @test contains(s_cs, "ClauseSet (2 clauses)")
    @test contains(s_cs, "p(x) :- q(y)")

    sub = Substitution(x => Constant("a"))
    @test sprint(show, sub) == "Substitution(x => \"a\")"
    @test sprint(show, MIME("text/plain"), sub) == "Substitution: {x ↦ \"a\"}"

    ee = EntailmentExample(px; positive=true)
    ie = InterpretationExample(m1; positive=true)
    pe = ProofExample("proof"; positive=false)
    @test contains(sprint(show, MIME("text/plain"), ee), "EntailmentExample (+): p(x)")
    @test contains(sprint(show, MIME("text/plain"), ie), "InterpretationExample (+): Model (2 worlds")
    @test contains(sprint(show, MIME("text/plain"), pe), "ProofExample (-): proof")
end
