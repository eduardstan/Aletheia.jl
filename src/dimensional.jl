# Immutable dimensional worlds and generated finite frames.

"""An interval `[left,right]` with `left < right`."""
struct Interval{T<:Real} <: AbstractWorld
    x::T
    y::T
    function Interval{T}(x::T, y::T) where {T<:Real}
        x < y || throw(ArgumentError("an interval requires left < right"))
        new{T}(x, y)
    end
end
Interval(x::T, y::T) where {T<:Real} = Interval{T}(x, y)

"""An immutable axis-aligned rectangle, represented by two intervals."""
struct Rectangle{T<:Real} <: AbstractWorld
    x::Interval{T}
    y::Interval{T}
end

"""A small immutable point value (provided for dimensional API compatibility)."""
struct Point <: AbstractWorld
    coordinates::Tuple
end
Point(x::T) where {T<:Real} = Point((x,))
Point(x::T, y::T) where {T<:Real} = Point((x, y))
Rectangle(x::Tuple{T,T}, y::Tuple{T,T}) where {T<:Real} = Rectangle(Interval(x...), Interval(y...))
const Interval2D = Rectangle

# A rectangle relation is a value carrying one relation for each axis.
struct RectangleRelation{X,Y} <: RelationFamily
    x::X
    y::Y
end
rectangle_relation(x, y) = RectangleRelation(x, y)
const CartesianRelation = RectangleRelation
relation_holds(r::RectangleRelation, a::Rectangle, b::Rectangle) =
    relation_holds(r.x, a.x, b.x) && relation_holds(r.y, a.y, b.y)
inverse(r::RectangleRelation) = RectangleRelation(inverse(r.x), inverse(r.y))
Base.show(io::IO, relation::RectangleRelation) = print(io, "rectangle-relation")
Base.isequal(a::RectangleRelation, b::RectangleRelation) = isequal(a.x, b.x) && isequal(a.y, b.y)
Base.:(==)(a::RectangleRelation, b::RectangleRelation) = a.x == b.x && a.y == b.y
Base.hash(r::RectangleRelation, h::UInt) = hash(r.y, hash(r.x, h))

Base.show(io::IO, interval::Interval) = print(io, "(", interval.x, "−", interval.y, ")")
Base.show(io::IO, rectangle::Rectangle) = print(io, "(", rectangle.x, "×", rectangle.y, ")")
Base.length(interval::Interval) = interval.y - interval.x
Base.length(rectangle::Rectangle) = length(rectangle.x) * length(rectangle.y)

# Endpoint tuples are accepted as bounded domains. For an integer n, n cells
# have n+1 boundaries, matching the conventional FullDimensionalFrame(n).
function _boundaries(domain::Integer)
    domain >= 1 || throw(ArgumentError("a dimensional domain must be positive"))
    collect(1:(Int(domain) + 1))
end
function _boundaries(domain::AbstractRange)
    values = collect(domain)
    length(values) >= 2 || throw(ArgumentError("a dimensional domain needs at least two boundaries"))
    issorted(values) && length(unique(values)) == length(values) ||
        throw(ArgumentError("dimensional boundaries must be strictly increasing"))
    values
end
function _boundaries(domain::AbstractVector)
    values = collect(domain)
    length(values) >= 2 || throw(ArgumentError("a dimensional domain needs at least two boundaries"))
    issorted(values) && length(unique(values)) == length(values) ||
        throw(ArgumentError("dimensional boundaries must be strictly increasing"))
    values
end

function _interval_worlds(boundaries)
    tuple((Interval(boundaries[i], boundaries[j]) for i in eachindex(boundaries)
        for j in (i + 1):length(boundaries))...)
end
function _point_worlds(domain)
    tuple(domain...)
end
function _rectangle_worlds(xboundaries, yboundaries)
    tuple((Rectangle(Interval(xboundaries[i], xboundaries[j]),
                     Interval(yboundaries[k], yboundaries[l]))
        for i in eachindex(xboundaries) for j in (i + 1):length(xboundaries)
        for k in eachindex(yboundaries) for l in (k + 1):length(yboundaries))...)
end

_world_values(worlds) = worlds isa AbstractVector ? worlds : collect(worlds)

function _interval_boundaries(worlds)
    first_world = first(worlds)
    values = [first_world.x, first_world.y]
    for world in Iterators.drop(worlds, 1)
        push!(values, world.x, world.y)
    end
    sort!(unique(values))
