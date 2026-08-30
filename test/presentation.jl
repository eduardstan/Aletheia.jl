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
    @test occursin("… (10 elided)", sprint(show, MIME("text/plain"), f_large))

    # Model
    m1 = Model(f1, BOOLEAN, Dict("p" => Set([:w2]), "q" => Set([:w1, :w2])))
    @test sprint(show, m1) == "Model(2 worlds, BooleanAlgebra())"
    s_m1 = sprint(show, MIME("text/plain"), m1)
    @test occursin("Model (2 worlds, 1 relation", s_m1)
    @test occursin("p: {:w2}", s_m1)
    @test occursin("q: {:w1, :w2}", s_m1)

    # Large model
    m_large = Model(f_large, BOOLEAN, Dict("p" => Set(large_worlds)))
    @test occursin("… (10 elided)", sprint(show, MIME("text/plain"), m_large))

    # Callable relations / valuation
    f_callable = Frame((:w1, :w2), (w, r) -> (:w2,); index=true)
    m_callable = Model(f_callable, (a, w) -> true, BOOLEAN)
    @test occursin("relations supplied on demand", sprint(show, MIME("text/plain"), f_callable))
    @test occursin("relations supplied on demand", sprint(show, MIME("text/plain"), m_callable))
    @test occursin("<callable>", sprint(show, MIME("text/plain"), f_callable))
    @test occursin("<function>", sprint(show, MIME("text/plain"), m_callable))

    generated = interval_frame(3)
    generated_display = sprint(show, MIME("text/plain"), generated)
    @test occursin("Frame (6 worlds, relations supplied on demand)", generated_display)
    @test !occursin("1 relation", generated_display)

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


    # Branch coverage: bounded displays and edge cases.
    @test sprint(show, MIME("text/plain"), Extension(BitVector([0, 0]), m1)) ==
        "Extension (0 of 2 worlds satisfy)\n  Satisfied at: (none)\n  Unsatisfied at: :w1, :w2"
    @test sprint(show, MIME("text/plain"), Extension(BitVector([1, 1]), m1)) ==
        "Extension (2 of 2 worlds satisfy)\n  Satisfied at: :w1, :w2\n  Unsatisfied at: (none)"
    @test sprint(show, Extension(BitVector([0, 0]), m1)) == "Extension(Bool[0, 0])"

    # Exercise the large Boolean extension's elision branch and its terse form.
    ext_large = Extension(BitVector(ones(Bool, length(large_worlds))), f_large.worlds)
    s_ext_large = sprint(show, MIME("text/plain"), ext_large)
    @test occursin("Satisfied at: :w1, :w2, :w3, :w4, :w5, :w6, :w7, :w8, :w9, :w10, … (10 elided)", s_ext_large)
    @test sprint(show, ext_large) == "Extension(Bool[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])"

    # Valuation summaries accept the supported world/atom dictionary shapes.
    m_world_nested = Model(f1, BOOLEAN, Dict(:w1 => Dict("p" => true), :w2 => Dict("p" => false)))
    @test occursin("p: {:w1 => true, :w2 => false}", sprint(show, MIME("text/plain"), m_world_nested))
    m_pairs = Model(f1, BOOLEAN, Dict((:w1, "p") => true, ("q", :w2) => true, ("unused", :w1) => false))
    @test occursin("p: {:w1}", sprint(show, MIME("text/plain"), m_pairs))
    @test occursin("q: {:w2}", sprint(show, MIME("text/plain"), m_pairs))
    m_atom_map = Model(f1, BOOLEAN, Dict("p" => Dict(:w1 => true), "empty" => Dict(:ghost => true)))
    s_atom_map = sprint(show, MIME("text/plain"), m_atom_map)
    @test occursin("empty: {}", s_atom_map)
    @test occursin("p: {:w1}", s_atom_map)
    m_empty_set = Model(f1, BOOLEAN, Dict("empty" => Set{Symbol}()))
    @test occursin("empty: {}", sprint(show, MIME("text/plain"), m_empty_set))
    m_constant = Model(f1, BOOLEAN, Dict("p" => true))
    @test occursin("p: {}", sprint(show, MIME("text/plain"), m_constant))

    # Callable relation entries and large graded extensions exercise compact paths.
    f_callable_entry = Frame((:a, :b), Dict(:R => (w -> (:b,))); index=true)
    @test occursin("<callable>", sprint(show, MIME("text/plain"), f_callable_entry))
    m_callable_entry = Model(f_callable_entry, (a, w) -> true, BOOLEAN)
    @test occursin("<callable>", sprint(show, MIME("text/plain"), m_callable_entry))
    ext_g_large = Extension(fill(0.5, length(large_worlds)), large_worlds)
    @test occursin("… (10 elided)", sprint(show, MIME("text/plain"), ext_g_large))

    # Both terse and rich forms of finite algebras remain distinct.
    @test sprint(show, H4) == "FiniteFLewAlgebra{4}(bottom=⊥, top=⊤)"
    @test sprint(show, MIME("text/plain"), H4) isa String
    @test occursin("Order: ⊥ < α < β < γ < δ < ε < ζ < η < θ < ι < ⊤",
        sprint(show, MIME("text/plain"), Aletheia._chain_flew(11, :godel)))

    # Large quotient output elides classes after the first five.
    worlds_11 = tuple([Symbol("u", i) for i in 1:11]...)
    vals_11 = Dict("p$(i)" => Set([worlds_11[i]]) for i in 1:11)
    f_11 = Frame(worlds_11, Dict(:R => Dict()); index=true)
    q_11 = bisimulation_contraction(Model(f_11, BOOLEAN, vals_11))
    @test occursin("… (1 elided)", sprint(show, MIME("text/plain"), q_11))

    # Quotients with no collapse and complete collapse.
    q_none = bisimulation_contraction(m1)
    @test occursin("0% collapse ratio", sprint(show, MIME("text/plain"), q_none))
    @test sprint(show, q_none) == "BisimulationContraction(2 → 2 worlds)"
    f_same = Frame((:a, :b), Dict(:R => Dict()); index=true)
    m_same = Model(f_same, BOOLEAN, Dict("p" => Set{Symbol}()))
    q_all = bisimulation_contraction(m_same)
    s_q_all = sprint(show, MIME("text/plain"), q_all)
    @test occursin("BisimulationContraction (2 → 1 world, 50% collapse ratio)", s_q_all)
    @test occursin("Class 1: :a, :b", s_q_all)
    @test sprint(show, q_all) == "BisimulationContraction(2 → 1 worlds)"

    clauses_16 = ClauseSet([HornClause(Predicate(:p, (Variable(:z),))) for _ in 1:16])
    # ClauseSet canonicalization removes duplicates; use distinct predicates for elision.
    clauses_16 = ClauseSet([HornClause(Predicate(Symbol("p", i), (Variable(:z),))) for i in 1:16])
    @test occursin("… (6 elided)", sprint(show, MIME("text/plain"), clauses_16))

    # Empty ILP bodies and rich/terse substitution displays.
    @test sprint(show, MIME("text/plain"), hc2) == "p(x)"
    @test sprint(show, MIME("text/plain"), HornClause(nothing)) == "⊥"
    @test sprint(show, MIME("text/plain"), Substitution()) == "Substitution: {}"
    @test sprint(show, Substitution()) == "Substitution()"
    @test sprint(show, f1) == "Frame(2 worlds)"
    @test sprint(show, m1) == "Model(2 worlds, BooleanAlgebra())"

    # 6. Element-labelled algebra displays.  The carrier is a one-based UInt8
    # index; no display may present that index as if it were an element.
    @test sprint(show, MIME("text/plain"), G3) == join([
        "FiniteFLewAlgebra{3} (3 values, chain, bottom=⊥, top=⊤)",
        "  Order: ⊥ < α < ⊤",
        "",
        "  Meet (∧)      Join (∨)      Implication (→)",
        " ∧ │ ⊥ α ⊤     ∨ │ ⊥ α ⊤     → │ ⊥ α ⊤",
        "───┼──────    ───┼──────    ───┼──────",
        " ⊥ │ ⊥ ⊥ ⊥     ⊥ │ ⊥ α ⊤     ⊥ │ ⊤ ⊤ ⊤",
        " α │ ⊥ α α     α │ α α ⊤     α │ ⊥ ⊤ ⊤",
        " ⊤ │ ⊥ α ⊤     ⊤ │ ⊤ ⊤ ⊤     ⊤ │ ⊥ α ⊤",
    ], "\n")

    # H4 is not a chain, so its display says so instead of implying that the
    # carrier order ranks its elements.
    @test sprint(show, MIME("text/plain"), H4) == join([
        "FiniteFLewAlgebra{4} (4 values, not a chain, bottom=⊥, top=⊤)",
        "  Elements: ⊥, α, β, ⊤",
        "",
        "  Meet (∧)        Join (∨)        Implication (→)",
        " ∧ │ ⊥ α β ⊤     ∨ │ ⊥ α β ⊤     → │ ⊥ α β ⊤",
        "───┼────────    ───┼────────    ───┼────────",
        " ⊥ │ ⊥ ⊥ ⊥ ⊥     ⊥ │ ⊥ α β ⊤     ⊥ │ ⊤ ⊤ ⊤ ⊤",
        " α │ ⊥ α ⊥ α     α │ α α ⊤ ⊤     α │ β ⊤ β ⊤",
        " β │ ⊥ ⊥ β β     β │ β ⊤ β ⊤     β │ α α ⊤ ⊤",
        " ⊤ │ ⊥ α β ⊤     ⊤ │ ⊤ ⊤ ⊤ ⊤     ⊤ │ ⊥ α β ⊤",
    ], "\n")
    for algebra in (G3, G4, G5, G6, Ł3, Ł4, H4, H6, H6_1, H6_2, H6_3, H9, BooleanFLewAlgebra)
        rich = sprint(show, MIME("text/plain"), algebra)
        @test occursin("bottom=⊥, top=⊤", rich)
        @test occursin(occursin("not a chain", rich) ? "Elements: ⊥, " : "Order: ⊥ < ", rich)
    end
    @test occursin("not a chain", sprint(show, MIME("text/plain"), H9))
    @test occursin("chain", sprint(show, MIME("text/plain"), G6))
    @test Aletheia.truthlabel(1) == "⊤" && Aletheia.truthlabel(2) == "⊥" && Aletheia.truthlabel(3) == "α"
    @test Aletheia.truthlabel(H4, 4) == "β"
    # A carrier laid out the other way round still labels its own bottom and top.
    flipped = FiniteFLewAlgebra([1 2; 2 2], [1 1; 1 2], [1 1; 1 2], 1, 2)
    @test sprint(show, flipped) == "FiniteFLewAlgebra{2}(bottom=⊥, top=⊤)"
    @test Aletheia.truthlabel(flipped, 1) == "⊥" && Aletheia.truthlabel(flipped, 2) == "⊤"
    # Values outside the carrier fall back to their plain form rather than throwing.
    @test Aletheia._display_truth(G3, true) == "true"
    @test Aletheia._display_truth(nothing, 0.5) == "0.5"

    # Graded models and extensions report elements, not carrier indices.
    m_finite = Model(f1, G3, Dict("p" => Dict(:w1 => UInt8(3), :w2 => UInt8(1))))
    @test occursin("p: {:w1 => α, :w2 => ⊤}", sprint(show, MIME("text/plain"), m_finite))
    s_ext_finite = sprint(show, MIME("text/plain"), Extension(extension(p, m_finite), m_finite))
    @test occursin(":w1 => α", s_ext_finite)
    @test occursin(":w2 => ⊤", s_ext_finite)
    # A bare world tuple has no algebra to consult, so values print plainly.
    @test occursin(":w1 => 3", sprint(show, MIME("text/plain"), Extension(UInt8[3, 1], f1.worlds)))

    # 7. Colour is emitted only when the IO context reports it.
    coloured(value) = sprint(io -> show(IOContext(io, :color => true), MIME("text/plain"), value))
    for value in (G3, H4, f1, m1, ext_view, ext_g_view, q, cs, sub, ee, ie, pe, BOOLEAN, GodelAlgebra(3))
        @test !occursin('\e', sprint(show, MIME("text/plain"), value))
        @test occursin('\e', coloured(value))
    end

    # 8. `:limit => false` in the IO context disables every truncation.
    unlimited(value) = sprint(io -> show(IOContext(io, :limit => false), MIME("text/plain"), value))
    @test !occursin("elided", unlimited(f_large)) && occursin(":w20", unlimited(f_large))
    @test !occursin("elided", unlimited(m_large)) && occursin(":w20", unlimited(m_large))
    @test !occursin("elided", unlimited(ext_large)) && occursin(":w20", unlimited(ext_large))
    @test !occursin("elided", unlimited(ext_g_large))
    @test !occursin("elided", unlimited(q_11)) && occursin("Class 11", unlimited(q_11))
    @test !occursin("elided", unlimited(clauses_16)) && occursin("p9(z)", unlimited(clauses_16))
    @test !occursin("elided", unlimited(Aletheia._chain_flew(11, :godel)))

    # 9. Long relation edge lists and valuation world sets stay bounded.
    edges = Frame(large_worlds, Dict(:R => Dict(w => [w] for w in large_worlds)); index=true)
    @test occursin("… (10 elided)", sprint(show, MIME("text/plain"), edges))
    @test occursin(":w10 → :w10, … (10 elided)", sprint(show, MIME("text/plain"), edges))
    @test occursin("p: {:w1, :w2, :w3, :w4, :w5, :w6, :w7, :w8, :w9, :w10, … (10 elided)}",
        sprint(show, MIME("text/plain"), m_large))

    # 6. Display edge cases: singular forms, empty relations, and elision.
    f_single = Frame((:w1,), Dict(:R => Dict(:w1 => Symbol[])); index=true)
    @test sprint(show, f_single) == "Frame(1 world)"
    s_f_single = sprint(show, MIME("text/plain"), f_single)
    @test occursin("Frame (1 world, 1 relation)", s_f_single)
    @test occursin("(none)", s_f_single)

    f_multi_rel = Frame((:w1, :w2), Dict(:R => Dict(:w1 => [:w2]), :S => Dict(:w2 => [:w1])); index=true)
    @test occursin("Frame (2 worlds, 2 relations)", sprint(show, MIME("text/plain"), f_multi_rel))

    w20 = tuple([Symbol("w", i) for i in 1:20]...)
    f20 = Frame(w20, Dict(:R => Dict(:w1 => [:w2])); index=true)
    s_f20 = sprint(show, MIME("text/plain"), f20)
    @test occursin("Worlds (20): :w1, :w2, :w3, :w4, :w5, :w6, :w7, :w8, :w9, :w10, … (10 elided)", s_f20)
    @test occursin("Relations:\n    :R: :w1 → :w2", s_f20)

    m_single = Model(f_single, BOOLEAN, Dict("p" => Set([:w1])))
    @test occursin("Model (1 world, 1 relation, BooleanAlgebra())", sprint(show, MIME("text/plain"), m_single))
    m20 = Model(f20, BOOLEAN, Dict("p" => Set([:w1])))
    s_m20 = sprint(show, MIME("text/plain"), m20)
    @test occursin("Model (20 worlds, 1 relation, BooleanAlgebra())", s_m20)
    @test occursin("Valuation:\n    p: {:w1}", s_m20)
    m20_fn = Model(f20, (a, w) -> true, BOOLEAN)
    @test occursin("Valuation: <function>", sprint(show, MIME("text/plain"), m20_fn))

    ext_empty = Extension(BitVector([0, 0]), f1.worlds)
    s_ext_empty = sprint(show, MIME("text/plain"), ext_empty)
    @test occursin("Extension (0 of 2 worlds satisfy)", s_ext_empty)
    @test occursin("Satisfied at: (none)", s_ext_empty)
    @test occursin("Unsatisfied at: :w1, :w2", s_ext_empty)
    ext_full = Extension(BitVector([1, 1]), f1.worlds)
    s_ext_full = sprint(show, MIME("text/plain"), ext_full)
    @test occursin("Extension (2 of 2 worlds satisfy)", s_ext_full)
    @test occursin("Satisfied at: :w1, :w2", s_ext_full)
    @test occursin("Unsatisfied at: (none)", s_ext_full)
    ext_single = Extension(BitVector([1]), f_single.worlds)
    @test occursin("Extension (1 of 1 world satisfy)", sprint(show, MIME("text/plain"), ext_single))
    ext20_sat10 = Extension(BitVector([i <= 10 for i in 1:20]), w20)
    s_ext20_sat10 = sprint(show, MIME("text/plain"), ext20_sat10)
    @test occursin("Extension (10 of 20 worlds satisfy)", s_ext20_sat10)
    @test occursin("Satisfied at: :w1, :w2, :w3, :w4, :w5, :w6, :w7, :w8, :w9, :w10", s_ext20_sat10)
    ext20_sat0 = Extension(BitVector([0 for _ in 1:20]), w20)
    @test occursin("Satisfied at: (none)", sprint(show, MIME("text/plain"), ext20_sat0))

    ext_g_single = Extension(Float64[0.5], f_single.worlds)
    s_ext_g_single = sprint(show, MIME("text/plain"), ext_g_single)
    @test occursin("Extension (1 world)", s_ext_g_single)
    @test occursin(":w1 => 0.5", s_ext_g_single)
    ext_g20 = Extension(fill(0.7, 20), w20)
    s_ext_g20 = sprint(show, MIME("text/plain"), ext_g20)
    @test occursin("Extension (20 worlds)", s_ext_g20)
    @test occursin("… (10 elided)", s_ext_g20)


    # Quotient and ILP displays also handle complete/partial collapse and elision.
    q_0 = bisimulation_contraction(m1)
    @test occursin("0% collapse ratio", sprint(show, MIME("text/plain"), q_0))
    f_coll = Frame((:w1, :w2), Dict(:R => Dict()); index=true)
    m_coll = Model(f_coll, BOOLEAN, Dict("p" => Set([:w1, :w2])))
    @test occursin("50% collapse ratio", sprint(show, MIME("text/plain"), bisimulation_contraction(m_coll)))
    m20_diff = Model(f20, BOOLEAN, Dict("p$i" => Set([Symbol("w", i)]) for i in 1:20))
    @test occursin("Classes (20):", sprint(show, MIME("text/plain"), bisimulation_contraction(m20_diff)))
    @test occursin("… (10 elided)", sprint(show, MIME("text/plain"), bisimulation_contraction(m20_diff)))

    @test sprint(show, Substitution()) == "Substitution()"
    @test sprint(show, MIME("text/plain"), Substitution()) == "Substitution: {}"
    @test occursin("ClauseSet (1 clause)", sprint(show, MIME("text/plain"), ClauseSet([hc1])))
    hc_list = [HornClause(Predicate(Symbol("p", i), (x,))) for i in 1:20]
    s_cs20 = sprint(show, MIME("text/plain"), ClauseSet(hc_list))
    @test occursin("ClauseSet (20 clauses)", s_cs20)
    @test occursin("… (10 elided)", s_cs20)

end
