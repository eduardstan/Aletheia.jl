using Test
using Aletheia

@testset "presentation and rich display" begin
    # 1. Models & Frames
    f1 = Frame((:w1, :w2), Dict(:R => Dict(:w1 => [:w2], :w2 => [:w2])); index=true)
    @test sprint(show, f1) == "Frame(2 worlds)"
    s_f1 = sprint(show, MIME("text/plain"), f1)
    @test occursin("Frame (2 worlds, 1 relation)", s_f1)
    @test occursin("Worlds (2): :w1, :w2", s_f1)
    @test occursin(":w1 → :w2", s_f1)

    # Large frame
    large_worlds = tuple([Symbol("w", i) for i in 1:20]...)
    f_large = Frame(large_worlds, Dict(:R => Dict()); index=true)
    @test occursin("15 elided", sprint(show, MIME("text/plain"), f_large))

    # Model
    m1 = Model(f1, BOOLEAN, Dict("p" => Set([:w2]), "q" => Set([:w1, :w2])))
    @test sprint(show, m1) == "Model(2 worlds, BooleanAlgebra())"
    s_m1 = sprint(show, MIME("text/plain"), m1)
    @test occursin("Model (2 worlds, 1 relation", s_m1)
    @test occursin("p: {:w2}", s_m1)
    @test occursin("q: {:w1, :w2}", s_m1)

    # Large model
    m_large = Model(f_large, BOOLEAN, Dict("p" => Set(large_worlds)))
    @test occursin("15 elided", sprint(show, MIME("text/plain"), m_large))

    # Callable relations / valuation
    f_callable = Frame((:w1, :w2), (w, r) -> (:w2,); index=true)
    m_callable = Model(f_callable, (a, w) -> true, BOOLEAN)
    @test occursin("<callable>", sprint(show, MIME("text/plain"), f_callable))
    @test occursin("<function>", sprint(show, MIME("text/plain"), m_callable))

    # 2. Algebras
    @test sprint(show, MIME("text/plain"), BOOLEAN) == "BooleanAlgebra (carrier Bool: {false, true})"
    @test occursin("GodelAlgebra{3}", sprint(show, MIME("text/plain"), GodelAlgebra(3)))
    @test occursin("LukasiewiczAlgebra{4}", sprint(show, MIME("text/plain"), LukasiewiczAlgebra(4)))
    @test sprint(show, MIME("text/plain"), GodelAlgebra()) == "GodelAlgebra (unit interval [0.0, 1.0])"
    @test sprint(show, MIME("text/plain"), LukasiewiczAlgebra()) == "LukasiewiczAlgebra (unit interval [0.0, 1.0])"

    s_h4 = sprint(show, MIME("text/plain"), H4)
    @test occursin("FiniteFLewAlgebra{4}", s_h4)
    @test occursin("Meet (∧)", s_h4)
    @test occursin("Join (∨)", s_h4)
    @test occursin("Implication (→)", s_h4)

    # 3. Extensions & describe view
    sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    ext_bool = extension(p, m1)
    @test ext_bool isa BitVector
    @test ext_bool == BitVector([0, 1])

    ext_view = Extension(ext_bool, m1)
    @test sprint(show, ext_view) == "Extension(Bool[0, 1])"
    s_ext = sprint(show, MIME("text/plain"), ext_view)
    @test occursin("Extension (1 of 2 worlds satisfy)", s_ext)
    @test occursin("Satisfied at: :w2", s_ext)
    @test occursin("Unsatisfied at: :w1", s_ext)

    # describe view
    s_desc = sprint(describe, ext_bool, m1)
    @test occursin("Extension (1 of 2 worlds satisfy)", s_desc)

    # Non-boolean extension
    m_g = Model(f1, GodelAlgebra(3), Dict("p" => Dict(:w1 => 0.5, :w2 => 1.0)))
    ext_g = extension(p, m_g)
    @test ext_g isa Vector{Float64}
    ext_g_view = Extension(ext_g, m_g)
    s_ext_g = sprint(show, MIME("text/plain"), ext_g_view)
    @test occursin("Extension (2 worlds)", s_ext_g)
    @test occursin(":w1 => 0.5", s_ext_g)

    # 4. Bisimulation Quotients
    q = bisimulation_contraction(m1)
    @test occursin("BisimulationContraction", sprint(show, q))
    s_q = sprint(show, MIME("text/plain"), q)
    @test occursin("BisimulationContraction (2 →", s_q)
    @test occursin("Classes (", s_q)

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
    @test occursin("ClauseSet (2 clauses)", s_cs)
    @test occursin("p(x) :- q(y)", s_cs)

    sub = Substitution(x => Constant("a"))
    @test sprint(show, sub) == "Substitution(x => \"a\")"
    @test sprint(show, MIME("text/plain"), sub) == "Substitution: {x ↦ \"a\"}"

    ee = EntailmentExample(px; positive=true)
    ie = InterpretationExample(m1; positive=true)
    pe = ProofExample("proof"; positive=false)
    @test occursin("EntailmentExample (+): p(x)", sprint(show, MIME("text/plain"), ee))
    @test occursin("InterpretationExample (+): Model(2 worlds", sprint(show, MIME("text/plain"), ie))
    @test occursin("ProofExample (-): proof", sprint(show, MIME("text/plain"), pe))
end