end
function _interval_world_index(left, right, n)
    (left - 1) * (2n - left) ÷ 2 + right - left
end
struct _IntervalSuccessors{W}
    worlds::W
    n::Int
    kfirst::Int
    klast::Int
    lfirst::Int
    llast::Int
    mode::UInt8
end
Base.eltype(::Type{_IntervalSuccessors{W}}) where W = eltype(W)
Base.IteratorSize(::Type{<:_IntervalSuccessors}) = Base.SizeUnknown()

function _interval_successors(worlds, n, kfirst, klast, lfirst, llast, mode)
    kfirst > klast || lfirst > llast ? () :
        _IntervalSuccessors(worlds, n, kfirst, klast, lfirst, llast, UInt8(mode))
end
function Base.iterate(iter::_IntervalSuccessors)
    k = iter.kfirst
    l = iter.mode == 0 || iter.mode == 3 ? k + 1 : iter.lfirst
    state = k * (iter.n + 1) + l
    iter.mode == 3 && k == iter.kfirst && l == iter.llast ?
        iterate(iter, (k + 1) * (iter.n + 1) + k + 2) :
        iter.mode == 4 && k == iter.klast && l == iter.lfirst ?
            iterate(iter, k * (iter.n + 1) + l + 1) : iterate(iter, state)
end
function Base.iterate(iter::_IntervalSuccessors, state::Int)
    base = iter.n + 1
    k = state ÷ base
    l = state - k * base
    (k > iter.klast || l > iter.llast) && return nothing
    if iter.mode == 3 && k == iter.kfirst && l == iter.llast
        return iterate(iter, (k + 1) * base + k + 2)
    elseif iter.mode == 4 && k == iter.klast && l == iter.lfirst
        return iterate(iter, k * base + l + 1)
    end
    value = iter.worlds[_interval_world_index(k, l, iter.n)]
    next = if iter.mode == 0 || iter.mode == 3
        l < iter.llast ? k * base + l + 1 : (k + 1) * base + k + 2
    elseif iter.mode == 1 || iter.mode == 4
        l < iter.llast ? k * base + l + 1 : (k + 1) * base + iter.lfirst
    else
        (k + 1) * base + l
    end
    value, next
end
@inline function _interval_before_successors(source::Interval, boundaries, worlds)
    right = searchsortedfirst(boundaries, source.y)
    first_left = right + 1
    n = length(boundaries)
    first_left >= n ? () : Iterators.drop(worlds, _interval_world_index(first_left, first_left + 1, n) - 1)
end

