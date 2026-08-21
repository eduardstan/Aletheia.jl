module CompatibilityClient
using Aletheia.SoleLogics

function basic()
    p, q = Atom("p"), Atom("q")
    f = SyntaxBranch(∧, p, q)
    parsed = parseformula("¬p ∨ q")
    return p, q, f, parsed
end

function custom_parse()
    parseformula("p → q"; atom_parser=text -> Atom(Symbol(text)))
end
end

@testset "SoleLogics compatibility" begin
    @test Aletheia.SoleLogics isa Module
    @test !isdefined(Aletheia, :parseformula)
    @test !isdefined(Aletheia, :SyntaxTree)
    @test !(:SoleLogics in names(Aletheia, all=false))

    p, q, conjunction, parsed = CompatibilityClient.basic()
    @test p isa CompatibilityClient.Atom
    @test q isa CompatibilityClient.Atom
    @test conjunction isa Aletheia.Formula
    @test CompatibilityClient.token(conjunction).native === Aletheia.:∧
    @test CompatibilityClient.children(conjunction) == (p, q)
    # Children are a tuple-shaped lazy view and reuse canonical pool handles.
    @test CompatibilityClient.children(conjunction) isa Aletheia.SoleLogics._CompatChildren
    @test CompatibilityClient.children(conjunction)[1] === p
    childaccess(x) = CompatibilityClient.children(x)
    tokenaccess(x) = CompatibilityClient.token(x)
    valueaccess(x) = CompatibilityClient.value(x)
    childaccess(conjunction); tokenaccess(conjunction); valueaccess(p)
    @test @allocated(childaccess(conjunction)) == 0
    @test @allocated(tokenaccess(conjunction)) == 0
    @test @allocated(valueaccess(p)) == 0
    @test CompatibilityClient.SyntaxBranch(∧, p, q) === conjunction
    other_pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.:¬,
        Aletheia.:∧, Aletheia.:∨, Aletheia.:→)))
    other_q = Aletheia.SoleLogics.atom(other_pool, "q")
    cross_pool = CompatibilityClient.SyntaxBranch(∧, p, other_q)
    @test cross_pool isa Aletheia.Formula
    @test CompatibilityClient.syntaxstring(cross_pool) == "p ∧ q"
    @test cross_pool !== conjunction
    @test_throws ArgumentError CompatibilityClient.SyntaxBranch(∧, p)
    @test CompatibilityClient.value(p) == "p"
    @test CompatibilityClient.tree(conjunction) === conjunction
    @test CompatibilityClient.nchildren(p) == 0
    @test CompatibilityClient.nchildren(conjunction) == 2
    @test CompatibilityClient.arity(CompatibilityClient.token(conjunction)) == 2
    @test CompatibilityClient.syntaxstring(conjunction; threshold_digits=2) == "p ∧ q"
    @test CompatibilityClient.height(conjunction) == 1
    @test CompatibilityClient.atoms(conjunction) == [p, q]
    @test CompatibilityClient.leaves(conjunction) == [p, q]
    @test CompatibilityClient.formulas(conjunction) == [p, q, conjunction]
    @test CompatibilityClient.subformulas(conjunction) == [p, q, conjunction]
    @test [c.native for c in CompatibilityClient.connectives(conjunction)] == [Aletheia.:∧]
    @test CompatibilityClient.ntokens(conjunction) == 3
    @test CompatibilityClient.natoms(conjunction) == 2
    @test CompatibilityClient.nleaves(conjunction) == 2
    @test CompatibilityClient.nconnectives(conjunction) == 1
    @test CompatibilityClient.noperators(conjunction) == 1
    @test CompatibilityClient.conjuncts(conjunction) == [p, q]
    @test CompatibilityClient.disjuncts(parsed) == collect(CompatibilityClient.children(parsed))
    @test CompatibilityClient.grandchildren(conjunction) == (p, q)
    @test CompatibilityClient.nconjuncts(conjunction) == 2
    @test CompatibilityClient.syntaxstring(parsed) == "¬p ∨ q"
    @test CompatibilityClient.dual(Aletheia.:∧) === Aletheia.:∨
    @test CompatibilityClient.hasdual(Aletheia.:∧)
    @test CompatibilityClient.relation(Aletheia.Diamond(:G)) == :G
    @test CompatibilityClient.op(conjunction).native === Aletheia.:∧
    @test CompatibilityClient.token(p) === p
    @test CompatibilityClient.token(CompatibilityClient.⊤) === CompatibilityClient.⊤
    @test [c.native for c in CompatibilityClient.operators(conjunction)] == [Aletheia.:∧]
    @test CompatibilityClient.atom("r") isa CompatibilityClient.Atom
    compat_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((Aletheia.:∧,)))
    compat_p, compat_q = CompatibilityClient.atom(compat_pool, "s"), CompatibilityClient.atom(compat_pool, "t")
    @test compat_p isa CompatibilityClient.Atom
    @test CompatibilityClient.branch(compat_pool, Aletheia.:∧, compat_p, compat_q) isa Aletheia.Formula
    @test CompatibilityClient.branch(Aletheia.:∧, p, q) isa Aletheia.Formula
    @test CompatibilityClient.syntaxstring(Aletheia.:∧) == "∧"
    @test CompatibilityClient.syntaxstring(17) == "17"
    @test CompatibilityClient.value(CompatibilityClient.⊤)
    @test !CompatibilityClient.istop(17)
    @test !CompatibilityClient.isbot(17)
    @test CompatibilityClient.children(CompatibilityClient.⊤) == ()
    @test CompatibilityClient.arity(CompatibilityClient.⊤) == 0
    @test isempty(CompatibilityClient.truths(p))
    @test_throws ArgumentError CompatibilityClient.truths(CompatibilityClient.⊤)
    modal = CompatibilityClient.SyntaxBranch(CompatibilityClient.diamond(CompatibilityClient.IA_L), p)
    @test modal isa Aletheia.Formula
    @test CompatibilityClient.relation(CompatibilityClient.token(modal)) == CompatibilityClient.IA_L
    nested_modal = CompatibilityClient.SyntaxBranch(CompatibilityClient.diamond(CompatibilityClient.IA_L), conjunction)
    @test nested_modal isa Aletheia.Formula
    @test_throws ArgumentError CompatibilityClient.SyntaxBranch(CompatibilityClient.diamond(CompatibilityClient.IA_L))
    @test_throws ArgumentError CompatibilityClient.SyntaxBranch(Aletheia.:∧, 1)
    @test CompatibilityClient.Interval(1, 2) == Aletheia.Interval(1, 2)
    @test CompatibilityClient.Interval2D === Aletheia.Interval2D
    @test CompatibilityClient.Point1D(1) == Aletheia.Point(1)
    @test CompatibilityClient.FullDimensionalFrame === Aletheia.FullDimensionalFrame
    @test CompatibilityClient.allworlds(Aletheia.point_frame(1:2)) == [1, 2]
    world_frame = CompatibilityClient.FullDimensionalFrame((1,), CompatibilityClient.Interval; index=true)
    world = first(CompatibilityClient.allworlds(world_frame))
    model = CompatibilityClient.KripkeStructure(world_frame, Dict("p" => Set([world])))
    @test CompatibilityClient.check(p, model, world)
    @test CompatibilityClient.TruthDict(Dict("p" => Set([world]))) isa CompatibilityClient.Valuation
    @test CompatibilityClient.worldtype(model) <: CompatibilityClient.Interval
    @test_throws ArgumentError CompatibilityClient.worldtype(world_frame)
    @test CompatibilityClient.accessibles(world_frame, world, CompatibilityClient.IA_L) isa Vector
    @test CompatibilityClient.ManyValuedLogics.getdomain(CompatibilityClient.ManyValuedLogics.BooleanAlgebra()) == (false, true)
    @test CompatibilityClient.parseformula(CompatibilityClient.SyntaxTree, "⟨before⟩p", [CompatibilityClient.diamond(CompatibilityClient.IA_L)]) isa Aletheia.Formula
    @test CompatibilityClient.parseformula(CompatibilityClient.SyntaxTree, "p") isa Aletheia.Formula
    @test CompatibilityClient.parseformula("⟨before⟩p", [CompatibilityClient.diamond(CompatibilityClient.IA_L)]) isa Aletheia.Formula
    @test CompatibilityClient.custom_parse() isa Aletheia.Formula
    @test CompatibilityClient.dnf(parsed) isa Aletheia.Formula
    @test CompatibilityClient.cnf(parsed) isa Aletheia.Formula

    @test CompatibilityClient.TOP isa CompatibilityClient.Truth
    @test CompatibilityClient.istop(CompatibilityClient.⊤)
    @test CompatibilityClient.isbot(CompatibilityClient.⊥)
    @test_throws ArgumentError CompatibilityClient.Atom(CompatibilityClient.⊤)
    @test_throws ArgumentError CompatibilityClient.parseformula("⊤"; atom_parser=_ -> CompatibilityClient.⊤)
    @test_throws ArgumentError CompatibilityClient.collatetruth(CompatibilityClient.:∧, (CompatibilityClient.⊤, CompatibilityClient.⊥))
    @test_throws ArgumentError CompatibilityClient.LeftmostConjunctiveForm([p, q])
    @test_throws ArgumentError CompatibilityClient.ispos(nothing)
    @test_throws ArgumentError CompatibilityClient.RCC5Relations()
    @test_throws ArgumentError CompatibilityClient.alphabet(nothing)
    @test_throws ArgumentError CompatibilityClient.feature(nothing)
    @test_throws ArgumentError CompatibilityClient.condition(nothing)
    @test_throws ArgumentError CompatibilityClient.threshold(nothing)
    @test_throws ArgumentError CompatibilityClient.normalize(parsed)
    @test_throws ArgumentError CompatibilityClient.sample(parsed)
    @test !(CompatibilityClient.ManyValuedLogics.G3 isa CompatibilityClient.ManyValuedLogics.FiniteTruth)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.G3()
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.FiniteTruth()
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.getdomain(nothing)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.booleanalgebra()
    @test CompatibilityClient.IARelations == (Aletheia.IA_A, Aletheia.IA_L, Aletheia.IA_B, Aletheia.IA_E, Aletheia.IA_D, Aletheia.IA_O, Aletheia.IA_Ai, Aletheia.IA_Li, Aletheia.IA_Bi, Aletheia.IA_Ei, Aletheia.IA_Di, Aletheia.IA_Oi)
    @test CompatibilityClient.box(CompatibilityClient.IA_L) isa Aletheia.Box
    @test CompatibilityClient.name(Aletheia.:∧) == :∧
    @test sprint(show, CompatibilityClient.RCC5Relations) == "unsupported SoleLogics.RCC5Relations"
    @test_throws ArgumentError CompatibilityClient.Literal()
    @test_throws ArgumentError CompatibilityClient.Literal(p)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.precedeq(1, 2)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.succeedeq(1, 2)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.maximalmembers((1, 2))
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.minimalmembers((1, 2))
    @test sprint(show, CompatibilityClient.ManyValuedLogics.G3) == "unsupported SoleLogics.ManyValuedLogics.G3"
