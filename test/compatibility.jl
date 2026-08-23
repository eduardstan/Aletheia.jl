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
    @test CompatibilityClient.syntaxstring(CompatibilityClient.⊤) == "⊤"
    @test sprint(show, CompatibilityClient.⊥) == "⊥"
    @test !CompatibilityClient.istop(17)
    @test !CompatibilityClient.isbot(17)
    @test CompatibilityClient.children(CompatibilityClient.⊤) == ()
    @test CompatibilityClient.arity(CompatibilityClient.⊤) == 0
    @test isempty(CompatibilityClient.truths(p))
    @test CompatibilityClient.truths(CompatibilityClient.⊤) == [CompatibilityClient.⊤]
    @test CompatibilityClient.leaves(CompatibilityClient.⊤) == [CompatibilityClient.⊤]
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
    truth_formula = CompatibilityClient.:∧(CompatibilityClient.⊤, p)
    @test CompatibilityClient.check(truth_formula, model, world)
    @test CompatibilityClient.interpret(CompatibilityClient.⊥, model, world) === false
    MV = CompatibilityClient.ManyValuedLogics
    @test CompatibilityClient.check(MV.FiniteTruth(1), model, world) === true
    @test CompatibilityClient.check(MV.FiniteTruth(2), model, world) === false
    finite_frame = Aletheia.Frame((1,), Dict())
    finite_model = Aletheia.Model(finite_frame, Aletheia.G4, Dict("p" => UInt8(3)))
    finite_formula = CompatibilityClient.:∧(MV.α, CompatibilityClient.Atom("p"))
    @test CompatibilityClient.check(finite_formula, finite_model, 1) == UInt8(3)
    @test CompatibilityClient.check(MV.β, finite_model, 1) == UInt8(4)
    godel_model = Aletheia.Model(finite_frame, Aletheia.GodelAlgebra(4), Dict("p" => 1.0))
    @test_throws ArgumentError CompatibilityClient.check(MV.α, godel_model, 1)
    @test Set(CompatibilityClient.collateworlds(world_frame,
        CompatibilityClient.token(conjunction), (Set([world]), Set([world])))) == Set([world])
    grounded = CompatibilityClient.SyntaxBranch(
        CompatibilityClient.diamond(CompatibilityClient.globalrel), p)
    @test CompatibilityClient.isgrounded(grounded)
    @test CompatibilityClient.TruthDict(Dict("p" => Set([world]))) isa CompatibilityClient.Valuation
    @test CompatibilityClient.worldtype(model) <: CompatibilityClient.Interval
    @test_throws ArgumentError CompatibilityClient.worldtype(world_frame)
    @test !(CompatibilityClient.accessibles(world_frame, world, CompatibilityClient.IA_L) isa Vector)
    @test CompatibilityClient.ManyValuedLogics.getdomain(CompatibilityClient.ManyValuedLogics.BooleanAlgebra()) == (false, true)
    @test CompatibilityClient.ManyValuedLogics.getdomain(CompatibilityClient.ManyValuedLogics.G4) ==
        (CompatibilityClient.ManyValuedLogics.FiniteTruth(1),
         CompatibilityClient.ManyValuedLogics.FiniteTruth(2),
         CompatibilityClient.ManyValuedLogics.FiniteTruth(3),
         CompatibilityClient.ManyValuedLogics.FiniteTruth(4))
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
    @test_throws "truth values are semantic values" CompatibilityClient.Atom(CompatibilityClient.⊤)
    truth_first = CompatibilityClient.SyntaxBranch(CompatibilityClient.:∧,
        CompatibilityClient.⊤, p)
    @test CompatibilityClient.nchildren(truth_first) == 2
    @test CompatibilityClient.children(truth_first)[2] == p
    @test CompatibilityClient.SyntaxBranch(CompatibilityClient.:¬,
        CompatibilityClient.⊤) isa Aletheia.Formula
    @test CompatibilityClient.SyntaxBranch(CompatibilityClient.:¬, CompatibilityClient.⊤) ==
        CompatibilityClient.SyntaxBranch(CompatibilityClient.:¬, CompatibilityClient.⊤)
    @test CompatibilityClient.SyntaxBranch(CompatibilityClient.:∧, CompatibilityClient.⊤,
            CompatibilityClient.⊥) ==
        CompatibilityClient.SyntaxBranch(CompatibilityClient.:∧, CompatibilityClient.⊤,
            CompatibilityClient.⊥)
    @test_throws ArgumentError CompatibilityClient.parseformula("⊤"; atom_parser=_ -> CompatibilityClient.⊤)
    @test_throws ArgumentError CompatibilityClient.collatetruth(CompatibilityClient.:∧, (CompatibilityClient.⊤, CompatibilityClient.⊥))
    @test_throws ArgumentError CompatibilityClient.LeftmostConjunctiveForm([p, q])
    @test_throws ArgumentError CompatibilityClient.ispos(nothing)
    @test_throws ArgumentError CompatibilityClient.alphabet(nothing)
    @test_throws ArgumentError CompatibilityClient.feature(nothing)
    @test_throws ArgumentError CompatibilityClient.condition(nothing)
    @test_throws ArgumentError CompatibilityClient.threshold(nothing)
    @test_throws ArgumentError CompatibilityClient.normalize(parsed)
    @test_throws ArgumentError CompatibilityClient.sample(parsed)
    MV = CompatibilityClient.ManyValuedLogics
    @test MV.G3 isa MV.FiniteFLewAlgebra
    @test MV.booleanalgebra isa MV.FiniteFLewAlgebra
    @test MV.FiniteTruth(1).index == UInt8(1)
    @test MV.FiniteTruth(UInt8(2)) == convert(MV.FiniteTruth, 2)
    @test convert(UInt8, MV.α) == UInt8(3)
    @test convert(MV.FiniteTruth, CompatibilityClient.⊤) == MV.FiniteTruth(1)
    @test convert(MV.FiniteTruth, 'α') == MV.α
    @test convert(MV.FiniteTruth, '⊤') == MV.FiniteTruth(1)
    @test convert(MV.FiniteTruth, "β") == MV.β
    @test sprint(show, MV.FiniteTruth(1)) == "⊤"
    @test sprint(show, MV.FiniteTruth(2)) == "⊥"
    @test sprint(show, MV.α) == "α"
    @test MV.syntaxstring(MV.α) == 'α'
    @test CompatibilityClient.istop(MV.FiniteTruth(1)) && CompatibilityClient.isbot(MV.FiniteTruth(2))
    @test MV.G4.monoid(MV.α, MV.β) == MV.α
    @test MV.G4.implication(MV.α, MV.β) == MV.FiniteTruth(1)
    @test MV.G4.join[MV.α, MV.α] == MV.G4.join(MV.α, MV.α)
    @test CompatibilityClient.token(CompatibilityClient.:∧(p, p)) in MV.BASE_MANY_VALUED_CONNECTIVES
    @test MV.precedeq(Aletheia.G4, MV.α, MV.β)
    @test MV.maximalmembers(Aletheia.H4, MV.α) == [MV.β]
    @test MV.precedeq(MV.G4, MV.α, MV.β)
    @test MV.succeedeq(MV.G4, MV.β, MV.α)
    @test MV.precedes(MV.G4, MV.α, MV.β)
    @test MV.succeedeq(MV.G4, MV.α, MV.α)
    @test MV.succeedes(MV.G4, MV.β, MV.α)
    @test MV.maximalmembers(MV.H4, MV.FiniteTruth(2)) == MV.FiniteTruth[]
    @test MV.minimalmembers(MV.H4, MV.FiniteTruth(1)) == MV.FiniteTruth[]
    @test MV.maximalmembers(MV.H4, MV.α) == [MV.β]
    @test MV.minimalmembers(MV.H4, MV.α) == [MV.β]
    @test MV.maximalmembers(MV.G4, MV.α) == [MV.FiniteTruth(2)]
    @test MV.minimalmembers(MV.G4, MV.α) == [MV.β]
    @test MV.BASE_MANY_VALUED_CONNECTIVES == [CompatibilityClient.:∨,
        CompatibilityClient.:∧, CompatibilityClient.:→]
    @test_throws MethodError MV.FiniteTruth()
    @test_throws ErrorException MV.FiniteTruth(0)
    @test_throws ArgumentError MV.FiniteTruth(-1)
    @test_throws ArgumentError MV.FiniteTruth(256)
    @test_throws ArgumentError MV.getdomain(nothing)
    @test_throws MethodError MV.booleanalgebra()
    @test CompatibilityClient.IARelations == (Aletheia.IA_A, Aletheia.IA_L, Aletheia.IA_B, Aletheia.IA_E, Aletheia.IA_D, Aletheia.IA_O, Aletheia.IA_Ai, Aletheia.IA_Li, Aletheia.IA_Bi, Aletheia.IA_Ei, Aletheia.IA_Di, Aletheia.IA_Oi)
    @test CompatibilityClient.box(CompatibilityClient.IA_L) isa Aletheia.Box
    @test CompatibilityClient.name(Aletheia.:∧) == :∧
    @test CompatibilityClient.RCC5Relations == Aletheia.RCC5Relations
    @test CompatibilityClient.IA3Relations == Aletheia.IA3Relations
    @test CompatibilityClient.IA7Relations == Aletheia.IA7Relations
    @test_throws ArgumentError CompatibilityClient.Literal()
    @test_throws ArgumentError CompatibilityClient.Literal(p)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.precedeq(1, 2)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.succeedeq(1, 2)
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.maximalmembers((1, 2))
    @test_throws ArgumentError CompatibilityClient.ManyValuedLogics.minimalmembers((1, 2))
    @test sprint(show, MV.G3) == string(typeof(MV.G3))
    g3_show = sprint(show, MIME"text/plain"(), MV.G3)
    @test occursin("Domain: " * string(MV.getdomain(MV.G3)), g3_show)
    @test occursin("Bot: " * sprint(show, MV.G3.bot), g3_show)
    @test occursin("Top: " * sprint(show, MV.G3.top), g3_show)
    @test occursin("Join: " * string(MV.G3.join.table), g3_show)
    @test_throws ArgumentError MV.FiniteFLewAlgebra{3}(MV.G4.join, MV.G4.meet, MV.G4.monoid, 2, 1)