function _interval_relation_successors(relation, source::Interval, boundaries, worlds)
    left = searchsortedfirst(boundaries, source.x)
    right = searchsortedfirst(boundaries, source.y)
    n = length(boundaries)
    (left > n || right > n || !isequal(boundaries[left], source.x) ||
        !isequal(boundaries[right], source.y)) && return nothing
    if relation === IA_AorO
        return _interval_successors(worlds, n, left + 1, right, right + 1, n, 1)
    elseif relation === IA_DorBorE
        return _interval_successors(worlds, n, left, right - 1, 0, right, 3)
    elseif relation === IA_AiorOi
        return _interval_successors(worlds, n, 1, left - 1, left, right - 1, 1)
    elseif relation === IA_DiorBiorEi
        return _interval_successors(worlds, n, 1, left, right, n, 4)
    elseif relation === IA_I
        return (target for target in worlds if target.x <= source.y && source.x <= target.y &&
            (target.x != source.x || target.y != source.y))
    elseif relation === DC
        return Iterators.flatten((_interval_relation_successors(BEFORE, source, boundaries, worlds),
            _interval_relation_successors(AFTER, source, boundaries, worlds)))
    elseif relation === EC
        return Iterators.flatten((_interval_relation_successors(MEETS, source, boundaries, worlds),
            _interval_relation_successors(MET_BY, source, boundaries, worlds)))
    elseif relation === PO
        return Iterators.flatten((_interval_relation_successors(OVERLAPS, source, boundaries, worlds),
            _interval_relation_successors(OVERLAPPED_BY, source, boundaries, worlds)))
    elseif relation === TPP
        return Iterators.flatten((_interval_relation_successors(STARTS, source, boundaries, worlds),
            _interval_relation_successors(FINISHES, source, boundaries, worlds)))
    elseif relation === TPPi
        return Iterators.flatten((_interval_relation_successors(STARTED_BY, source, boundaries, worlds),
            _interval_relation_successors(FINISHED_BY, source, boundaries, worlds)))
    elseif relation === NTPP
        return _interval_relation_successors(DURING, source, boundaries, worlds)
    elseif relation === NTPPi
        return _interval_relation_successors(CONTAINS, source, boundaries, worlds)
    elseif relation === RCC_EQ
        return _interval_relation_successors(EQUALS, source, boundaries, worlds)
    elseif relation === Topo_DR
        # Mode 1 spans a full k x l block, so it may enter cells with l <= k
        # once lfirst <= klast; those map back to the preceding interval and
        # duplicate it. The targets at or after the source's right boundary
        # are the triangle l > k, which is exactly mode 0.
        return Iterators.flatten((_interval_successors(worlds, n, right, n - 1, right + 1, n, 0),
            _interval_successors(worlds, n, 1, left - 1, 0, left, 0)))
    elseif relation === Topo_PP
        return _interval_successors(worlds, n, 1, left, right, n, 4)
    elseif relation === Topo_PPi
        return _interval_successors(worlds, n, left, right - 1, 0, right, 3)
    elseif relation === BEFORE
        return _interval_before_successors(source, boundaries, worlds)
    elseif relation === MEETS
        return _interval_successors(worlds, n, right, right, right + 1, n, 1)
    elseif relation === OVERLAPS
        return _interval_successors(worlds, n, left + 1, right - 1, right + 1, n, 1)
    elseif relation === STARTS
        return _interval_successors(worlds, n, left, left, right + 1, n, 1)
    elseif relation === DURING
        return _interval_successors(worlds, n, 1, left - 1, right + 1, n, 1)
    elseif relation === FINISHES
        return _interval_successors(worlds, n, 1, left - 1, right, right, 2)
    elseif relation === EQUALS
        return (source,)
    elseif relation === AFTER
        return _interval_successors(worlds, n, 1, left - 2, 0, left - 1, 0)
    elseif relation === MET_BY
        return _interval_successors(worlds, n, 1, left - 1, left, left, 2)
    elseif relation === OVERLAPPED_BY
        return _interval_successors(worlds, n, 1, left - 1, left + 1, right - 1, 1)
    elseif relation === STARTED_BY
        return _interval_successors(worlds, n, left, left, left + 1, right - 1, 1)
    elseif relation === CONTAINS
        return _interval_successors(worlds, n, left + 1, right - 2, 0, right - 1, 0)
    elseif relation === FINISHED_BY
        return _interval_successors(worlds, n, left + 1, right - 1, right, right, 2)
    end
    nothing
end

function _canonical_interval_values(values, boundaries)
    canonical = _interval_worlds(boundaries)
    length(values) == length(canonical) && all(isequal.(values, canonical))
end
function relation_successors(::BeforeRelation, source::Interval, worlds)
    values = _world_values(worlds)
    boundaries = _interval_boundaries(values)
    _canonical_interval_values(values, boundaries) ?
        _interval_before_successors(source, boundaries, values) :
        (target for target in worlds if relation_holds(BEFORE, source, target))
end
function relation_successors(relation::IntervalRelation, source::Interval, worlds)
    values = _world_values(worlds)
    boundaries = _interval_boundaries(values)
    _canonical_interval_values(values, boundaries) ||
        return (target for target in worlds if relation_holds(relation, source, target))
    targets = _interval_relation_successors(relation, source, boundaries, values)
    targets === nothing ? (target for target in worlds if relation_holds(relation, source, target)) : targets
end
function relation_successors(relation::RCCRelation, source::Interval, worlds)
    values = _world_values(worlds)
    boundaries = _interval_boundaries(values)
    _canonical_interval_values(values, boundaries) ||
        return (target for target in worlds if relation_holds(relation, source, target))
    targets = _interval_relation_successors(relation, source, boundaries, values)
    targets === nothing ? (target for target in worlds if relation_holds(relation, source, target)) : targets
end

# Bounded-domain point dispatch. A user-defined relation uses the public
# three-argument predicate by default, while built-in point relations can use
# the finite world domain through the four-argument protocol.
function _point_relation_holds(relation::PointRelation, source, target, worlds)
    relation_holds(relation, source, target, worlds)
