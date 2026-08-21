# Immutable dimensional worlds and generated finite frames.

"""An interval `[left,right]` with `left < right`."""
struct Interval{T<:Real}
    x::T
    y::T
    function Interval{T}(x::T, y::T) where {T<:Real}
        x < y || throw(ArgumentError("an interval requires left < right"))
        new{T}(x, y)
    end
end
Interval(x::T, y::T) where {T<:Real} = Interval{T}(x, y)

"""An immutable axis-aligned rectangle, represented by two intervals."""
struct Rectangle{T<:Real}
    x::Interval{T}
    y::Interval{T}
end

"""A small immutable point value (provided for dimensional API compatibility)."""
struct Point
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
    l = iter.mode == 0 ? k + 1 : iter.lfirst
    iterate(iter, k * (iter.n + 1) + l)
end
function Base.iterate(iter::_IntervalSuccessors, state::Int)
    base = iter.n + 1
    k = state ÷ base
    l = state - k * base
    (k > iter.klast || l > iter.llast) && return nothing
    value = iter.worlds[_interval_world_index(k, l, iter.n)]
    next = if iter.mode == 0
        l < iter.llast ? k * base + l + 1 : (k + 1) * base + k + 2
    elseif iter.mode == 1
        l < iter.llast ? k * base + l + 1 : (k + 1) * base + iter.lfirst
    else
        (k + 1) * base + l
    end
    value, next
end
function _interval_relation_successors(relation, source::Interval, boundaries, worlds)
    left = searchsortedfirst(boundaries, source.x)
    right = searchsortedfirst(boundaries, source.y)
    n = length(boundaries)
    (left > n || right > n || !isequal(boundaries[left], source.x) ||
        !isequal(boundaries[right], source.y)) && return nothing
    if relation === BEFORE
        return (target for target in worlds if target.x > source.y)
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

function relation_successors(::BeforeRelation, source::Interval, worlds)
    (target for target in worlds if target.x > source.y)
end
function relation_successors(relation::IntervalRelation, source::Interval, worlds)
    world_values = _world_values(worlds)
    _interval_relation_successors(relation, source, _interval_boundaries(world_values), world_values)
end

# Bounded-domain point dispatch. A user-defined relation uses the public
# relation_holds method directly and is therefore independent of this file.
function _point_relation_holds(relation::PointRelation, source, target, worlds)
    relation_holds(relation, source, target)
end
function _dimensional_relation_holds(relation, source, target, worlds)
    relation isa PointRelation ? _point_relation_holds(relation, source, target, worlds) :
        relation_holds(relation, source, target)
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
    world_values = _world_values(worlds)
    xvalues = tuple((world.x for world in world_values)...)
    yvalues = tuple((world.y for world in world_values)...)
    xb, yb = _interval_boundaries(xvalues), _interval_boundaries(yvalues)
    _rectangle_rcc_successors(relation, source, collect(_interval_worlds(xb)),
        collect(_interval_worlds(yb)))
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

"""Build a one-dimensional interval frame over `domain`."""
function interval_frame(domain; index=true)
    boundaries = _boundaries(domain)
    ws = _interval_worlds(boundaries)
    world_values = collect(ws)
    relation_map = (source, relation) -> begin
        targets = relation === BEFORE ?
            relation_successors(relation, source, world_values) :
            _interval_relation_successors(relation, source, boundaries, world_values)
        targets === nothing && (targets = relation_successors(relation, source, ws))
        targets === nothing &&
            (targets = (target for target in ws if _dimensional_relation_holds(relation, source, target, ws)))
        targets
    end
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

