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

# Bounded-domain point dispatch. A user-defined relation uses the public
# relation_holds method directly and is therefore independent of this file.
function _point_relation_holds(relation::MinimumRelation, source, target, worlds)
    isequal(target, first(worlds))
end
function _point_relation_holds(relation::MaximumRelation, source, target, worlds)
    isequal(target, last(worlds))
end
function _point_relation_holds(::SuccessorRelation, source, target, worlds)
    position = findfirst(value -> isequal(value, source), worlds)
    position !== nothing && position < length(worlds) && isequal(worlds[position + 1], target)
end
function _point_relation_holds(::PredecessorRelation, source, target, worlds)
    position = findfirst(value -> isequal(value, source), worlds)
    position !== nothing && position > 1 && isequal(worlds[position - 1], target)
end
function _point_relation_holds(::GreaterRelation, source, target, worlds)
    source_position = findfirst(value -> isequal(value, source), worlds)
    target_position = findfirst(value -> isequal(value, target), worlds)
    source_position !== nothing && target_position !== nothing && target_position > source_position
end
function _point_relation_holds(::LesserRelation, source, target, worlds)
    source_position = findfirst(value -> isequal(value, source), worlds)
    target_position = findfirst(value -> isequal(value, target), worlds)
    source_position !== nothing && target_position !== nothing && target_position < source_position
end
function _point_relation_holds(relation::PointRelation, source, target, worlds)
    relation_holds(relation, source, target)
end
function _dimensional_relation_holds(relation, source, target, worlds)
    relation isa PointRelation ? _point_relation_holds(relation, source, target, worlds) :
        relation_holds(relation, source, target)
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

"""Build a one-dimensional interval frame over `domain`."""
function interval_frame(domain; index=true)
    boundaries = _boundaries(domain)
    ws = _interval_worlds(boundaries)
    relation_map = (source, relation) ->
        (target for target in ws if _dimensional_relation_holds(relation, source, target, ws))
    Frame(ws, relation_map; index=index)
end

"""Build a two-dimensional rectangle frame over `x` and `y` domains."""
function rectangle_frame(x, y=x; index=true)
    xb, yb = _boundaries(x), _boundaries(y)
    ws = _rectangle_worlds(xb, yb)
    relation_map = (source, relation) ->
        (target for target in ws if _dimensional_relation_holds(relation, source, target, ws))
    Frame(ws, relation_map; index=index)
end

"""Build a point frame over a finite linear-order domain."""
function point_frame(domain; index=true)
    values = domain isa Integer ? collect(1:Int(domain)) : collect(domain)
    isempty(values) && throw(ArgumentError("a point domain must be non-empty"))
    issorted(values) && length(unique(values)) == length(values) ||
        throw(ArgumentError("point values must be strictly increasing"))
    ws = tuple(values...)
    relation_map = (source, relation) ->
        (target for target in ws if _dimensional_relation_holds(relation, source, target, ws))
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
    world_type === Rectangle || world_type === Interval2D || world_type <: Rectangle ||
        throw(ArgumentError("two-dimensional worlds must be Rectangle"))
    rectangle_frame(channelsize[1], channelsize[2]; index=index)
end
FullDimensionalFrame(n::Integer; kwargs...) = FullDimensionalFrame((n,), Interval; kwargs...)
FullDimensionalFrame(n::Integer, m::Integer; kwargs...) = FullDimensionalFrame((n, m), Rectangle; kwargs...)
Full1DFrame(n::Integer; kwargs...) = interval_frame(n; kwargs...)
Full2DFrame(n::Integer, m::Integer; kwargs...) = rectangle_frame(n, m; kwargs...)
Full1DPointFrame(n::Integer; kwargs...) = point_frame(n; kwargs...)
Full2DPointFrame(n::Integer, m::Integer; kwargs...) = throw(ArgumentError("two-dimensional point frames are not part of the dimensional interval API"))