end

@inline _point_position(source, worlds) = findfirst(value -> isequal(value, source), worlds)
relation_holds(::MinimumRelation, source, target, worlds) =
    !isempty(worlds) && _point_position(source, worlds) !== nothing && isequal(target, first(worlds))
relation_holds(::MaximumRelation, source, target, worlds) =
    !isempty(worlds) && _point_position(source, worlds) !== nothing && isequal(target, last(worlds))
function relation_holds(::SuccessorRelation, source, target, worlds)
    position = _point_position(source, worlds)
    position !== nothing && position < length(worlds) && isequal(target, worlds[position + 1])
end
function relation_holds(::PredecessorRelation, source, target, worlds)
    position = _point_position(source, worlds)
    position !== nothing && position > 1 && isequal(target, worlds[position - 1])
end
function relation_holds(::GreaterRelation, source, target, worlds)
    source_position, target_position = _point_position(source, worlds), _point_position(target, worlds)
    source_position !== nothing && target_position !== nothing && target_position > source_position
end
function relation_holds(::LesserRelation, source, target, worlds)
    source_position, target_position = _point_position(source, worlds), _point_position(target, worlds)
    source_position !== nothing && target_position !== nothing && target_position < source_position
end
function _dimensional_relation_holds(relation, source, target, worlds)
    relation_holds(relation, source, target, worlds)
end

# Optional arithmetic successor paths for generated point frames. A family that
# does not define relation_successors falls through to the generic predicate.
relation_successors(::IdentityRelation, source, worlds) = (source,)
relation_successors(::MinimumRelation, source, worlds) = (first(worlds),)
relation_successors(::MaximumRelation, source, worlds) = (last(worlds),)
function relation_successors(::SuccessorRelation, source, worlds)
    position = findfirst(value -> isequal(value, source), worlds)
    position === nothing || position == length(worlds) ? () : (worlds[position + 1],)
end
function relation_successors(::PredecessorRelation, source, worlds)
    position = findfirst(value -> isequal(value, source), worlds)
    position === nothing || position == 1 ? () : (worlds[position - 1],)
end
function relation_successors(::GreaterRelation, source, worlds)
    position = findfirst(value -> isequal(value, source), worlds)
    position === nothing ? () : Iterators.drop(worlds, position)
end
function relation_successors(::LesserRelation, source, worlds)
    position = findfirst(value -> isequal(value, source), worlds)
    position === nothing ? () : Iterators.take(worlds, position - 1)
end
function relation_successors(relation::Point2DRelation, source, worlds)
    (target for target in worlds if relation_holds(relation, source, target))
end

# RCC8 of rectangles is determined by the two axis projections. A DC axis
# separates interiors, an EC axis gives boundary-only contact, and the
# remaining cases are decided by proper containment and interior overlap.
function _rectangle_contains(a::Rectangle, b::Rectangle)
    _contains_interval(a.x, b.x) && _contains_interval(a.y, b.y)
end
function _rectangle_proper_subset(a::Rectangle, b::Rectangle)
    _rectangle_contains(b, a) && !isequal(a, b)
end
function relation_holds(::DisconnectedRelation, a::Rectangle, b::Rectangle)
    relation_holds(DC, a.x, b.x) || relation_holds(DC, a.y, b.y)
end
function relation_holds(::ExternallyConnectedRelation, a::Rectangle, b::Rectangle)
    !relation_holds(DC, a, b) &&
        (relation_holds(EC, a.x, b.x) || relation_holds(EC, a.y, b.y)) &&
        !_rectangle_contains(a, b) && !_rectangle_contains(b, a)
end
function relation_holds(::RCCEqualsRelation, a::Rectangle, b::Rectangle)
    isequal(a, b)
end
function relation_holds(::TangentialProperPartRelation, a::Rectangle, b::Rectangle)
    _rectangle_proper_subset(a, b) &&
        (a.x.x == b.x.x || a.x.y == b.x.y || a.y.x == b.y.x || a.y.y == b.y.y)
end
relation_holds(::TangentialProperPartInverseRelation, a::Rectangle, b::Rectangle) = relation_holds(TPP, b, a)
function relation_holds(::NonTangentialProperPartRelation, a::Rectangle, b::Rectangle)
    _rectangle_proper_subset(a, b) && a.x.x > b.x.x && a.x.y < b.x.y && a.y.x > b.y.x && a.y.y < b.y.y
