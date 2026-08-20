struct ExternalFamilyRelation end
Base.show(io::IO, ::ExternalFamilyRelation) = print(io, "external")
Aletheia.relation_holds(::ExternalFamilyRelation, source::Int, target::Int) = iseven(source + target)

@testset "relation families and dimensional frames" begin
    I = Interval
    a, b = I(1, 3), I(3, 5)
    overlap_a, overlap_b = I(1, 4), I(2, 5)
    long = I(1, 5)
    inner = I(2, 4)
    same_start = I(1, 4)
    same_end = I(2, 5)
    right = I(4, 6)

    examples = (
        (BEFORE, a, right), (MEETS, a, b), (OVERLAPS, overlap_a, overlap_b),
        (STARTS, same_start, long), (DURING, inner, long),
        (FINISHES, same_end, long), (EQUALS, a, a),
        (AFTER, right, a), (MET_BY, b, a),
        (OVERLAPPED_BY, overlap_b, overlap_a), (STARTED_BY, long, same_start),
        (CONTAINS, long, inner), (FINISHED_BY, long, same_end),
    )
    @test length(ALLEN_RELATIONS) == 13
    for (r, source, target) in examples
        @test relation_holds(r, source, target)
        @test relation_holds(inverse(r), target, source)
        @test inverse(inverse(r)) == r
        @test converse(r) == inverse(r)
    end
    @test inverse(EQUALS) === EQUALS
    @test inverse(IDENTITY) === IDENTITY
    @test_throws MethodError relation_holds(:not-a-relation, a, b)
    @test_throws MethodError inverse(:not-a-relation)
    @test_throws MethodError Base.invokelatest(Aletheia.relation_holds, :not-a-relation, a, b)
    @test_throws MethodError Base.invokelatest(Aletheia.inverse, :not-a-relation)
    for r in ALLEN_RELATIONS
        @test sprint(show, r) isa String
    end
    @test !relation_holds(BEFORE, a, b)
    @test !relation_holds(MEETS, a, right)
    @test_throws ArgumentError I(3, 3)
    @test_throws ArgumentError I(4, 2)
    @test length(a) == 2
    @test string(a) == "(1−3)"
    @test IA_A === MEETS && IA_L === BEFORE && IA_O === OVERLAPS
    @test IA_B === STARTED_BY && IA_Bi === STARTS
    @test IA_E === FINISHED_BY && IA_Ei === FINISHES
    @test IA_D === CONTAINS && IA_Di === DURING
    @test collect(accessible(interval_frame(5), I(2, 4), IA_B)) == [I(2, 3)]
    interval_worlds = worlds(interval_frame(3))
    @test all(sum(relation_holds(r, source, target) for r in ALLEN_RELATIONS) == 1
        for source in interval_worlds for target in interval_worlds)

    @test relation_holds(DC, I(1, 2), I(3, 4))
    @test relation_holds(EC, I(1, 2), I(2, 3))
    @test relation_holds(PO, I(1, 4), I(2, 5))
    @test relation_holds(TPP, I(1, 2), I(1, 4))
    @test relation_holds(TPPi, I(1, 4), I(1, 2))
    @test relation_holds(NTPP, I(2, 3), I(1, 4))
    @test relation_holds(NTPPi, I(1, 4), I(2, 3))
    @test relation_holds(RCC_EQ, a, a)
    for r in RCC8_RELATIONS
        @test inverse(inverse(r)) == r
    end
    @test length(RCC8_BASICS) == 7
    @test Topo_TPP === TPPi && Topo_NTPP === NTPPi

    rectangles = worlds(rectangle_frame(2, 2))
    @test length(rectangles) == 9
    @test length(worlds(interval_frame(3))) == 6
    @test relation_holds(RCC_EQ, rectangles[1], rectangles[1])
    @test relation_holds(DC, Rectangle((1, 2), (1, 2)), Rectangle((2, 3), (2, 3))) == false
    @test relation_holds(EC, Rectangle((1, 2), (1, 2)), Rectangle((2, 3), (1, 2)))
    @test relation_holds(PO, Rectangle((1, 3), (1, 2)), Rectangle((2, 4), (1, 2)))
    @test relation_holds(TPP, Rectangle((1, 2), (1, 2)), Rectangle((1, 3), (1, 3)))
    @test relation_holds(NTPP, Rectangle((2, 3), (2, 3)), Rectangle((1, 4), (1, 4)))
    @test relation_holds(TPPi, Rectangle((1, 3), (1, 3)), Rectangle((1, 2), (1, 2)))
    @test relation_holds(NTPPi, Rectangle((1, 4), (1, 4)), Rectangle((2, 3), (2, 3)))
    @test all(sum(relation_holds(r, source, target) for r in RCC8_RELATIONS) == 1
        for source in rectangles for target in rectangles)
    rr = rectangle_relation(MEETS, MEETS)
    @test inverse(rr) == rectangle_relation(MET_BY, MET_BY)
    @test relation_holds(rr, Rectangle((1, 2), (2, 3)), Rectangle((2, 3), (3, 4)))

    struct CustomPointRelation <: Aletheia.PointRelation end
    Aletheia.relation_holds(::CustomPointRelation, source::Int, target::Int) = source == target

    points = point_frame([10, 20, 40])
    @test worlds(points) == (10, 20, 40)
    @test collect(accessible(points, 10, MINIMUM)) == [10]
    @test collect(accessible(points, 20, MINIMUM)) == [10]
    @test collect(accessible(points, 10, MAXIMUM)) == [40]
    @test collect(accessible(points, 20, SUCCESSOR)) == [40]
    @test collect(accessible(points, 20, PREDECESSOR)) == [10]
    @test collect(accessible(points, 10, GREATER)) == [20, 40]
    @test collect(accessible(points, 40, LESSER)) == [10, 20]
    @test collect(accessible(points, 20, IDENTITY)) == [20]
    @test inverse(SUCCESSOR) === PREDECESSOR && inverse(GREATER) === LESSER
    @test inverse(MINIMUM) === MINIMUM && inverse(MAXIMUM) === MAXIMUM
    @test relation_holds(SUCCESSOR, 1, 2) && !relation_holds(SUCCESSOR, 1, 3)
    @test relation_holds(PREDECESSOR, 2, 1) && relation_holds(GREATER, 1, 2)
    @test relation_holds(LESSER, 2, 1)
    for r in POINT_RELATIONS
        @test sprint(show, r) isa String
        @test inverse(inverse(r)) == r
    end
    for r in RCC8_RELATIONS
        @test sprint(show, r) isa String
    end
    @test FullDimensionalFrame((3,), Interval).worlds == interval_frame(3).worlds
    @test Full1DFrame(3).worlds == interval_frame(3).worlds
    @test Full2DFrame(2, 2).worlds == rectangle_frame(2, 2).worlds
    @test FullDimensionalFrame(2, 2).worlds == rectangle_frame(2, 2).worlds
    @test FullDimensionalFrame(2).worlds == interval_frame(2).worlds
    @test Full1DPointFrame(3).worlds == point_frame(3).worlds
    @test FullDimensionalFrame((3,), Point).worlds == point_frame(3).worlds
    @test sprint(show, Rectangle((1, 2), (1, 3))) == "((1−2)×(1−3))"
    @test hash(rr) isa UInt
    @test Point(1).coordinates == (1,) && Point(1, 2).coordinates == (1, 2)
    @test length(Rectangle((1, 2), (1, 3))) == 2
    @test Aletheia._point_worlds((1, 2)) == (1, 2)
    @test Aletheia._point_relation_holds(CustomPointRelation(), 10, 10, worlds(points))
    @test Aletheia._dimensional_relation_holds(CustomPointRelation(), 10, 10, worlds(points))
    @test Rectangle((1, 2), (1, 3)) == Rectangle(Interval(1, 2), Interval(1, 3))
    @test interval_frame(1:4).worlds == interval_frame([1, 2, 3, 4]).worlds
    @test rectangle_frame([1, 2], [1, 2]).worlds == rectangle_frame(1, 1).worlds
    @test_throws ArgumentError point_frame(Int[])
    @test_throws ArgumentError interval_frame(0)
    @test_throws ArgumentError rectangle_frame(0, 2)
    @test_throws ArgumentError point_frame([2, 1])
    @test_throws ArgumentError FullDimensionalFrame((1, 2, 3))
    @test_throws ArgumentError Full2DPointFrame(2, 2)
    @test_throws ArgumentError interval_frame([1, 1])
    @test_throws ArgumentError rectangle_frame([1, 1], [1, 2])

    @test collect(accessible(points, 10, CustomPointRelation())) == [10]

    external_frame = point_frame(1:4)
    @test collect(accessible(external_frame, 1, ExternalFamilyRelation())) == [1, 3]
    @test collect(accessible(external_frame, 2, ExternalFamilyRelation())) == [2, 4]
    external_pool = FormulaPool(Signature((Diamond(ExternalFamilyRelation()),)))
    external_atom = atom(external_pool, "p")
    external_formula = branch(external_pool, Diamond(ExternalFamilyRelation()), external_atom)
    external_model = Model(external_frame, BOOLEAN, Dict("p" => Set([1, 3])))
    @test extension(external_formula, external_model) == BitVector([true, false, true, false])

    syntax_pool = FormulaPool(Signature((Diamond(BEFORE), Box(BEFORE))))
    syntax_atom = atom(syntax_pool, "p")
    @test parse(syntax_pool, "⟨before⟩p") == branch(syntax_pool, Diamond(BEFORE), syntax_atom)
    @test parse(syntax_pool, "[before]p") == branch(syntax_pool, Box(BEFORE), syntax_atom)

    sig = Signature((Diamond(BEFORE), Box(BEFORE), Implication()))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    model = Model(interval_frame(3), BOOLEAN, Dict("p" => Set([I(3, 4)])))
    diamond = branch(pool, Diamond(BEFORE), p)
    box = branch(pool, Box(BEFORE), p)
    @test extension(diamond, model) == BitVector([true, false, false, false, false, false])
    @test check(box, model, I(1, 2)) == true
    @test check(box, model, I(3, 4)) == true
