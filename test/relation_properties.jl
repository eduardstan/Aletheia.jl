# Generated-input properties for relation values.
#
# Every property below draws its domain from a seeded generator and then
# quantifies over every ordered pair of the generated domain, so a defect in
# any relation of the family fails the property rather than a fixed example.
# Failures report the offending pairs, not just a boolean.

const _RELATION_RNG = MersenneTwister(0x5eed)

# A strictly increasing boundary vector with generated origin and spacing.
function _generated_boundaries(rng, count)
    values = Int[]
    value = rand(rng, -2:2)
    for _ in 1:count
        push!(values, value)
        value += rand(rng, 1:3)
    end
    values
end
_generated_points(rng, count) = _generated_boundaries(rng, count)
_intervals_over(boundaries) = [Interval(boundaries[i], boundaries[j])
    for i in eachindex(boundaries) for j in (i + 1):length(boundaries)]

# Domains include the degenerate ones: two boundaries give a single interval,
# a one-value point domain gives a single point, and a 1x1 grid a single cell.
const _INTERVAL_BOUNDARIES = [_generated_boundaries(_RELATION_RNG, k) for k in (2, 3, 4, 5)]
const _RECTANGLE_BOUNDARIES = [(_generated_boundaries(_RELATION_RNG, k),
    _generated_boundaries(_RELATION_RNG, l)) for (k, l) in ((2, 2), (3, 2), (3, 3), (4, 3))]
const _POINT_DOMAINS = [_generated_points(_RELATION_RNG, k) for k in (1, 2, 4, 5)]
const _GRID_DOMAINS = [(_generated_points(_RELATION_RNG, k), _generated_points(_RELATION_RNG, l))
    for (k, l) in ((1, 1), (3, 2), (3, 4))]

const _INTERVAL_WORLDS = [_intervals_over(b) for b in _INTERVAL_BOUNDARIES]
const _RECTANGLE_WORLDS = [[Rectangle(x, y) for x in _intervals_over(xb) for y in _intervals_over(yb)]
    for (xb, yb) in _RECTANGLE_BOUNDARIES]
const _POINT_WORLDS = _POINT_DOMAINS
const _GRID_WORLDS = [[Point(x, y) for x in xs for y in ys] for (xs, ys) in _GRID_DOMAINS]

# Every relation value the package exports, collected from the exported names
# so a newly exported relation joins these properties without an edit here.
const _EXPORTED_RELATIONS = let values = Any[]
    for name in names(Aletheia)
        isdefined(Aletheia, name) || continue
        value = getproperty(Aletheia, name)
        value isa Aletheia.RelationFamily && !any(other -> other === value, values) &&
            push!(values, value)
    end
    values
end

# Generated rectangle relations: the axis pair is drawn, not fixed.
const _RECTANGLE_RELATIONS = [rectangle_relation(rand(_RELATION_RNG, ALLEN_RELATIONS),
    rand(_RELATION_RNG, ALLEN_RELATIONS)) for _ in 1:6]

# Relations excluded from the converse and involution properties, by name:
#
#   MINIMUM, MAXIMUM — every source reaches one fixed boundary world, so the
#     converse relates that one world to every target. That relation is not a
#     value this vocabulary names, so `inverse` refuses rather than returning a
#     relation which is not the converse; the refusal is asserted below.
#   tocenterrel — it has no source/target predicate at all (the frame defines
#     its target), so there is no `relation_holds` for a converse to be checked
#     against. `inverse` refuses for it too.
#
# All three refusals are `ArgumentError`s carrying the reason, not bare
# no-method errors.
const _NO_CONVERSE = (MINIMUM, MAXIMUM, tocenterrel)
_has_converse(relation) = !any(excluded -> excluded === relation, _NO_CONVERSE)

# The domains a relation family is defined over. Domain-agnostic relations
# (identity, global) are checked on both an interval and a point domain.
function _relation_domains(relation)
    relation isa Aletheia.IntervalRelation ? _INTERVAL_WORLDS :
    relation isa Aletheia.RCCRelation ? vcat(_INTERVAL_WORLDS, _RECTANGLE_WORLDS) :
    relation isa Aletheia.PointRelation ? _POINT_WORLDS :
    relation isa Aletheia.Point2DRelation ? _GRID_WORLDS :
    vcat(_INTERVAL_WORLDS, _POINT_WORLDS)
end

_converse_mismatches(relation, ws) =
    [(a, b) for a in ws for b in ws
        if relation_holds(inverse(relation), a, b, ws) != relation_holds(relation, b, a, ws)]