end
relation_holds(::NonTangentialProperPartInverseRelation, a::Rectangle, b::Rectangle) = relation_holds(NTPP, b, a)
function relation_holds(::PartiallyOverlappingRelation, a::Rectangle, b::Rectangle)
    !relation_holds(DC, a, b) && !relation_holds(EC, a, b) &&
        !_rectangle_contains(a, b) && !_rectangle_contains(b, a) && !isequal(a, b)
end

@inline _interval_disconnected(a::Interval, b::Interval) = a.y < b.x || b.y < a.x
@inline _interval_touching(a::Interval, b::Interval) = a.y == b.x || b.y == a.x
@inline _rectangle_contains_axes(ax, ay, bx, by) =
    ax.x <= bx.x && bx.y <= ax.y && ay.x <= by.x && by.y <= ay.y
@inline _rectangle_equal_axes(ax, ay, bx, by) = ax.x == bx.x && ax.y == bx.y &&
    ay.x == by.x && ay.y == by.y
function _rectangle_rcc_holds(relation::RCCRelation, ax, ay, bx, by)
    disconnected = _interval_disconnected(ax, bx) || _interval_disconnected(ay, by)
    equal = _rectangle_equal_axes(ax, ay, bx, by)
    acontainsb = _rectangle_contains_axes(ax, ay, bx, by)
    bcontainsa = _rectangle_contains_axes(bx, by, ax, ay)
    apropersubsetb = bcontainsa && !equal
    bpropersubseta = acontainsb && !equal
    externally_connected = !disconnected && (_interval_touching(ax, bx) || _interval_touching(ay, by)) &&
        !acontainsb && !bcontainsa
    relation === Topo_DR ? disconnected || externally_connected :
    relation === Topo_PP ? (bcontainsa && !equal) :
    relation === Topo_PPi ? (acontainsb && !equal) :
    relation === DC ? disconnected :
    relation === EC ? externally_connected :
    relation === RCC_EQ ? equal :
    relation === TPP ? apropersubsetb &&
        (ax.x == bx.x || ax.y == bx.y || ay.x == by.x || ay.y == by.y) :
    relation === TPPi ? bpropersubseta &&
        (bx.x == ax.x || bx.y == ax.y || by.x == ay.x || by.y == ay.y) :
    relation === NTPP ? apropersubsetb && ax.x > bx.x && ax.y < bx.y &&
        ay.x > by.x && ay.y < by.y :
    relation === NTPPi ? bpropersubseta && bx.x > ax.x && bx.y < ax.y &&
        by.x > ay.x && by.y < ay.y :
    relation === PO ? !disconnected && !externally_connected &&
        !acontainsb && !bcontainsa && !equal : false
end
function _rectangle_rcc_successors(relation::RCCRelation, source, xworlds, yworlds)
    Iterators.flatten(((Rectangle(x, y) for y in yworlds
        if _rectangle_rcc_holds(relation, source.x, source.y, x, y)) for x in xworlds))
end
function relation_successors(relation::RCCRelation, source::Rectangle, worlds)
    (target for target in worlds if relation_holds(relation, source, target))
end

function _rectangle_relation_successors(relation::RectangleRelation, source, xb, yb, xworlds, yworlds)
    xsuccessors = _interval_relation_successors(relation.x, source.x, xb, xworlds)
    xsuccessors === nothing && (xsuccessors = relation_successors(relation.x, source.x, xworlds))
    ysuccessors = _interval_relation_successors(relation.y, source.y, yb, yworlds)
    ysuccessors === nothing && (ysuccessors = relation_successors(relation.y, source.y, yworlds))
    (xsuccessors === nothing || ysuccessors === nothing) && return nothing
    Iterators.flatten(((Rectangle(x, y) for y in ysuccessors) for x in xsuccessors))
end
function relation_successors(relation::RectangleRelation, source::Rectangle, worlds)
    world_values = _world_values(worlds)
    xvalues = tuple((world.x for world in world_values)...)
    yvalues = tuple((world.y for world in world_values)...)
    xb, yb = _interval_boundaries(xvalues), _interval_boundaries(yvalues)
    _rectangle_relation_successors(relation, source, xb, yb, collect(_interval_worlds(xb)),
        collect(_interval_worlds(yb)))
end

