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
    @test p isa Aletheia.Atom
    @test q isa Aletheia.Atom
    @test conjunction isa Aletheia.Branch
    @test CompatibilityClient.token(conjunction) === Aletheia.:∧
    @test CompatibilityClient.children(conjunction) == (p, q)
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
    @test CompatibilityClient.connectives(conjunction) == [Aletheia.:∧]
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
    @test CompatibilityClient.op(conjunction) === Aletheia.:∧
    @test CompatibilityClient.token(p) === p
    @test CompatibilityClient.token(CompatibilityClient.⊤) === CompatibilityClient.⊤
    @test CompatibilityClient.operators(conjunction) == [Aletheia.:∧]
    @test CompatibilityClient.atom("r") isa Aletheia.Atom
    compat_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((Aletheia.:∧,)))
    compat_p, compat_q = CompatibilityClient.atom(compat_pool, "s"), CompatibilityClient.atom(compat_pool, "t")
    @test compat_p isa Aletheia.Atom
    @test CompatibilityClient.branch(compat_pool, Aletheia.:∧, compat_p, compat_q) isa Aletheia.Branch
    @test CompatibilityClient.branch(Aletheia.:∧, p, q) isa Aletheia.Branch
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
    @test modal isa Aletheia.Branch
    @test CompatibilityClient.relation(CompatibilityClient.token(modal)) == CompatibilityClient.IA_L
    nested_modal = CompatibilityClient.SyntaxBranch(CompatibilityClient.diamond(CompatibilityClient.IA_L), conjunction)
    @test nested_modal isa Aletheia.Branch
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
