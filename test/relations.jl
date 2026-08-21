struct ExternalFamilyRelation end
Base.show(io::IO, ::ExternalFamilyRelation) = print(io, "external")
Aletheia.relation_holds(::ExternalFamilyRelation, source::Int, target::Int) = iseven(source + target)

struct HookedPointRelation end
const hooked_point_calls = Ref(0)
Aletheia.relation_holds(::HookedPointRelation, source::Int, target::Int) = source == target
function Aletheia.relation_successors(::HookedPointRelation, source::Int, worlds)
    hooked_point_calls[] += 1
    (source,)
end

# Independent endpoint oracle: this intentionally does not call relation_holds or inverse.
function allen_definition(relation, source::Interval, target::Interval)
    sx, sy, tx, ty = source.x, source.y, target.x, target.y
    relation === BEFORE ? sy < tx :
    relation === MEETS ? sy == tx :
    relation === OVERLAPS ? sx < tx < sy < ty :
    relation === STARTS ? sx == tx && sy < ty :
    relation === DURING ? tx < sx && sy < ty :
    relation === FINISHES ? tx < sx && sy == ty :
    relation === EQUALS ? sx == tx && sy == ty :
    relation === AFTER ? ty < sx :
    relation === MET_BY ? sx == ty :
    relation === OVERLAPPED_BY ? tx < sx < ty < sy :
    relation === STARTED_BY ? sx == tx && ty < sy :
    relation === CONTAINS ? sx < tx && ty < sy :
    relation === FINISHED_BY ? sx < tx && sy == ty :
    throw(ArgumentError("unknown Allen relation"))