end


@testset "many-valued compatibility boundary" begin
    MV = CompatibilityClient.ManyValuedLogics
    join_table = [1 1; 1 2]
    meet_table = [1 2; 2 2]
    direct = MV.FiniteFLewAlgebra(join_table, meet_table, meet_table, 2, 1)
    @test direct isa MV.FiniteFLewAlgebra{2}
    @test direct.native isa Aletheia.FiniteFLewAlgebra{2}
    @test MV.getdomain(direct) == (MV.FiniteTruth(1), MV.FiniteTruth(2))
    @test MV.getdomain(direct.native) == MV.getdomain(direct)
    @test MV.getdomain(Aletheia.G4) == MV.getdomain(MV.G4)
    wrapped_ops = MV.FiniteFLewAlgebra{2}(direct.join, direct.meet, direct.monoid, 2, 1)
    @test wrapped_ops.monoid(MV.FiniteTruth(1), MV.FiniteTruth(2)) == MV.FiniteTruth(2)
    flat_join = [1, 1, 1, 2]
    flat_meet = [1, 2, 2, 2]
    flat = MV.FiniteFLewAlgebra(flat_join, flat_meet, flat_meet, 2, 1)
    @test flat isa MV.FiniteFLewAlgebra{2}
    operation(table) = (left, right) -> MV.FiniteTruth(table[Int(left.index), Int(right.index)])
    callable = MV.FiniteFLewAlgebra{2}(operation(join_table), operation(meet_table),
        operation(meet_table), MV.FiniteTruth(2), MV.FiniteTruth(1))
    @test callable.monoid(MV.FiniteTruth(2), MV.FiniteTruth(1)) == MV.FiniteTruth(2)
    @test MV.FiniteFLewAlgebra(Aletheia.BooleanFLewAlgebra) isa MV.FiniteFLewAlgebra
    @test_throws ArgumentError MV.FiniteFLewAlgebra([1, 2, 3], join_table, meet_table, 2, 1)
    @test_throws ArgumentError MV.FiniteFLewAlgebra{2}(:bad, join_table, meet_table, 2, 1)
    @test_throws ArgumentError MV.FiniteFLewAlgebra{2}([1, 2, 3], join_table, meet_table, 2, 1)
    @test_throws ArgumentError MV.FiniteFLewAlgebra(join_table, [1, 2, 3], meet_table, 2, 1)
    @test_throws ArgumentError MV.FiniteFLewAlgebra{256}(join_table, meet_table, meet_table, 2, 1)
    @test_throws ArgumentError MV.FiniteFLewAlgebra((x, y) -> x, join_table, meet_table, 2, 1)
    @test_throws ErrorException convert(MV.FiniteTruth, 'x')
    @test_throws ErrorException convert(MV.FiniteTruth, "xy")
