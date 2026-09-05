module CompatibilityClient
using AletheiaSole.SoleLogics

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
    @test AletheiaSole.SoleLogics isa Module
    @test !isdefined(Aletheia, :parseformula)
    @test !isdefined(Aletheia, :SyntaxTree)
    @test :SoleLogics in names(AletheiaSole, all=false)

    p, q, conjunction, parsed = CompatibilityClient.basic()
    @test p isa CompatibilityClient.Atom
    @test q isa CompatibilityClient.Atom
    @test conjunction isa AletheiaSole.Formula
    @test CompatibilityClient.token(conjunction).native === AletheiaSole.:∧
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
    @test [c.native for c in CompatibilityClient.connectives(conjunction)] == [AletheiaSole.:∧]
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
    @test CompatibilityClient.dual(AletheiaSole.:∧) === AletheiaSole.:∨
    @test CompatibilityClient.hasdual(AletheiaSole.:∧)
    @test CompatibilityClient.relation(AletheiaSole.Diamond(:G)) == :G
    @test CompatibilityClient.op(conjunction).native === AletheiaSole.:∧
    @test CompatibilityClient.token(p) === p
    @test CompatibilityClient.token(CompatibilityClient.⊤) === CompatibilityClient.⊤
    @test [c.native for c in CompatibilityClient.operators(conjunction)] == [AletheiaSole.:∧]
    @test CompatibilityClient.atom("r") isa CompatibilityClient.Atom
    compat_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((AletheiaSole.:∧,)))
    compat_p, compat_q = CompatibilityClient.atom(compat_pool, "s"), CompatibilityClient.atom(compat_pool, "t")
    @test compat_p isa CompatibilityClient.Atom
    @test CompatibilityClient.branch(compat_pool, AletheiaSole.:∧, compat_p, compat_q) isa AletheiaSole.Formula
    @test CompatibilityClient.branch(AletheiaSole.:∧, p, q) isa AletheiaSole.Formula
    @test CompatibilityClient.syntaxstring(AletheiaSole.:∧) == "∧"
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
    @test modal isa AletheiaSole.Formula
    @test CompatibilityClient.relation(CompatibilityClient.token(modal)) == CompatibilityClient.IA_L
    nested_modal = CompatibilityClient.SyntaxBranch(CompatibilityClient.diamond(CompatibilityClient.IA_L), conjunction)
    @test nested_modal isa AletheiaSole.Formula
    @test_throws ArgumentError CompatibilityClient.SyntaxBranch(CompatibilityClient.diamond(CompatibilityClient.IA_L))
    @test_throws ArgumentError CompatibilityClient.SyntaxBranch(AletheiaSole.:∧, 1)
    @test CompatibilityClient.Interval(1, 2) == AletheiaSole.Interval(1, 2)
    @test CompatibilityClient.Interval2D === AletheiaCore.Interval2D
    @test CompatibilityClient.Point1D(1) == AletheiaSole.Point(1)
    @test CompatibilityClient.FullDimensionalFrame === AletheiaCore.FullDimensionalFrame
    @test CompatibilityClient.allworlds(AletheiaSole.point_frame(1:2)) == [1, 2]
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
    finite_frame = AletheiaSole.Frame((1,), Dict())
    finite_model = AletheiaSole.Model(finite_frame, AletheiaSole.G4, Dict("p" => UInt8(3)))
    finite_formula = CompatibilityClient.:∧(MV.α, CompatibilityClient.Atom("p"))
    @test CompatibilityClient.check(finite_formula, finite_model, 1) == UInt8(3)
    @test CompatibilityClient.check(MV.β, finite_model, 1) == UInt8(4)
    godel_model = AletheiaSole.Model(finite_frame, AletheiaSole.GodelAlgebra(4), Dict("p" => 1.0))
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
    @test CompatibilityClient.parseformula(CompatibilityClient.SyntaxTree, "⟨before⟩p", [CompatibilityClient.diamond(CompatibilityClient.IA_L)]) isa AletheiaSole.Formula
    @test CompatibilityClient.parseformula(CompatibilityClient.SyntaxTree, "p") isa AletheiaSole.Formula
    @test CompatibilityClient.parseformula("⟨before⟩p", [CompatibilityClient.diamond(CompatibilityClient.IA_L)]) isa AletheiaSole.Formula
    @test CompatibilityClient.custom_parse() isa AletheiaSole.Formula
    @test CompatibilityClient.dnf(parsed) isa AletheiaSole.Formula
    @test CompatibilityClient.cnf(parsed) isa AletheiaSole.Formula

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
        CompatibilityClient.⊤) isa AletheiaSole.Formula
    @test CompatibilityClient.SyntaxBranch(CompatibilityClient.:¬, CompatibilityClient.⊤) ==
        CompatibilityClient.SyntaxBranch(CompatibilityClient.:¬, CompatibilityClient.⊤)
    @test CompatibilityClient.SyntaxBranch(CompatibilityClient.:∧, CompatibilityClient.⊤,
            CompatibilityClient.⊥) ==
        CompatibilityClient.SyntaxBranch(CompatibilityClient.:∧, CompatibilityClient.⊤,
            CompatibilityClient.⊥)
    @test_throws ArgumentError CompatibilityClient.parseformula("⊤"; atom_parser=_ -> CompatibilityClient.⊤)
    @test_throws ArgumentError CompatibilityClient.collatetruth(CompatibilityClient.:∧, (CompatibilityClient.⊤, CompatibilityClient.⊥))
    @test_throws MethodError CompatibilityClient.ispos(nothing)
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
    @test MV.precedeq(AletheiaSole.G4, MV.α, MV.β)
    @test MV.maximalmembers(AletheiaSole.H4, MV.α) == [MV.β]
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
    @test CompatibilityClient.IARelations == (AletheiaCore.IA_A, AletheiaCore.IA_L, AletheiaCore.IA_B, AletheiaCore.IA_E, AletheiaCore.IA_D, AletheiaCore.IA_O, AletheiaCore.IA_Ai, AletheiaCore.IA_Li, AletheiaCore.IA_Bi, AletheiaCore.IA_Ei, AletheiaCore.IA_Di, AletheiaCore.IA_Oi)
    @test CompatibilityClient.box(CompatibilityClient.IA_L) isa AletheiaSole.Box
    @test CompatibilityClient.name(AletheiaSole.:∧) == :∧
    @test CompatibilityClient.RCC5Relations == (AletheiaSole.DR, AletheiaSole.PO, AletheiaSole.PPi, AletheiaSole.PP)
    @test CompatibilityClient.IA3Relations == AletheiaCore.IA3Relations
    @test CompatibilityClient.IA7Relations == AletheiaCore.IA7Relations
    @test CompatibilityClient.Topo_PP === AletheiaSole.PPi
    @test CompatibilityClient.Topo_PPi === AletheiaSole.PP
    @test CompatibilityClient.Point2DRelations == AletheiaCore.POINT2D_RELATIONS
    @test_throws MethodError CompatibilityClient.Literal()
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
    # The boundary view keeps SoleLogics' payload but follows Aletheia's
    # presentation conventions: plain text without colour, colour with it.
    @test !occursin('\e', g3_show)
    @test occursin('\e', sprint(io -> show(IOContext(io, :color => true), MIME"text/plain"(), MV.G3)))
    big = MV.FiniteFLewAlgebra(AletheiaCore._chain_flew(11, :godel))
    @test occursin("Join: 11×11 carrier table", sprint(show, MIME"text/plain"(), big))
    @test occursin("Join: " * string(big.join.table),
        sprint(io -> show(IOContext(io, :limit => false), MIME"text/plain"(), big)))