struct _IntervalRelationMap{B,W,T} <: _RelationProvider
    boundaries::B
    world_values::W
    worlds::T
    canonical_index::Bool
end

function (provider::_IntervalRelationMap)(source, relation)
    targets = relation === BEFORE ? _interval_before_successors(source, provider.boundaries, provider.world_values) :
        _interval_relation_successors(relation, source, provider.boundaries, provider.world_values)
    targets === nothing && (targets = relation_successors(relation, source, provider.worlds))
    targets === nothing &&
        (targets = (target for target in provider.worlds if _dimensional_relation_holds(relation, source, target, provider.worlds)))
    targets
end

function _interval_relation_adjacency(frame, provider::_IntervalRelationMap, relation, positions)
    relation === BEFORE || return nothing
    provider.canonical_index || return nothing
    frame_worlds = frame.worlds
    world_count = length(frame_worlds)
    boundary_count = length(provider.boundaries)
    rows = Vector{Vector{Int}}(undef, world_count)
    columns = [falses(world_count) for _ in 1:world_count]
    for (source_position, source) in enumerate(frame_worlds)
        right = searchsortedfirst(provider.boundaries, source.y)
        first_left = right + 1
        if first_left >= boundary_count
            rows[source_position] = Int[]
            continue
        end
        first_target = _interval_world_index(first_left, first_left + 1, boundary_count)
        targets = first_target:world_count
        rows[source_position] = collect(targets)
        for target_position in targets
            columns[target_position][source_position] = true
        end
    end
    _RelationAdjacency(rows, columns)
end

"""Build a one-dimensional interval frame over `domain`."""
function interval_frame(domain; index=true)
    boundaries = _boundaries(domain)
    ws = _interval_worlds(boundaries)
    world_values = collect(ws)
    relation_map = _IntervalRelationMap(boundaries, world_values, ws, !(index isa AbstractDict))
    Frame(ws, relation_map; index=index)
end

"""Build a two-dimensional rectangle frame over `x` and `y` domains."""
function rectangle_frame(x, y=x; index=true)
    xb, yb = _boundaries(x), _boundaries(y)
    ws = _rectangle_worlds(xb, yb)
    xworlds, yworlds = collect(_interval_worlds(xb)), collect(_interval_worlds(yb))
    relation_map = (source, relation) -> begin
        targets = relation isa RectangleRelation ?
            _rectangle_relation_successors(relation, source, xb, yb, xworlds, yworlds) :
            relation isa RCCRelation ? _rectangle_rcc_successors(relation, source, xworlds, yworlds) : nothing
        targets === nothing && (targets = relation_successors(relation, source, ws))
        targets === nothing &&
            (targets = (target for target in ws if _dimensional_relation_holds(relation, source, target, ws)))
        targets
    end
    Frame(ws, relation_map; index=index)
end

"""Build a point frame over a finite linear-order domain (1D) or grid domain (2D)."""
function point_frame(domain, ydomain=nothing; index=true)
    if ydomain === nothing
        values = domain isa Integer ? collect(1:Int(domain)) : collect(domain)
        isempty(values) && throw(ArgumentError("a point domain must be non-empty"))
        issorted(values) && length(unique(values)) == length(values) ||
            throw(ArgumentError("point values must be strictly increasing"))
        ws = tuple(values...)
    else
        xvalues = domain isa Integer ? collect(1:Int(domain)) : collect(domain)
        yvalues = ydomain isa Integer ? collect(1:Int(ydomain)) : collect(ydomain)
        (isempty(xvalues) || isempty(yvalues)) && throw(ArgumentError("a point domain must be non-empty"))
        (issorted(xvalues) && length(unique(xvalues)) == length(xvalues)) ||
            throw(ArgumentError("point values must be strictly increasing"))
        (issorted(yvalues) && length(unique(yvalues)) == length(yvalues)) ||
            throw(ArgumentError("point values must be strictly increasing"))
        ws = tuple((Point(x, y) for x in xvalues for y in yvalues)...)
    end
    relation_map = (source, relation) -> begin
        targets = relation_successors(relation, source, ws)
        targets === nothing &&
            (targets = (target for target in ws if _dimensional_relation_holds(relation, source, target, ws)))
        targets
    end
    Frame(ws, relation_map; index=index)
end