end


@testset "frame class traits and correspondence axioms" begin
    reflexive_frame = Frame((1, 2), Dict(:R => Dict(1 => [1, 2], 2 => [1, 2])); index=true)
    preorder = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [2])); index=true)
    symmetric_frame = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [1])); index=true)
    serial_frame = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [2])); index=true)
    nonserial = Frame((1, 2), Dict(:R => Dict(1 => [], 2 => [2])); index=true)
    nontransitive = Frame((1, 2, 3), Dict(:R => Dict(1 => [1, 2], 2 => [2, 3], 3 => [3])); index=true)
    @test isreflexive(reflexive_frame, :R)
    @test istransitive(reflexive_frame, :R)
    @test issymmetric(reflexive_frame, :R)
    @test isserial(reflexive_frame, :R)
    @test sprint(show, T) == "T"
    @test sprint(show, FrameClass(:custom, ())) == "custom"
    @test satisfies(reflexive_frame, K, :R)
    @test satisfies(reflexive_frame, T, :R)
    @test satisfies(reflexive_frame, S4, :R)
    @test satisfies(reflexive_frame, S5, :R)
    @test reflexive(reflexive_frame, :R) && transitive(reflexive_frame, :R)
    @test symmetric(reflexive_frame, :R) && serial(reflexive_frame, :R)
    @test isreflexive(reflexive_frame) && istransitive(reflexive_frame)
    @test satisfies(serial_frame, SERIAL, :R) && !satisfies(nonserial, SERIAL, :R)
    @test checkclass(reflexive_frame, T, :R) && validclass(reflexive_frame, T, :R)
    @test istransitive(preorder, :R) && !issymmetric(preorder, :R)
    @test !istransitive(nontransitive, :R) && isreflexive(nontransitive, :R)
    @test !isreflexive(preorder, :R)
    @test issymmetric(symmetric_frame, :R) && isserial(serial_frame, :R)
    @test !isserial(nonserial, :R)
    @test !isreflexive(Frame((1,), Dict()), :R)
    generated = interval_frame(3)
    @test isreflexive(generated, IDENTITY)
    @test !isreflexive(generated, BEFORE)
    @test satisfies(generated, K, BEFORE)
    @test !satisfies(generated, T, BEFORE)
    @test !satisfies(generated, FrameClass(:unknown, (:unknown_condition,)), BEFORE)

    sig = Signature((Implication(), Conjunction(), Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    t_axiom = axiom(pool, T; relation=:R)
    s4_axiom = axiom(pool, S4; relation=:R)
    s5_axiom = axiom(pool, S5; relation=:R)
    d_axiom = axiom(pool, SERIAL; relation=:R)
    k_axiom = axiom(pool, K; relation=:R)
    b_axiom = axiom(pool, SYMMETRIC; relation=:R)
    d_axiom = axiom(pool, SERIAL; relation=:R)
    k_axiom = axiom(pool, K; relation=:R)
    @test length(axioms(pool, T; relation=:R)) == 1
    @test length(axioms(pool, S4; relation=:R)) == 2
    @test length(axioms(pool, S5; relation=:R)) == 3
    @test length(axioms(pool, K; relation=:R)) == 1
    @test length(axioms(pool, SERIAL; relation=:R)) == 1
    @test isbranch(t_axiom) && isbranch(s4_axiom) && isbranch(s5_axiom) && isbranch(b_axiom) && isbranch(d_axiom) && isbranch(k_axiom)
    p = atom(pool, "p")
    valuation = Dict("p" => Set([2]), "q" => Set([2]))
    conforming = Model(reflexive_frame, BOOLEAN, valuation)
    failing = Model(preorder, BOOLEAN, valuation)
    @test validates(conforming, t_axiom)
    @test validates(conforming, s4_axiom)
    @test validates(conforming, s5_axiom)
    @test validates(conforming, k_axiom)
    @test validates(Model(serial_frame, BOOLEAN, valuation), d_axiom)
    @test !validates(Model(nonserial, BOOLEAN, valuation), d_axiom)
    @test validates(t_axiom, conforming)
    @test !validates(failing, t_axiom)
    @test !validates(failing, s4_axiom)
    @test !validates(Model(nontransitive, BOOLEAN, Dict("p" => Set([1, 2]), "q" => Set([1, 2]))), s4_axiom)
    @test validates(Model(symmetric_frame, BOOLEAN, Dict("p" => Set([1]), "q" => Set([1]))), b_axiom)
    @test_throws ArgumentError axiom(FormulaPool(Signature((Box(:R),))), T; relation=:R)
    @test_throws ArgumentError axioms(pool, FrameClass(:unknown, (:unknown_condition,)); relation=:R)
    @test_throws ArgumentError axiom(FormulaPool(Signature((Box(:R), Implication()))), S5; relation=:R)
end