end


@testset "many-valued compatibility boundary" begin
    MV = CompatibilityClient.ManyValuedLogics
    join_table = [1 1; 1 2]
    meet_table = [1 2; 2 2]
    direct = MV.FiniteFLewAlgebra(join_table, meet_table, meet_table, 2, 1)
    @test direct isa MV.FiniteFLewAlgebra{2}
    @test direct.native isa AletheiaSole.FiniteFLewAlgebra{2}
    @test MV.getdomain(direct) == (MV.FiniteTruth(1), MV.FiniteTruth(2))
    @test MV.getdomain(direct.native) == MV.getdomain(direct)
    @test MV.getdomain(AletheiaSole.G4) == MV.getdomain(MV.G4)
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
    @test MV.FiniteFLewAlgebra(AletheiaSole.BooleanFLewAlgebra) isa MV.FiniteFLewAlgebra
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
using AletheiaSole.SoleLogics
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
        AletheiaSole.SoleLogics._CompatChildren
    @test @allocated(walk_compatibility(conjunction)) == 0
    CompatibilityClient.Branch(CompatibilityClient.:∧, p, q)
    @test @allocated(CompatibilityClient.Branch(CompatibilityClient.:∧, p, q)) < 4096
    @test CompatibilityClient.:¬(p) isa AletheiaSole.Formula
    @test CompatibilityClient.:¬(p) === CompatibilityClient.:¬(p)
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, (p, q)) isa AletheiaSole.Formula
    @test AletheiaSole.SoleLogics._compat_branch(AletheiaSole.:∧, (p, q)) isa AletheiaSole.Formula
    modal_connective = AletheiaSole.Diamond(:coverage)
    modal_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((AletheiaSole.:∧, modal_connective)))
    modal_atom = CompatibilityClient.atom(modal_pool, "modal")
    @test AletheiaSole.SoleLogics._compat_branch(modal_connective, modal_atom) isa AletheiaSole.Formula
    constant_formula = CompatibilityClient.:→(p, CompatibilityClient.⊥)
    @test constant_formula isa AletheiaSole.Formula
    @test CompatibilityClient.token(first(collect(CompatibilityClient.children(constant_formula)))) isa CompatibilityClient.Atom
    @test CompatibilityClient.token(collect(CompatibilityClient.children(constant_formula))[2]) === CompatibilityClient.⊥
    @test CompatibilityClient.truths(constant_formula) == [CompatibilityClient.⊥]
    @test CompatibilityClient.atoms(constant_formula) == [p]
    @test CompatibilityClient.leaves(constant_formula) == [p, CompatibilityClient.⊥]
    @test CompatibilityClient.nleaves(constant_formula) == 2

    # Exercise the legacy/native pool merge path and both cached tree walks.
    native_pool = AletheiaSole.FormulaPool(AletheiaSole.Signature((AletheiaSole.:∧,)))
    native_atom = AletheiaSole.atom(native_pool, "native")
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, native_atom, p) isa AletheiaSole.Formula
    merged = CompatibilityClient.Branch(CompatibilityClient.:∧, p, native_atom)
    @test merged isa AletheiaSole.Formula
    other_pool = CompatibilityClient.FormulaPool(CompatibilityClient.Signature((AletheiaSole.:∧,)))
    other_atom = CompatibilityClient.atom(other_pool, "other")
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, p, other_atom) isa AletheiaSole.Formula
    native_branch = AletheiaSole.branch(native_pool, AletheiaSole.:∧, native_atom, native_atom)
    @test CompatibilityClient.Branch(CompatibilityClient.:∧, p, native_branch) isa AletheiaSole.Formula
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
        (AletheiaCore.IA_A, AletheiaCore.IA_L, AletheiaCore.IA_B, AletheiaCore.IA_E, AletheiaCore.IA_D,
        AletheiaCore.IA_O, AletheiaCore.IA_Ai, AletheiaCore.IA_Li, AletheiaCore.IA_Bi, AletheiaCore.IA_Ei,
        AletheiaCore.IA_Di, AletheiaCore.IA_Oi)

    # SoleLogics defines LRCC8_Rec_* as these Topo_* aliases.
    @test (CompatibilityClient.LRCC8_Rec_DC, CompatibilityClient.LRCC8_Rec_EC,
        CompatibilityClient.LRCC8_Rec_PO, CompatibilityClient.LRCC8_Rec_TPP,
        CompatibilityClient.LRCC8_Rec_TPPi, CompatibilityClient.LRCC8_Rec_NTPP,
        CompatibilityClient.LRCC8_Rec_NTPPi) ===
        (AletheiaSole.DC, AletheiaSole.EC, AletheiaSole.PO, AletheiaSole.TPPi,
        AletheiaSole.TPP, AletheiaSole.NTPPi, AletheiaSole.NTPP)

    # SoleLogics defines LTLFP_F = GreaterRel and LTLFP_P = LesserRel.
    @test CompatibilityClient.LTLFP_F === AletheiaSole.GREATER
    @test CompatibilityClient.LTLFP_P === AletheiaSole.LESSER

    # Compass names now follow Aletheia's landed 2D point relation constants.
    @test (CompatibilityClient.CL_N, CompatibilityClient.CL_S,
        CompatibilityClient.CL_E, CompatibilityClient.CL_W,
        CompatibilityClient.CL_NE, CompatibilityClient.CL_NW,
        CompatibilityClient.CL_SE, CompatibilityClient.CL_SW) ===
        (AletheiaCore.CL_N, AletheiaCore.CL_S, AletheiaCore.CL_E, AletheiaCore.CL_W,
        AletheiaCore.CL_NE, AletheiaCore.CL_NW, AletheiaCore.CL_SE, AletheiaCore.CL_SW)