@testset "relation properties over generated domains" begin
    @test length(_EXPORTED_RELATIONS) >= 40

    @testset "inverse is the converse" begin
        for relation in _EXPORTED_RELATIONS
            _has_converse(relation) || continue
            for ws in _relation_domains(relation)
                @test _converse_mismatches(relation, ws) == []
            end
        end
        for relation in _RECTANGLE_RELATIONS, ws in _RECTANGLE_WORLDS
            @test _converse_mismatches(relation, ws) == []
        end
        # The excluded relations must refuse, not answer wrongly, and the
        # refusal must explain itself.
        for relation in _NO_CONVERSE
            @test_throws ArgumentError inverse(relation)
            @test_throws "is undefined" inverse(relation)
            @test_throws "converse" inverse(relation)
        end
    end

    @testset "inverse is an involution" begin
        for relation in _EXPORTED_RELATIONS
            _has_converse(relation) || continue
            @test inverse(inverse(relation)) === relation
        end
        for relation in _RECTANGLE_RELATIONS
            @test inverse(inverse(relation)) == relation
        end
    end

    @testset "Allen and RCC8 are jointly exhaustive and pairwise disjoint" begin
        for ws in _INTERVAL_WORLDS
            @test [(a, b) for a in ws for b in ws
                if count(r -> relation_holds(r, a, b), ALLEN_RELATIONS) != 1] == []
            @test [(a, b) for a in ws for b in ws
                if count(r -> relation_holds(r, a, b), RCC8_RELATIONS) != 1] == []
        end
        for ws in _RECTANGLE_WORLDS
            @test [(a, b) for a in ws for b in ws
                if count(r -> relation_holds(r, a, b), RCC8_RELATIONS) != 1] == []
        end
    end

    # A relation with an optimised successor iterator must produce exactly the
    # worlds the generic predicate selects, each of them once. Sets alone would
    # hide a duplicated target, so multiplicity is checked as well.
    function _successor_defects(relation, ws, frame)
        defects = []
        for source in ws
            expected = Set(t for t in ws if relation_holds(relation, source, t, ws))
            fast = relation_successors(relation, source, ws)
            streams = fast === nothing ? Any[("accessible", accessible(frame, source, relation))] :
                Any[("relation_successors", fast), ("accessible", accessible(frame, source, relation))]
            for (label, targets) in streams
                got = collect(targets)
                allunique(got) || push!(defects, (label, source, :duplicate, got))
                Set(got) == expected || push!(defects, (label, source, :set, got))
            end
        end
        defects
    end

    @testset "optimised successors agree with the generic predicate" begin
        interval_frames = [(interval_frame(b), _intervals_over(b)) for b in _INTERVAL_BOUNDARIES]
        rectangle_frames = [(rectangle_frame(xb, yb),
            [Rectangle(x, y) for x in _intervals_over(xb) for y in _intervals_over(yb)])
            for (xb, yb) in _RECTANGLE_BOUNDARIES]
        point_frames = [(point_frame(d), d) for d in _POINT_DOMAINS]
        grid_frames = [(point_frame(xs, ys), [Point(x, y) for x in xs for y in ys])
            for (xs, ys) in _GRID_DOMAINS]
        for relation in _EXPORTED_RELATIONS
            # tocenterrel has no source/target predicate to compare against.
            relation === tocenterrel && continue
            frames = relation isa Aletheia.IntervalRelation ? interval_frames :
                relation isa Aletheia.RCCRelation ? vcat(interval_frames, rectangle_frames) :
                relation isa Aletheia.PointRelation ? point_frames :
                relation isa Aletheia.Point2DRelation ? grid_frames :
                vcat(interval_frames, point_frames)
            for (frame, ws) in frames
                @test _successor_defects(relation, ws, frame) == []
            end
        end
        for relation in _RECTANGLE_RELATIONS, (frame, ws) in rectangle_frames
            @test _successor_defects(relation, ws, frame) == []
        end
    end

    @testset "IA3 and IA7 composites are exactly their unions" begin
        composites = ((IA_AorO, IA72IARelations(IA_AorO)), (IA_DorBorE, IA72IARelations(IA_DorBorE)),
            (IA_AiorOi, IA72IARelations(IA_AiorOi)), (IA_DiorBiorEi, IA72IARelations(IA_DiorBiorEi)),
            (IA_I, IA32IARelations(IA_I)))
        for (coarse, members) in composites, ws in _INTERVAL_WORLDS
            @test [(a, b) for a in ws for b in ws
                if relation_holds(coarse, a, b) != any(m -> relation_holds(m, a, b), members)] == []
        end
    end
end