end

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
    @test sprint(show, IDENTITY) == "identity"
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
    @test collect(relation_successors(BEFORE, I(1, 2), interval_worlds)) ==
        collect(accessible(interval_frame(3), I(1, 2), BEFORE))
    @test all(sum(relation_holds(r, source, target) for r in ALLEN_RELATIONS) == 1
        for source in interval_worlds for target in interval_worlds)
    @test all(relation_holds(r, source, target) == allen_definition(r, source, target)
        for r in ALLEN_RELATIONS for source in interval_worlds for target in interval_worlds)
    @test all(collect(relation_successors(r, source, interval_worlds)) ==
        [target for target in interval_worlds if relation_holds(r, source, target)]
        for r in ALLEN_RELATIONS for source in interval_worlds)

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
    @test all(collect(relation_successors(r, source, rectangles)) ==
        [target for target in rectangles if relation_holds(r, source, target)]
        for r in RCC8_RELATIONS for source in rectangles)
    rr = rectangle_relation(MEETS, MEETS)
    @test inverse(rr) == rectangle_relation(MET_BY, MET_BY)
    @test isequal(rr, rectangle_relation(MEETS, MEETS))
    @test sprint(show, rr) == "rectangle-relation"
    @test relation_holds(rr, Rectangle((1, 2), (2, 3)), Rectangle((2, 3), (3, 4)))
    @test relation_successors(rr, Rectangle((1, 2), (1, 2)), rectangles) !== nothing

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
    @test !relation_holds(SUCCESSOR, 10, 20)
    @test relation_holds(SUCCESSOR, 10, 20, worlds(points))
    @test relation_holds(MINIMUM, 20, 10, worlds(points))
    @test relation_holds(MAXIMUM, 20, 40, worlds(points))
    for r in POINT_RELATIONS
        @test all((target in collect(accessible(points, source, r))) ==
                  relation_holds(r, source, target, worlds(points))
                  for source in worlds(points), target in worlds(points))
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
    @test Full2DPointFrame(2, 2).worlds == point_frame(2, 2).worlds
    @test_throws ArgumentError interval_frame([1, 1])
    @test_throws ArgumentError rectangle_frame([1, 1], [1, 2])

    @testset "Point2DRelation family and 2D point frames" begin
        @test length(POINT2D_RELATIONS) == 8
        @test length(Point2DRelations) == 8
        @test Point2DRelations == (CL_N, CL_S, CL_E, CL_W, CL_NE, CL_NW, CL_SE, CL_SW)

        display_pairs = [
            (CL_N, "N"), (CL_S, "S"), (CL_E, "E"), (CL_W, "W"),
            (CL_NE, "NE"), (CL_NW, "NW"), (CL_SE, "SE"), (CL_SW, "SW")
        ]
        for (r, expected_str) in display_pairs
            @test sprint(show, r) == expected_str
            @test r isa Point2DRelation
            @test r isa RelationFamily
            @test istransitive(r)
        end

        converses = [
            (CL_N, CL_S), (CL_S, CL_N),
            (CL_E, CL_W), (CL_W, CL_E),
            (CL_NE, CL_SW), (CL_SW, CL_NE),
            (CL_NW, CL_SE), (CL_SE, CL_NW),
        ]
        for (r1, r2) in converses
            @test inverse(r1) === r2
            @test converse(r1) === r2
            @test converse(converse(r1)) === r1
            @test inverse(inverse(r1)) === r1
        end

        # Hand-checked accessibility on a 3x3 grid
        pf3x3 = point_frame(3, 3)
        @test length(worlds(pf3x3)) == 9
        center = Point(2, 2)
        @test collect(accessible(pf3x3, center, CL_N)) == [Point(2, 3)]
        @test collect(accessible(pf3x3, center, CL_S)) == [Point(2, 1)]
        @test collect(accessible(pf3x3, center, CL_E)) == [Point(3, 2)]
        @test collect(accessible(pf3x3, center, CL_W)) == [Point(1, 2)]
        @test collect(accessible(pf3x3, center, CL_NE)) == [Point(3, 3)]
        @test collect(accessible(pf3x3, center, CL_NW)) == [Point(1, 3)]
        @test collect(accessible(pf3x3, center, CL_SE)) == [Point(3, 1)]
        @test collect(accessible(pf3x3, center, CL_SW)) == [Point(1, 1)]

        sw_corner = Point(1, 1)
        @test collect(accessible(pf3x3, sw_corner, CL_N)) == [Point(1, 2), Point(1, 3)]
        @test collect(accessible(pf3x3, sw_corner, CL_E)) == [Point(2, 1), Point(3, 1)]
        @test collect(accessible(pf3x3, sw_corner, CL_NE)) == [Point(2, 2), Point(2, 3), Point(3, 2), Point(3, 3)]
        @test isempty(accessible(pf3x3, sw_corner, CL_S))
        @test isempty(accessible(pf3x3, sw_corner, CL_W))
        @test isempty(accessible(pf3x3, sw_corner, CL_SW))
        @test isempty(accessible(pf3x3, sw_corner, CL_NW))
        @test isempty(accessible(pf3x3, sw_corner, CL_SE))

        # Check relation_holds explicitly (both Point objects and Tuples)
        @test relation_holds(CL_N, Point(1, 1), Point(1, 2))
        @test !relation_holds(CL_N, Point(1, 1), Point(2, 2))
        @test relation_holds(CL_NE, Point(1, 1), Point(2, 2))
        @test relation_holds(CL_SW, Point(2, 2), Point(1, 1))
        @test relation_holds(CL_N, (1, 1), (1, 2))
        @test relation_holds(CL_S, (1, 2), (1, 1))
        @test relation_holds(CL_E, (1, 1), (2, 1))
        @test relation_holds(CL_W, (2, 1), (1, 1))
        @test relation_holds(CL_NW, (2, 1), (1, 2))
        @test relation_holds(CL_SE, (1, 2), (2, 1))

        # Test frame transitivity
        for r in POINT2D_RELATIONS
            @test istransitive(pf3x3, r)
        end

        # Test Full2DPointFrame and FullDimensionalFrame
        @test Full2DPointFrame(3, 3).worlds == pf3x3.worlds
        @test FullDimensionalFrame((3, 3), Point).worlds == pf3x3.worlds

        # Lazy iterator check (does not return Vector directly, returns Generator)
        @test !(accessible(pf3x3, center, CL_N) isa Vector)

        # End-to-end modal check over 2D point frame
        pool2d = FormulaPool(Signature((Diamond(CL_NE), Box(CL_SW))))
        p_atom = atom(pool2d, "p")
        f_dia = branch(pool2d, Diamond(CL_NE), p_atom)
        f_box = branch(pool2d, Box(CL_SW), p_atom)

        # p holds only at (3, 3)
        model2d = Model(pf3x3, BOOLEAN, Dict("p" => Set([Point(3, 3)])))
        @test check(f_dia, model2d, Point(2, 2)) == true
        @test check(f_dia, model2d, Point(3, 3)) == false
        @test check(f_dia, model2d, Point(1, 1)) == true

        # Model where p holds at all worlds except (2, 2)
        all_except_center = Set(w for w in worlds(pf3x3) if w != center)
        model2d_box = Model(pf3x3, BOOLEAN, Dict("p" => all_except_center))
        # SW of (2, 2) is (1, 1), where p is true, so [SW]p at (2, 2) is true
        @test check(f_box, model2d_box, center) == true

        # Invalid domains check
        @test_throws ArgumentError point_frame(Int[], 1:3)
        @test_throws ArgumentError point_frame(1:3, Int[])
        @test_throws ArgumentError point_frame([2, 1], 1:3)
        @test_throws ArgumentError point_frame(1:3, [2, 1])
    end

    @test collect(accessible(points, 10, CustomPointRelation())) == [10]
    hooked_point_calls[] = 0
    hooked_frame = point_frame(1:4)
    @test collect(accessible(hooked_frame, 2, HookedPointRelation())) == [2]
    @test hooked_point_calls[] > 0

    external_frame = point_frame(1:4)
    @test relation_successors(ExternalFamilyRelation(), 1, worlds(external_frame)) === nothing
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