end

# The chain below is SolePostHoc's own conversion code from
# `src/shared_utils.jl`, kept verbatim in shape: it reads `.grandchildren`,
# `.ispos` and `.atom`, and builds branches from `NamedConnective{:sym}()`.
module LeftmostClient
using AletheiaSole.SoleLogics

function to_syntaxbranch(form, connective, convert)
    forms = form.grandchildren
    length(forms) == 1 && return convert(forms[1])
    foldl(forms[2:end]; init=convert(forms[1])) do branch, element
        SyntaxBranch(connective, (branch, convert(element)))
    end
end
literal_to_syntaxbranch(literal) = literal.ispos ? literal.atom :
    SyntaxBranch(NamedConnective{:¬}(), (literal.atom,))
conjunction_to_syntaxbranch(conjunction) =
    to_syntaxbranch(conjunction, NamedConnective{:∧}(), literal_to_syntaxbranch)
dnf_to_syntaxbranch(form) =
    to_syntaxbranch(form, NamedConnective{:∨}(), conjunction_to_syntaxbranch)
lf_to_string(form) =
    "(" * join(map(syntaxstring, SoleLogics.grandchildren(form)), " ∧ ") * ")"
end

@testset "leftmost linear forms" begin
    p, q, r = CompatibilityClient.Atom("p"), CompatibilityClient.Atom("q"),
        CompatibilityClient.Atom("r")
    conjunctive = CompatibilityClient.LeftmostConjunctiveForm([p, q])
    @test conjunctive isa CompatibilityClient.LeftmostLinearForm
    @test conjunctive isa AletheiaSole.Formula
    @test CompatibilityClient.grandchildren(conjunctive) == [p, q]
    @test CompatibilityClient.ngrandchildren(conjunctive) == 2
    @test CompatibilityClient.nconjuncts(conjunctive) == 2
    @test CompatibilityClient.conjuncts(conjunctive) == [p, q]
    @test CompatibilityClient.connective(conjunctive) === AletheiaSole.:∧
    @test CompatibilityClient.token(conjunctive).native === AletheiaSole.:∧
    @test conjunctive[1] == p
    @test CompatibilityClient.syntaxstring(conjunctive) == "p ∧ q"
    @test CompatibilityClient.syntaxstring(CompatibilityClient.tree(conjunctive)) == "p ∧ q"
    @test CompatibilityClient.height(conjunctive) == 1
    @test LeftmostClient.lf_to_string(conjunctive) == "(p ∧ q)"

    # Sole's own mutation vocabulary for a growing antecedent.
    CompatibilityClient.pushconjunct!(conjunctive, r)
    @test CompatibilityClient.ngrandchildren(conjunctive) == 3
    @test conjunctive[[1, 3]] == CompatibilityClient.LeftmostConjunctiveForm([p, r])
    push!(conjunctive, p)
    @test CompatibilityClient.ngrandchildren(conjunctive) == 4

    # A binary connective unwinds leftmost, so the fold is right-nested.
    nested = CompatibilityClient.tree(CompatibilityClient.LeftmostConjunctiveForm([p, q, r]))
    @test CompatibilityClient.syntaxstring(nested) == "p ∧ (q ∧ r)"
    @test CompatibilityClient.syntaxstring(
        CompatibilityClient.children(nested)[2]) == "q ∧ r"

    # A tree flattens back into a container over one connective.
    flattened = CompatibilityClient.LeftmostLinearForm(nested)
    @test CompatibilityClient.connective(flattened) === AletheiaSole.:∧
    @test CompatibilityClient.grandchildren(flattened) == [p, q, r]
    @test CompatibilityClient.LeftmostLinearForm(AletheiaSole.:∧, [p, q]) ==
        CompatibilityClient.LeftmostConjunctiveForm([p, q])

    @test_throws ArgumentError CompatibilityClient.LeftmostConjunctiveForm(
        CompatibilityClient.Atom[])
    @test CompatibilityClient.LeftmostConjunctiveForm(
        CompatibilityClient.Atom[], true) isa CompatibilityClient.LeftmostLinearForm

    literal = CompatibilityClient.Literal(p)
    @test literal.ispos && literal.atom == p
    @test CompatibilityClient.ispos(literal)
    @test CompatibilityClient.atom(literal) == p
    @test CompatibilityClient.tree(literal) == p
    negative = CompatibilityClient.dual(literal)
    @test !CompatibilityClient.ispos(negative)
    @test CompatibilityClient.hasdual(literal)
    @test CompatibilityClient.syntaxstring(negative) == "¬p"
    @test CompatibilityClient.Literal(
        CompatibilityClient.SyntaxBranch(AletheiaSole.:¬, p)) == negative
    @test_throws ArgumentError CompatibilityClient.Literal(
        CompatibilityClient.SyntaxBranch(AletheiaSole.:∧, p, q))

    # Sole's dnf/cnf return leftmost containers of literals.
    formula = CompatibilityClient.parseformula("(p ∧ q) ∨ (¬r ∧ q)")
    normal = CompatibilityClient.dnf(formula)
    @test normal isa CompatibilityClient.DNF
    @test CompatibilityClient.syntaxstring(normal) == "(p ∧ q) ∨ (¬r ∧ q)"
    @test all(literal -> literal isa CompatibilityClient.Literal,
        CompatibilityClient.grandchildren(CompatibilityClient.grandchildren(normal)[1]))
    @test CompatibilityClient.cnf(CompatibilityClient.parseformula("p ∧ (q ∨ r)")) isa
        CompatibilityClient.CNF
    @test_throws ArgumentError CompatibilityClient.dnf(formula; profile=:nnf)

    # SolePostHoc's rule-extraction chain, end to end.
    rebuilt = LeftmostClient.dnf_to_syntaxbranch(normal)
    @test rebuilt isa AletheiaSole.Formula
    @test CompatibilityClient.tree(normal) == rebuilt
    @test CompatibilityClient.syntaxstring(rebuilt) == "p ∧ q ∨ ¬r ∧ q"
    @test CompatibilityClient.NamedConnective{:∧}().native === AletheiaSole.:∧
    @test_throws ArgumentError CompatibilityClient.NamedConnective{:⊻}()

    # Containers evaluate by folding into the ordinary DAG.
    frame = AletheiaSole.Frame((:w,), Dict{Symbol,Any}())
    model = AletheiaSole.Model(frame, AletheiaSole.BOOLEAN,
        AletheiaSole.Valuation(Dict(("p", :w) => true, ("q", :w) => true, ("r", :w) => false)))
    @test CompatibilityClient.check(
        CompatibilityClient.LeftmostConjunctiveForm([p, q]), model, :w)
    @test !CompatibilityClient.check(
        CompatibilityClient.LeftmostConjunctiveForm([p, r]), model, :w)
    @test CompatibilityClient.check(CompatibilityClient.Literal(false, r), model, :w)
    @test CompatibilityClient.check(normal, model, :w) ==
        CompatibilityClient.check(rebuilt, model, :w)

    # Aletheia connective values are Sole operators for dispatch purposes.
    @test AletheiaSole.:∧ isa CompatibilityClient.Operator
    @test Vector{CompatibilityClient.Connective}(
        [AletheiaSole.:∨, AletheiaSole.:∧, AletheiaSole.:→]) isa Vector
    @test CompatibilityClient.AbstractSyntaxStructure === AletheiaSole.Formula