end


module DistinctUnsupportedClient
using Aletheia.SoleLogics
marker_method(::typeof(RCC5Relations)) = :rcc5
marker_method(::typeof(AbstractInterpretationSet)) = :interpretation
end

@testset "consumer-facing Atom and relation aliases" begin
    @test CompatibilityClient.Atom isa Type
    atom_value = CompatibilityClient.Atom(:r)
    @test atom_value isa CompatibilityClient.Atom
    @test CompatibilityClient.value(atom_value) == :r
    @test typeof(CompatibilityClient.RCC5Relations) !=
        typeof(CompatibilityClient.AbstractInterpretationSet)
    @test DistinctUnsupportedClient.marker_method(CompatibilityClient.RCC5Relations) == :rcc5
    @test DistinctUnsupportedClient.marker_method(CompatibilityClient.AbstractInterpretationSet) == :interpretation
    for (marker, name) in ((CompatibilityClient.RCC5Relations, :RCC5Relations),
            (CompatibilityClient.AbstractInterpretationSet, :AbstractInterpretationSet))
        error = try
            marker()
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin(string(name), sprint(showerror, error))
    end

    # SoleLogics defines HS_* as the corresponding IA_* aliases.
    @test (CompatibilityClient.HS_A, CompatibilityClient.HS_L,
        CompatibilityClient.HS_B, CompatibilityClient.HS_E, CompatibilityClient.HS_D,
        CompatibilityClient.HS_O, CompatibilityClient.HS_Ai, CompatibilityClient.HS_Li,
        CompatibilityClient.HS_Bi, CompatibilityClient.HS_Ei, CompatibilityClient.HS_Di,
        CompatibilityClient.HS_Oi) ===
        (Aletheia.IA_A, Aletheia.IA_L, Aletheia.IA_B, Aletheia.IA_E, Aletheia.IA_D,
        Aletheia.IA_O, Aletheia.IA_Ai, Aletheia.IA_Li, Aletheia.IA_Bi, Aletheia.IA_Ei,
        Aletheia.IA_Di, Aletheia.IA_Oi)

    # SoleLogics defines LRCC8_Rec_* as these Topo_* aliases.
    @test (CompatibilityClient.LRCC8_Rec_DC, CompatibilityClient.LRCC8_Rec_EC,
        CompatibilityClient.LRCC8_Rec_PO, CompatibilityClient.LRCC8_Rec_TPP,
        CompatibilityClient.LRCC8_Rec_TPPi, CompatibilityClient.LRCC8_Rec_NTPP,
        CompatibilityClient.LRCC8_Rec_NTPPi) ===
        (Aletheia.Topo_DC, Aletheia.Topo_EC, Aletheia.Topo_PO, Aletheia.Topo_TPP,
        Aletheia.Topo_TPPi, Aletheia.Topo_NTPP, Aletheia.Topo_NTPPi)

    # SoleLogics defines LTLFP_F = GreaterRel and LTLFP_P = LesserRel.
    @test CompatibilityClient.LTLFP_F === Aletheia.GREATER
    @test CompatibilityClient.LTLFP_P === Aletheia.LESSER

    # Compass names now follow Aletheia's landed 2D point relation constants.
    @test (CompatibilityClient.CL_N, CompatibilityClient.CL_S,
        CompatibilityClient.CL_E, CompatibilityClient.CL_W,
        CompatibilityClient.CL_NE, CompatibilityClient.CL_NW,
        CompatibilityClient.CL_SE, CompatibilityClient.CL_SW) ===
        (Aletheia.CL_N, Aletheia.CL_S, Aletheia.CL_E, Aletheia.CL_W,
        Aletheia.CL_NE, Aletheia.CL_NW, Aletheia.CL_SE, Aletheia.CL_SW)
end