end


module DistinctUnsupportedClient
using Aletheia.SoleLogics
marker_method(::typeof(AbstractInterpretationSet)) = :interpretation
end

@testset "compatibility wrappers stay concrete during traversal" begin
    p, q, conjunction, _ = CompatibilityClient.basic()
    function walk_compatibility(formula)
        total = 0
        for _ in 1:1000
            for child in CompatibilityClient.children(formula)
                total += CompatibilityClient.nchildren(child)
            end
        end
        total
    end
    walk_compatibility(conjunction)
    @test @inferred(CompatibilityClient.children(conjunction)) isa
        Aletheia.SoleLogics._CompatChildren
    @test @allocated(walk_compatibility(conjunction)) == 0
    CompatibilityClient.Branch(CompatibilityClient.:∧, p, q)
    @test @allocated(CompatibilityClient.Branch(CompatibilityClient.:∧, p, q)) < 4096
    @test CompatibilityClient.:¬(p) isa Aletheia.Formula
    @test CompatibilityClient.:¬(p) === CompatibilityClient.:¬(p)
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, (p, q)) isa Aletheia.Formula
    @test Aletheia.SoleLogics._compat_branch(Aletheia.:∧, (p, q)) isa Aletheia.Formula
    modal_connective = Aletheia.Diamond(:coverage)
    modal_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((Aletheia.:∧, modal_connective)))
    modal_atom = CompatibilityClient.atom(modal_pool, "modal")
    @test Aletheia.SoleLogics._compat_branch(modal_connective, modal_atom) isa Aletheia.Formula
    constant_formula = CompatibilityClient.:→(p, CompatibilityClient.⊥)
    @test constant_formula isa Aletheia.Formula
    @test CompatibilityClient.token(first(collect(CompatibilityClient.children(constant_formula)))) isa CompatibilityClient.Atom
    @test CompatibilityClient.token(collect(CompatibilityClient.children(constant_formula))[2]) === CompatibilityClient.⊥
    @test CompatibilityClient.truths(constant_formula) == [CompatibilityClient.⊥]
    @test CompatibilityClient.atoms(constant_formula) == [p]
    @test CompatibilityClient.leaves(constant_formula) == [p, CompatibilityClient.⊥]
    @test CompatibilityClient.nleaves(constant_formula) == 2

    # Exercise the legacy/native pool merge path and both cached tree walks.
    native_pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.:∧,)))
    native_atom = Aletheia.atom(native_pool, "native")
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, native_atom, p) isa Aletheia.Formula
    merged = CompatibilityClient.Branch(CompatibilityClient.:∧, p, native_atom)
    @test merged isa Aletheia.Formula
    other_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((Aletheia.:∧,)))
    other_atom = CompatibilityClient.atom(other_pool, "other")
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, p, other_atom) isa Aletheia.Formula
    native_branch = Aletheia.branch(native_pool, Aletheia.:∧, native_atom, native_atom)
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, p, native_branch) isa Aletheia.Formula
    @test_throws MethodError CompatibilityClient.Branch(CompatibilityClient.:∧, p, 1)
    CompatibilityClient.formulas(merged)
    @test CompatibilityClient.formulas(merged) === CompatibilityClient.formulas(merged)
    CompatibilityClient.subformulas(merged)
    @test CompatibilityClient.subformulas(merged) === CompatibilityClient.subformulas(merged)
end

@testset "consumer-facing Atom and relation aliases" begin
    @test CompatibilityClient.Atom isa Type
    atom_value = CompatibilityClient.Atom(:r)
    @test atom_value isa CompatibilityClient.Atom
    @test CompatibilityClient.value(atom_value) == :r
    @test DistinctUnsupportedClient.marker_method(CompatibilityClient.AbstractInterpretationSet) == :interpretation
    for (marker, name) in ((CompatibilityClient.AbstractInterpretationSet, :AbstractInterpretationSet),)
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