end

@testset "alphabets and random generation" begin
    p, q, r = CompatibilityClient.Atom("p"), CompatibilityClient.Atom("q"),
        CompatibilityClient.Atom("r")
    explicit = CompatibilityClient.ExplicitAlphabet([p, q, r])
    @test CompatibilityClient.atoms(explicit) == [p, q, r]
    @test CompatibilityClient.natoms(explicit) == 3
    @test p in explicit
    @test isfinite(explicit)
    @test CompatibilityClient.alphabet(explicit) === explicit
    @test CompatibilityClient.atoms(CompatibilityClient.ExplicitAlphabet(["p"])) ==
        [CompatibilityClient.Atom("p")]
    union_alphabet = CompatibilityClient.UnionAlphabet([explicit])
    @test CompatibilityClient.subalphabets(union_alphabet) == [explicit]
    @test CompatibilityClient.atoms(union_alphabet) == [p, q, r]
    @test CompatibilityClient.randatom(MersenneTwister(1), explicit) in [p, q, r]
    @test CompatibilityClient.randatom(explicit) in [p, q, r]

    operators = [AletheiaSole.:¬, AletheiaSole.:∧, AletheiaSole.:∨]
    generated = CompatibilityClient.randformula(MersenneTwister(7), 3, explicit, operators)
    @test generated isa AletheiaSole.Formula
    @test CompatibilityClient.height(generated) <= 3
    @test generated == CompatibilityClient.randformula(MersenneTwister(7), 3, explicit, operators)
    full = CompatibilityClient.randformula(MersenneTwister(11), 3, [p, q, r], operators;
        mode=:full)
    @test CompatibilityClient.height(full) == 3
    @test CompatibilityClient.randformula(3, explicit, operators) isa AletheiaSole.Formula

    # SoleReasoners passes a basecase picker and operator weights.
    weighted = CompatibilityClient.randformula(MersenneTwister(3), 2, explicit, operators;
        opweights=[0, 1, 0], basecase=rng -> p, mode=:full)
    @test CompatibilityClient.syntaxstring(weighted) == "p ∧ p ∧ (p ∧ p)"
    modal = CompatibilityClient.randformula(MersenneTwister(5), 2, explicit,
        [AletheiaSole.Diamond(AletheiaCore.IA_L)]; mode=:full)
    @test CompatibilityClient.token(modal) == AletheiaSole.Diamond(AletheiaCore.IA_L)
    @test CompatibilityClient.height(modal) == 2

    @test_throws ArgumentError CompatibilityClient.randformula(
        MersenneTwister(1), 2, explicit, operators; opweights=[1, 1])
    @test_throws ArgumentError CompatibilityClient.randformula(
        MersenneTwister(1), 2, explicit, operators; atompicker=[1, 1])
    @test_throws ArgumentError CompatibilityClient.randformula(
        MersenneTwister(1), 2, explicit, operators; unsupported_kwarg=1)
    @test_throws ArgumentError CompatibilityClient.randformula(1, 2, explicit, operators)