"""Compatibility constructor for generated 0D/1D/2D frames.

`world_type` may be `Interval`, `Rectangle`/`Interval2D`, or `Point`.
The returned object is the ordinary `Frame`; no evaluator special case exists.
"""
function FullDimensionalFrame(channelsize::Tuple, world_type=nothing; index=true)
    length(channelsize) in (1, 2) || throw(ArgumentError("only one- and two-dimensional frames are supported"))
    if length(channelsize) == 1
        world_type === nothing && (world_type = Interval)
        world_type === Point && return point_frame(channelsize[1]; index=index)
        world_type <: Point && return point_frame(channelsize[1]; index=index)
        world_type <: Interval || throw(ArgumentError("one-dimensional worlds must be Interval or Point"))
        return interval_frame(channelsize[1]; index=index)
    end
    world_type === nothing && (world_type = Rectangle)
    if world_type === Point || world_type <: Point
        return point_frame(channelsize[1], channelsize[2]; index=index)
    end
    world_type === Rectangle || world_type === Interval2D || world_type <: Rectangle ||
        throw(ArgumentError("two-dimensional worlds must be Rectangle"))
    rectangle_frame(channelsize[1], channelsize[2]; index=index)
end
FullDimensionalFrame(n::Integer; kwargs...) = FullDimensionalFrame((n,), Interval; kwargs...)
FullDimensionalFrame(n::Integer, m::Integer; kwargs...) = FullDimensionalFrame((n, m), Rectangle; kwargs...)
Full1DFrame(n::Integer; kwargs...) = interval_frame(n; kwargs...)
Full2DFrame(n::Integer, m::Integer; kwargs...) = rectangle_frame(n, m; kwargs...)
Full1DPointFrame(n::Integer; kwargs...) = point_frame(n; kwargs...)
Full2DPointFrame(n::Integer, m::Integer; kwargs...) = point_frame(n, m; kwargs...)

# Frame vocabulary corresponding to SoleLogics' dimensional defaults.  These
# methods intentionally inspect the generated world values rather than add a
# second frame representation.
function emptyworld(frame::AbstractMultiModalFrame)
    error("Please, provide method emptyworld(::$(typeof(frame))).")
end
function centralworld(frame::AbstractMultiModalFrame)
    error("Please, provide method centralworld(::$(typeof(frame))).")
end

function emptyworld(frame::Frame)
    frame_worlds = worlds(frame)
    isempty(frame_worlds) && throw(ArgumentError("a frame must contain at least one world"))
    sample = first(frame_worlds)
    sample isa Interval && return Interval(-1, 0)
    sample isa Point && return length(sample.coordinates) == 1 ? Point(-1) : Point(-1, -1)
    sample isa Real && return -one(sample)
    sample isa Rectangle && return Rectangle(Interval(-1, 0), Interval(-1, 0))
    throw(MethodError(emptyworld, (frame,)))
end

function _central_interval(frame_worlds, axis::Symbol)
    endpoints = if axis === :x
        collect(value for world in frame_worlds for value in (world.x, world.y))
    else
        collect(value for world in frame_worlds for value in (world.x, world.y))
    end
    low = minimum(endpoints)
    high = maximum(endpoints)
    n = high - low
    left = low + div(n + 1, 2) - 1
    Interval(left, left + 1 + (isodd(n) ? 0 : 1))
end

function centralworld(frame::Frame)
    frame_worlds = worlds(frame)
    isempty(frame_worlds) && throw(ArgumentError("a frame must contain at least one world"))
    sample = first(frame_worlds)
    if sample isa Interval
        return _central_interval(frame_worlds, :x)
    elseif sample isa Real
        values = sort(collect(frame_worlds))
        return values[div(length(values) + 1, 2)]
    elseif sample isa Point
        coordinates = first(frame_worlds).coordinates
        length(coordinates) == 1 && return Point(sort(collect(w.coordinates[1] for w in frame_worlds))[div(length(frame_worlds) + 1, 2)])
        xs = sort(unique(w.coordinates[1] for w in frame_worlds))
        ys = sort(unique(w.coordinates[2] for w in frame_worlds))
        return Point(xs[div(length(xs) + 1, 2)], ys[div(length(ys) + 1, 2)])
    elseif sample isa Rectangle
        return Rectangle(_central_interval(tuple((w.x for w in frame_worlds)...), :x),
            _central_interval(tuple((w.y for w in frame_worlds)...), :x))
    end
    throw(MethodError(centralworld, (frame,)))
end