end

# A truth constant that occurs as a leaf inside a formula must come back from
# `children` as a `Truth`, not as an `Atom` wrapping one. SoleReasoners' tableau
# branches on the child object's type (`alphasat.jl:152`,
# `assertion(node) isa Tuple{Truth,Truth}`), so an `Atom` there silently
# disarms the closure rules and turns UNSAT into SAT.
@testset "truth constants stay truth values" begin
    MV = CompatibilityClient.ManyValuedLogics
    p = CompatibilityClient.Atom("p")
    bot, top = CompatibilityClient.⊥, CompatibilityClient.⊤

    conjunction = CompatibilityClient.SyntaxBranch(AletheiaSole.:∧, bot, bot)
    child = CompatibilityClient.children(conjunction)[1]
    @test child isa CompatibilityClient.Truth
    @test child === bot
    @test !(child isa CompatibilityClient.Atom)
    @test CompatibilityClient.token(child) === child
    # the consumer's own closure-rule predicate
    @test (MV.α, child) isa Tuple{CompatibilityClient.Truth,CompatibilityClient.Truth}

    mixed = CompatibilityClient.SyntaxBranch(AletheiaSole.:∧, p, top)
    @test CompatibilityClient.children(mixed)[1] === p
    @test CompatibilityClient.children(mixed)[2] === top
    @test (MV.α, CompatibilityClient.children(mixed)[2]) isa
        Tuple{CompatibilityClient.Truth,CompatibilityClient.Truth}
    @test !((MV.α, CompatibilityClient.children(mixed)[1]) isa
        Tuple{CompatibilityClient.Truth,CompatibilityClient.Truth})

    # finite tableau carriers travel the same path
    finite = CompatibilityClient.SyntaxBranch(AletheiaSole.:∨, p, MV.α)
    finite_child = CompatibilityClient.children(finite)[2]
    @test finite_child isa MV.FiniteTruth
    @test finite_child === MV.α

    # a child handed back this way rebuilds the identical formula
    @test CompatibilityClient.SyntaxBranch(AletheiaSole.:∧,
        CompatibilityClient.children(mixed)...) == mixed

    # flattened and normal-form views keep the truth value too
    @test CompatibilityClient.conjuncts(mixed) == [p, top]
    normal = CompatibilityClient.dnf(CompatibilityClient.SyntaxBranch(AletheiaSole.:∧, p, bot))
    literals = CompatibilityClient.grandchildren(
        CompatibilityClient.grandchildren(normal)[1])
    @test any(literal -> literal.atom isa CompatibilityClient.Truth, literals)

    # the surrounding vocabulary keeps its documented meaning
    @test CompatibilityClient.atoms(mixed) == [p]
    @test CompatibilityClient.leaves(mixed) == [p, top]
    @test CompatibilityClient.truths(mixed) == [top]
    @test CompatibilityClient.nleaves(mixed) == 2

    # and evaluation is unchanged: a truth leaf is still an algebra constant
    frame = AletheiaSole.Frame((:w,), Dict{Symbol,Any}())
    model = AletheiaSole.Model(frame, AletheiaSole.BOOLEAN,
        AletheiaSole.Valuation(Dict(("p", :w) => true)))
    @test CompatibilityClient.check(mixed, model, :w)
    @test !CompatibilityClient.check(
        CompatibilityClient.SyntaxBranch(AletheiaSole.:∧, p, bot), model, :w)
    @test CompatibilityClient.check(bot, model, :w) == false
end


@testset "SoleData prepared scalar bridge" begin
    if Base.find_package("SoleData") !== nothing
        @eval using SoleData
        @eval using AletheiaData
        logiset = SoleData.scalarlogiset([[1.0, 2.0], [3.0, 4.0]])
        prepared = AletheiaData.prepare_scalar(logiset)
        condition = SoleData.ScalarCondition(1, >, 1.5)
        @test AletheiaData.scalar_check(condition, prepared, 1, 1) === false
        @test AletheiaData.scalar_check(condition, prepared, 1, 2) === true
    end
end
