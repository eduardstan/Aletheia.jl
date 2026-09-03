import Base: join

# Semantic structures: truth algebras, frames, models, and atom interpretation.
# Formula syntax remains in syntax.jl; this file never turns a truth value into a
# Formula, nor does it evaluate a Branch.

"""Marker for values used as worlds in modal frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AbstractWorld"))
true
```
"""
abstract type AbstractWorld end
"""Abstract accessibility-frame vocabulary used by Sole consumers.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AbstractFrame"))
true
```
"""
abstract type AbstractFrame{W} end
"""Abstract frame with one implicit accessibility relation.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AbstractUniModalFrame"))
true
```
"""
abstract type AbstractUniModalFrame{W} <: AbstractFrame{W} end
"""Abstract frame with named accessibility relations.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AbstractMultiModalFrame"))
true
```
"""
abstract type AbstractMultiModalFrame{W} <: AbstractFrame{W} end
"""The SoleLogics world-set dispatch alias.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AbstractWorlds"))
true
```
"""
const AbstractWorlds{W} = AbstractVector{W} where {W<:AbstractWorld}
"""Marker used when a grounded formula is checked without choosing a world.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AnyWorld"))
true
```
"""
struct AnyWorld end

"""
    TruthAlgebra{T}

Interface for a truth algebra whose carrier type is `T`.  Implementations provide
`top`, `bottom`, lattice `meet`, `join`, monoid `fusion`, `implication`, and
`negation`.  Keeping `T` in
the type makes an interpretation's result type part of the model's type rather
than a `Union` of unrelated truth domains.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("TruthAlgebra"))
true
```
"""
abstract type TruthAlgebra{T} end

"""Return the carrier type `T` of a truth algebra."""
truth_type(::Type{<:TruthAlgebra{T}}) where T = T
"""Return the carrier type `T` of a truth algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("truth_type"))
true
```
"""
truth_type(algebra::TruthAlgebra) = truth_type(typeof(algebra))

"""Return the carrier representation of `algebra`.

Finite algebras return a tuple enumerating every carrier value.  The continuous
unit-interval chains return `(bottom, top)` as their finite bounds
representation; use the algebra's operations for the full interval.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("carrier"))
true
```
"""
carrier(algebra::TruthAlgebra) = domain(algebra)

"""ASCII alias for [`truth_type`](@ref)."""
truthtype(algebra) = truth_type(algebra)

"""Return the greatest truth value of `algebra`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("top"))
true
```
"""
function top(algebra::TruthAlgebra)
    throw(MethodError(top, (algebra,)))
end

"""Return the least truth value of `algebra`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("bottom"))
true
```
"""
function bottom(algebra::TruthAlgebra)
    throw(MethodError(bottom, (algebra,)))
end

"""Short alias for [`bottom`](@ref).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("bot"))
true
```
"""
bot(algebra::TruthAlgebra) = bottom(algebra)

"""Meet operation of `algebra`."""
function meet(algebra::TruthAlgebra, left, right)
    throw(MethodError(meet, (algebra, left, right)))
end

"""Monoid fusion operation of `algebra`."""
function fusion(algebra::TruthAlgebra, left, right)
    throw(MethodError(fusion, (algebra, left, right)))
end

"""Join operation of `algebra`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("join"))
true
```
"""
function join(algebra::TruthAlgebra, left, right)
    throw(MethodError(join, (algebra, left, right)))
end

"""Residual implication operation of `algebra`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("implication"))
true
```
"""
function implication(algebra::TruthAlgebra, left, right)
    throw(MethodError(implication, (algebra, left, right)))
end

"""Negation operation of `algebra`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("negation"))
true
```
"""
function negation(algebra::TruthAlgebra, value)
    throw(MethodError(negation, (algebra, value)))
end

"""Alias for [`implication`](@ref)."""
implies(algebra::TruthAlgebra, left, right) = implication(algebra, left, right)

"""Alias for [`negation`](@ref)."""
negate(algebra::TruthAlgebra, value) = negation(algebra, value)

"""
    BooleanAlgebra()

The two-element Boolean algebra, with carrier `Bool`: `top` is `true`,
`bottom` is `false`, meet/join are `&`/`|`, implication is `(!left) || right`,
and negation is `!value`.  These are the standard Boolean operations; see
Goranko, *Logic as a Tool*, §§1.1.2–1.1.5 (pp. 3–6) [goranko2016](@cite).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("BooleanAlgebra"))
true
```
"""
struct BooleanAlgebra <: TruthAlgebra{Bool} end

"""The standard Boolean truth algebra singleton.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("BOOLEAN"))
true
```
"""
const BOOLEAN = BooleanAlgebra()

truth_type(::Type{BooleanAlgebra}) = Bool
top(::BooleanAlgebra) = true
bottom(::BooleanAlgebra) = false
meet(::BooleanAlgebra, left::Bool, right::Bool) = left & right
fusion(::BooleanAlgebra, left::Bool, right::Bool) = left & right
join(::BooleanAlgebra, left::Bool, right::Bool) = left | right
implication(::BooleanAlgebra, left::Bool, right::Bool) = (!left) | right
negation(::BooleanAlgebra, value::Bool) = !value

@inline function _unit_value(value::Real)
    result = Float64(value)
    0.0 <= result <= 1.0 || throw(ArgumentError("truth values must lie in [0, 1]"))
    result
end

@inline function _chain_value(value::Real, n::Int)
    result = _unit_value(value)
    if n != 0
        step = 1.0 / (n - 1)
        # Floating-point chain levels are accepted within 8eps(Float64) of a
        # level, then canonicalized to that level.
        isapprox(result / step, round(result / step); atol=8eps(Float64)) ||
            throw(ArgumentError("truth value $result is not on the $n-element chain"))
        return round(result / step) * step
    end
    result
end

"""
    GodelAlgebra([n])

A Gödel chain with carrier `Float64`.  With no argument this is the standard
unit interval; `GodelAlgebra(n)` restricts values to the `n` equally spaced
members of that interval (`n ≥ 2`).  `top = 1`, `bottom = 0`, meet/join are `min`/`max`,
implication is `1` when `left ≤ right` and `right` otherwise,
and negation is `1` at `0` and `0` elsewhere.  Structurally, this is an
FL-algebra/residuated-lattice instance in the framework defined by Galatos et al.,
§2.2 (printed pp. 91–94), with the residuation law stated in the Introduction
(printed p. 2) [galatos2007](@cite). Galatos et al. explicitly leave specific
many-valued logics outside the book's scope (Introduction, printed p. 7)
[galatos2007](@cite), so this named Gödel table awaits a dedicated source.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("GodelAlgebra"))
true
```
"""
struct GodelAlgebra{N} <: TruthAlgebra{Float64}
    function GodelAlgebra{N}() where N
        N isa Integer && N >= 0 || throw(ArgumentError("chain size must be non-negative"))
        N == 1 && throw(ArgumentError("a finite chain must have at least two values"))
        new{N}()
    end
end

GodelAlgebra() = GodelAlgebra{0}()
function GodelAlgebra(n::Integer)
    n >= 2 || throw(ArgumentError("a finite chain must have at least two values"))
    GodelAlgebra{Int(n)}()
end

"""
    LukasiewiczAlgebra([n])

An Łukasiewicz chain with carrier `Float64`.  With no argument this is the
standard unit interval; `LukasiewiczAlgebra(n)` restricts values to the `n`
equally spaced members (`n ≥ 2`).  `top = 1`, `bottom = 0`, meet is `min`, fusion is the Łukasiewicz t-norm
`max(0, left + right - 1)`, join is `max`, implication is
`min(1, 1 - left + right)`, and negation is `1 - value`.  Structurally, this is
an FL-algebra/residuated-lattice instance in the framework defined by Galatos
et al., §2.2 (printed pp. 91–94), with the residuation law stated in the
Introduction (printed p. 2) [galatos2007](@cite). Galatos et al. explicitly leave
specific many-valued logics
outside the book's scope (Introduction, printed p. 7) [galatos2007](@cite), so
this named Łukasiewicz table awaits a dedicated source.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("LukasiewiczAlgebra"))
true
```
"""
struct LukasiewiczAlgebra{N} <: TruthAlgebra{Float64}
    function LukasiewiczAlgebra{N}() where N
        N isa Integer && N >= 0 || throw(ArgumentError("chain size must be non-negative"))
        N == 1 && throw(ArgumentError("a finite chain must have at least two values"))
        new{N}()
    end
end

LukasiewiczAlgebra() = LukasiewiczAlgebra{0}()
function LukasiewiczAlgebra(n::Integer)
    n >= 2 || throw(ArgumentError("a finite chain must have at least two values"))
    LukasiewiczAlgebra{Int(n)}()
end

# ASCII names are the stable API; these aliases keep the mathematical names
# discoverable without introducing another implementation.
const GodelChain = GodelAlgebra
const LukasiewiczChain = LukasiewiczAlgebra
const GödelAlgebra = GodelAlgebra
const ŁukasiewiczAlgebra = LukasiewiczAlgebra

truth_type(::Type{<:GodelAlgebra}) = Float64
truth_type(::Type{<:LukasiewiczAlgebra}) = Float64

@inline _godel_value(::GodelAlgebra{N}, value::Real) where N = _chain_value(value, N)
@inline _lukasiewicz_value(::LukasiewiczAlgebra{N}, value::Real) where N = _chain_value(value, N)
@inline function _snap_chain(value::Float64, n::Int)
    n == 0 && return value
    step = 1.0 / (n - 1)
    round(value / step) * step
end
@inline _lukasiewicz_result(::LukasiewiczAlgebra{N}, value::Float64) where N = _snap_chain(value, N)

top(::GodelAlgebra) = 1.0
bottom(::GodelAlgebra) = 0.0
meet(algebra::GodelAlgebra, left::Real, right::Real) = min(_godel_value(algebra, left), _godel_value(algebra, right))
fusion(algebra::GodelAlgebra, left::Real, right::Real) = min(_godel_value(algebra, left), _godel_value(algebra, right))
join(algebra::GodelAlgebra, left::Real, right::Real) = max(_godel_value(algebra, left), _godel_value(algebra, right))
function implication(algebra::GodelAlgebra, left::Real, right::Real)
    x, y = _godel_value(algebra, left), _godel_value(algebra, right)
    x <= y ? 1.0 : y
end
function negation(algebra::GodelAlgebra, value::Real)
    _godel_value(algebra, value) == 0.0 ? 1.0 : 0.0
end

top(::LukasiewiczAlgebra) = 1.0
bottom(::LukasiewiczAlgebra) = 0.0
meet(algebra::LukasiewiczAlgebra, left::Real, right::Real) =
    min(_lukasiewicz_value(algebra, left), _lukasiewicz_value(algebra, right))
function fusion(algebra::LukasiewiczAlgebra, left::Real, right::Real)
    x, y = _lukasiewicz_value(algebra, left), _lukasiewicz_value(algebra, right)
    _lukasiewicz_result(algebra, max(0.0, x + y - 1.0))
end
join(algebra::LukasiewiczAlgebra, left::Real, right::Real) = max(_lukasiewicz_value(algebra, left), _lukasiewicz_value(algebra, right))
function implication(algebra::LukasiewiczAlgebra, left::Real, right::Real)
    x, y = _lukasiewicz_value(algebra, left), _lukasiewicz_value(algebra, right)
    _lukasiewicz_result(algebra, min(1.0, 1.0 - x + y))
end
function negation(algebra::LukasiewiczAlgebra, value::Real)
    _lukasiewicz_result(algebra, 1.0 - _lukasiewicz_value(algebra, value))
end

"""Return the ordered finite levels of a chain algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("levels"))
true
```
"""
function levels(::Union{GodelAlgebra{N},LukasiewiczAlgebra{N}}) where N
    N == 0 && throw(ArgumentError("the unit-interval algebra has infinitely many levels"))
    (Float64(i) / (N - 1) for i in 0:(N - 1))
end

"""Return whether `algebra` is a finite chain rather than the unit interval."""
isfinitechain(::Union{GodelAlgebra{N},LukasiewiczAlgebra{N}}) where N = N != 0

"""Return the carrier values of `algebra`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("domain"))
true
```
"""
domain(::BooleanAlgebra) = (false, true)
domain(algebra::GodelAlgebra{0}) = (0.0, 1.0)
domain(algebra::LukasiewiczAlgebra{0}) = (0.0, 1.0)
domain(algebra::Union{GodelAlgebra,LukasiewiczAlgebra}) = Tuple(levels(algebra))

abstract type _RelationProvider end

# Relation adjacency is independent of valuation, so models that share a frame
# can share the lazily-built relation indexes as well.
struct _RelationAdjacency
    rows::Vector{Vector{Int}}
    columns::Vector{BitVector}
end

mutable struct _ModelEvaluationCache
    positions::Dict{Any,Int}
    adjacency::Dict{Any,_RelationAdjacency}
    lock::ReentrantLock
end

"""
    Frame(worlds, relations; index=false)

A relational frame in the sense of Blackburn, de Rijke, and Venema: an
ordered collection of worlds together with one accessibility relation per
relation name.  `relations` is normally a dictionary such as
`Dict(:G => Dict(:w1 => [:w2], :w2 => [:w2]))`.  The `worlds` collection is
stored in enumeration order, and `index=true` additionally stores a world to
position dictionary for algorithms that use stable positions.  A one-world
frame uses this same ordinary type; no propositional special case exists.
See Blackburn, de Rijke, and Venema, *Modal Logic*, §1.3 [blackburn2001](@cite).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("Frame"))
true
```
"""
struct Frame{W<:Tuple,RS,I} <: AbstractMultiModalFrame{eltype(W)}
    worlds::W
    relations::RS
    index::I
    cache::_ModelEvaluationCache
end

function _world_tuple(worlds)
    result = tuple(worlds...)
    isempty(result) && throw(ArgumentError("a frame must contain at least one world"))
    length(unique(result)) == length(result) || throw(ArgumentError("worlds must be unique"))
    result
end

function _world_index(worldtuple::Tuple, requested)
    requested === false && return nothing
    requested === nothing && return nothing
    if requested === true
        return Dict(world => position for (position, world) in enumerate(worldtuple))
    end
    requested isa AbstractDict || throw(ArgumentError("index must be false, true, or a dictionary"))
    result = Dict(requested)
    all(world -> haskey(result, world), worldtuple) || throw(ArgumentError("world index must contain every world"))
    positions = Int[]
    for world in worldtuple
        result[world] isa Integer || throw(ArgumentError("world index positions must be integers"))
        push!(positions, Int(result[world]))
    end
    sort!(positions) == collect(1:length(worldtuple)) ||
        throw(ArgumentError("world index positions must be a permutation of 1:length(worlds)"))
    result
end

@inline _is_world(worlds::Tuple, value) = any(world -> isequal(world, value), worlds)

function _targets(worlds::Tuple, target)
    _is_world(worlds, target) && return (target,)
    if target isa AbstractString || target isa Symbol || target isa Number || target isa Char
        return (target,)
    end
    try
        tuple(target...)
    catch
        (target,)
    end
end

function _check_targets(worlds::Tuple, source, targets)
    _is_world(worlds, source) || throw(ArgumentError("relation source $(repr(source)) is not a world"))
    result = _targets(worlds, targets)
    all(target -> _is_world(worlds, target), result) ||
        throw(ArgumentError("accessibility targets must be worlds"))
    result
end

function _edge_list(adjacency)
    adjacency isa AbstractVector || adjacency isa AbstractSet || return false
    all(edge -> edge isa Pair || (edge isa Tuple && length(edge) == 2), adjacency)
end

function _normalize_adjacency(adjacency, worlds::Tuple)
    if adjacency isa AbstractDict
        result = Dict{Any,Any}()
        for (source, targets) in adjacency
            result[source] = _check_targets(worlds, source, targets)
        end
        return result
    elseif adjacency isa Function || adjacency isa _RelationProvider
        return adjacency
    elseif _edge_list(adjacency)
        result = Dict{Any,Any}()
        for edge in adjacency
            source, target = edge isa Pair ? (edge.first, edge.second) : (edge[1], edge[2])
            existing = get(result, source, ())
            result[source] = (existing..., _check_targets(worlds, source, target)...)
        end
        return result
    else
        throw(ArgumentError("each accessibility relation must be a world map, function, or edge list"))
    end
end

function _normalize_relations(relations, worlds::Tuple)
    relations isa AbstractDict || relations isa Function || relations isa _RelationProvider ||
        throw(ArgumentError("relations must be a dictionary, function, or relation provider"))
    if relations isa Function || relations isa _RelationProvider
        return relations
    end
    result = Dict{Any,Any}()
    for (name, adjacency) in relations
        result[name] = _normalize_adjacency(adjacency, worlds)
    end
    result
end

function Frame(worlds, relations; index=false, world_index=nothing)
    worldtuple = _world_tuple(worlds)
    requested = world_index === nothing ? index : world_index
    normalized = _normalize_relations(relations, worldtuple)
    indexed = _world_index(worldtuple, requested)
    positions = indexed === nothing ?
        Dict{Any,Int}(world => position for (position, world) in enumerate(worldtuple)) :
        Dict{Any,Int}(world => Int(indexed[world]) for world in worldtuple)
    cache = _ModelEvaluationCache(positions, Dict{Any,_RelationAdjacency}(), ReentrantLock())
    Frame{typeof(worldtuple),typeof(normalized),typeof(indexed)}(
        worldtuple, normalized, indexed, cache)
end

Frame(worlds; index=false, world_index=nothing) = Frame(worlds, Dict(); index=index, world_index=world_index)
"""Return the worlds of a frame in stable enumeration order.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("worlds"))
true
```
"""
worlds(frame::Frame) = frame.worlds

"""Return the relation mapping stored by a frame.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("relations"))
true
```
"""
relations(frame::Frame) = frame.relations

"""Return the optional world-to-position index, or `nothing` when absent.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("world_index"))
true
```
"""
world_index(frame::Frame) = frame.index

"""Return whether a frame carries an explicit world-to-position index.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("hasworldindex"))
true
```
"""
hasworldindex(frame::Frame) = frame.index !== nothing

"""Return the stable position of `world`, using or building no allocation when indexed.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("world_position"))
true
```
"""
function world_position(frame::Frame, world)
    if frame.index !== nothing
        haskey(frame.index, world) || throw(KeyError(world))
        return frame.index[world]
    end
    position = findfirst(candidate -> isequal(candidate, world), frame.worlds)
    position === nothing && throw(KeyError(world))
    position
end

function _relation_targets(frame::Frame, world, relation_name)
    _is_world(frame.worlds, world) || throw(KeyError(world))
    _stored_relation_targets(frame, world, relation_name)
end

_has_stored_relation(frame::Frame, relation) =
    frame.relations isa AbstractDict && haskey(frame.relations, relation)

function _stored_relation_targets(frame::Frame, world, relation_name)
    stored = frame.relations
    if stored isa Function || stored isa _RelationProvider
        if applicable(stored, world, relation_name)
            return stored(world, relation_name)
        elseif applicable(stored, relation_name, world)
            return stored(relation_name, world)
        end
        throw(ArgumentError("accessibility function must accept (world, relation)"))
    end
    haskey(stored, relation_name) || return ()
    adjacency = stored[relation_name]
    if adjacency isa Function
        return adjacency(world)
    end
    haskey(adjacency, world) ? adjacency[world] : ()
end

"""
    accessible(frame, world, relation)

Return a lazy iterator over worlds accessible from `world` via `relation`.
No vector is allocated by this call; callers that need storage can explicitly
write `collect(accessible(frame, world, relation))`.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("accessible"))
true
```
"""
function accessible(frame::Frame, world, relation_name)
    targets = _relation_targets(frame, world, relation_name)
    targets isa AbstractString && return (target for target in (targets,))
    targets isa Nothing && throw(ArgumentError("accessibility must return an iterable"))
    (target for target in targets)
end

"""Return the lazy worlds accessible from `world` via `relation`."""
accessibles(frame::Frame, world, relation_name) = accessible(frame, world, relation_name)

# A lazy de-duplicating view.  The `seen` set is allocated per iteration pass,
# so the returned object stays re-iterable like any other lazy iterator.
struct _DistinctWorlds{S}
    source::S
end
Base.IteratorSize(::Type{<:_DistinctWorlds}) = Base.SizeUnknown()
Base.IteratorEltype(::Type{<:_DistinctWorlds}) = Base.EltypeUnknown()
Base.iterate(distinct::_DistinctWorlds) = _next_distinct(distinct, Set{Any}(), ())
Base.iterate(distinct::_DistinctWorlds, state) = _next_distinct(distinct, state[1], (state[2],))

function _next_distinct(distinct::_DistinctWorlds, seen, inner)
    while true
        step = iterate(distinct.source, inner...)
        step === nothing && return nothing
        value, inner_state = step
        inner = (inner_state,)
        value in seen && continue
        push!(seen, value)
        return value, (seen, inner_state)
    end
end

"""Return distinct worlds reachable from a world vector, lazily."""
function accessibles(frame::Frame, world_set::AbstractVector, relation_name)
    _DistinctWorlds((target for source in world_set for target in accessible(frame, source, relation_name)))
end

"""Return the worlds satisfying a Boolean connective from child extensions.

The result is a materialised world set, as in the SoleLogics collation API;
accessibility itself remains lazy and is only consumed by the modal predicates.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("collateworlds"))
true
```
"""
function collateworlds(frame::AbstractFrame, connective, truth_sets::Tuple)
    expected = arity(connective)
    length(truth_sets) == expected || throw(ArgumentError(
        "cannot collate $(length(truth_sets)) truth sets for $(typeof(connective)) with arity $expected"))
    frame_worlds = worlds(frame)
    if connective isa Conjunction
        return collect(intersect(truth_sets[1], truth_sets[2]))
    elseif connective isa Disjunction
        return collect(union(truth_sets[1], truth_sets[2]))
    elseif connective isa Implication
        return collect(union(setdiff(collect(frame_worlds), truth_sets[1]), truth_sets[2]))
    elseif connective isa Negation
        return collect(setdiff(collect(frame_worlds), truth_sets[1]))
    elseif connective isa Diamond
        relation_name = relation(connective)
        relation_name isa GlobalRelation && return isempty(truth_sets[1]) ? eltype(frame_worlds)[] : collect(frame_worlds)
        return [world for world in frame_worlds if any(target -> target in truth_sets[1],
            accessible(frame, world, relation_name))]
    elseif connective isa Box
        relation_name = relation(connective)
        relation_name isa GlobalRelation && return length(truth_sets[1]) == length(frame_worlds) ?
            collect(frame_worlds) : eltype(frame_worlds)[]
        return [world for world in frame_worlds if all(target -> target in truth_sets[1],
            accessible(frame, world, relation_name))]
    end
    throw(ArgumentError("no world collation for connective $(repr(connective))"))
end

Base.iterate(frame::Frame, state...) = iterate(frame.worlds, state...)
Base.length(frame::Frame) = length(frame.worlds)

Base.show(io::IO, frame::Frame) =
    print(io, "Frame(", length(frame.worlds), " world", length(frame.worlds) == 1 ? "" : "s", ")")

"""Print the `Worlds (n): …` line of a frame or model, bounded by the IO context."""
function _display_worlds(io::IO, frame::Frame)
    nw = length(frame.worlds)
    shown, elided = _display_bounded(io, frame.worlds, DISPLAY_ITEMS)
    _display_label(io, 2, "Worlds ($nw)")
    print(io, join(repr.(shown), ", "))
    _display_elision(io, elided)
end

"""Print the relation section of a frame or model, bounded by the IO context."""
function _display_relations(io::IO, frame::Frame)
    if !(frame.relations isa AbstractDict)
        _display_label(io, 2, "Relations")
        print(io, "<callable>")
        return
    end
    isempty(frame.relations) && return
    _display_label(io, 2, "Relations", ":")
    for (name, adj) in frame.relations
        _display_label(io, 4, repr(name))
        if !(adj isa AbstractDict)
            print(io, "<callable>")
            continue
        end
        edges = String[]
        for world in frame.worlds
            targets = _relation_targets(frame, world, name)
            isempty(targets) || push!(edges, "$(repr(world)) → $(join(repr.(targets), ", "))")
        end
        if isempty(edges)
            print(io, "(none)")
        else
            shown, elided = _display_bounded(io, edges, DISPLAY_ITEMS)
            print(io, join(shown, "; "))
            _display_elision(io, elided)
        end
    end
end

function Base.show(io::IO, ::MIME"text/plain", frame::Frame)
    nw = length(frame.worlds)
    relation_summary = if frame.relations isa AbstractDict
        nrel = length(frame.relations)
        "$nrel relation$(nrel == 1 ? "" : "s")"
    else
        "relations supplied on demand"
    end
    _display_header(io, "Frame", "$nw world$(nw == 1 ? "" : "s"), $relation_summary")
    _display_worlds(io, frame)
    _display_relations(io, frame)
end

"""
    Valuation(data)

A lightweight wrapper for a valuation.  `data` may be a function
`(atom_value, world) -> truth`, a dictionary keyed by `(atom_value, world)`, a
nested atom/world or world/atom dictionary, or a dictionary mapping atom values
to sets of worlds (the usual Boolean valuation presentation).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("Valuation"))
true
```
"""
struct Valuation{V}
    data::V
end

"""
    ValuationCallback(scalar; vectorized=nothing)

A valuation callback for models whose atom truth is computed on demand.  The
`scalar` callback receives `(atom, world)`.  An optional `vectorized` callback
receives `(atom, worlds)` and returns one value per world; the evaluator uses it
when computing an extension, while scalar interpretation remains available for
`check`.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("ValuationCallback"))
true
```
"""
struct ValuationCallback{S,B}
    scalar::S
    vectorized::B
end

ValuationCallback(scalar; vectorized=nothing) =
    ValuationCallback{typeof(scalar),typeof(vectorized)}(scalar, vectorized)

(valuation::ValuationCallback)(atom_value, world) = _owned_callback_value(valuation.scalar(atom_value, world))

function _nested_value(data, world)
    if data isa Function
        return data(world)
    elseif data isa AbstractSet
        return world in data
    elseif data isa AbstractDict
        haskey(data, world) || throw(KeyError(world))
        return data[world]
    elseif data isa Bool || data isa Real
        return data
    end
    try
        return data[world]
    catch error
        error isa KeyError && rethrow()
        error isa MethodError && return data
        throw(ArgumentError("valuation data is not indexed by worlds"))
    end
end

function _lookup_valuation(data::Valuation, atom_value, world)
    data(atom_value, world)
end

function _lookup_valuation(data::Function, atom_value, world)
    data(atom_value, world)
end

function _lookup_valuation(data::AbstractDict, atom_value, world)
    pair1 = (atom_value, world)
    pair2 = (world, atom_value)
    haskey(data, pair1) && return data[pair1]
    haskey(data, pair2) && return data[pair2]
    haskey(data, atom_value) && return _nested_value(data[atom_value], world)
    haskey(data, world) && return _nested_value(data[world], atom_value)
    throw(KeyError((atom_value, world)))
end

function _lookup_valuation(data, atom_value, world)
    try
        return data(atom_value, world)
    catch error
        error isa MethodError || rethrow()
        throw(ArgumentError("valuation must be callable or dictionary-like"))
    end
end

function _lookup_atom(data::AbstractDict, atom::Atom, world)
    pair1 = (atom, world)
    pair2 = (world, atom)
    haskey(data, pair1) && return data[pair1]
    haskey(data, pair2) && return data[pair2]
    haskey(data, atom) && return _nested_value(data[atom], world)
    if haskey(data, world)
        nested = data[world]
        nested isa AbstractDict && haskey(nested, atom) && return nested[atom]
        return _nested_value(nested, value(atom))
    end
    _lookup_valuation(data, value(atom), world)
end

function _lookup_atom(data::Valuation, atom::Atom, world)
    raw = data.data
    if raw isa AbstractDict
        if haskey(raw, atom) || haskey(raw, (atom, world)) || haskey(raw, (world, atom))
            return _lookup_valuation(data, atom, world)
        elseif haskey(raw, world)
            nested = raw[world]
            nested isa AbstractDict && haskey(nested, atom) && return nested[atom]
            return _nested_value(nested, value(atom))
        end
    end
    _lookup_valuation(data, value(atom), world)
end
_lookup_atom(data, atom::Atom, world) = _lookup_valuation(data, value(atom), world)
# Callback results belong to the evaluator. Copy mutable carriers so a
# callback may reuse an internal object without aliasing values across worlds.
_owned_callback_value(value) = isimmutable(value) ? value : deepcopy(value)
_lookup_atom(data::ValuationCallback, atom::Atom, world) = data(value(atom), world)

function (valuation::Valuation)(atom_value, world)
    _lookup_valuation(valuation.data, atom_value, world)
end

"""Return atom values in the supplied world order, using a batch callback when available.

The vector returned by a batch callback is consumed synchronously during formula
extension evaluation. Mutable carrier values are copied at this boundary, so
callbacks may reuse an internal buffer or value on the next call.
"""
function atom_values(valuation, atom::Atom, worlds)
    [ _lookup_atom(valuation, atom, world) for world in worlds ]
end

function atom_values(valuation::ValuationCallback, atom::Atom, worlds)
    batch = valuation.vectorized
    batch === nothing && return [valuation.scalar(value(atom), world) for world in worlds]
    result = batch(value(atom), worlds)
    values = result isa AbstractVector ? result : collect(result)
    [_owned_callback_value(value) for value in values]
end


"""
    Model(frame, algebra, valuation)

A model is a frame enriched by a valuation and a `TruthAlgebra`.  The algebra
is part of the model so Boolean, Gödel, and Łukasiewicz models all use exactly
the same interpretation path.  This is the many-valued analogue of the
frame-plus-valuation model of Blackburn, de Rijke, and Venema, *Modal Logic*,
§1.3 [blackburn2001](@cite).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("Model"))
true
```
"""
struct Model{T,A<:TruthAlgebra{T},F<:Frame,V}
    frame::F
    algebra::A
    valuation::V
    cache::_ModelEvaluationCache
end

function Model(frame::Frame, algebra::TruthAlgebra, valuation)
    Model(frame, algebra, valuation, frame.cache)
end


Model(frame::Frame, valuation::AbstractDict, algebra::TruthAlgebra) = Model(frame, algebra, valuation)
Model(frame::Frame, valuation::Function, algebra::TruthAlgebra) = Model(frame, algebra, valuation)
Model(frame::Frame, valuation::Valuation, algebra::TruthAlgebra) = Model(frame, algebra, valuation)
Model(frame::Frame, valuation; algebra::TruthAlgebra=BOOLEAN) = Model(frame, algebra, valuation)

"""Return the frame underlying `model`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("frame"))
true
```
"""
frame(model::Model) = model.frame

"""Return the truth algebra carried by `model`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("algebra"))
true
```
"""
algebra(model::Model) = model.algebra

"""Return the raw valuation carried by `model`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("valuation"))
true
```
"""
valuation(model::Model) = model.valuation

"""Forward [`accessible`](@ref) from a model to its underlying frame."""
accessible(model::Model, world, relation_name) = accessible(model.frame, world, relation_name)

function _check_world(frame::Frame, world)
    _is_world(frame.worlds, world) || throw(KeyError(world))
    world
end

@inline _validate_atom_value(::TruthAlgebra, value) = value
@inline _validate_atom_value(::Union{GodelAlgebra{N},LukasiewiczAlgebra{N}}, value::Float64) where N =
    _chain_value(value, N)

"""
    interpret(atom, model, world)

Interpret an **atom only** at `world`, returning exactly the carrier type of
`model`'s truth algebra.  Compound formulas are evaluated through [`check`](@ref)
and [`extension`](@ref), which consume the syntax DAG and apply these algebra
operations.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("interpret"))
true
```
"""
function interpret(atom::Atom, model::Model{T}, world)::T where T
    _check_world(model.frame, world)
    raw = _lookup_atom(model.valuation, atom, world)
    raw isa T || throw(ArgumentError("valuation returned $(typeof(raw)); expected $T"))
    _validate_atom_value(model.algebra, raw)
end

Base.show(io::IO, model::Model) =
    print(io, "Model(", length(frame(model).worlds), " world", length(frame(model).worlds) == 1 ? "" : "s", ", ", algebra(model), ")")

# Rich model headers use a reader-facing algebra description rather than
# exposing implementation parameters such as the unit-interval sentinel.
_model_algebra_summary(algebra) = sprint(show, algebra)

function _format_valuation_summary(val_data, worlds_tuple, fmt=string, limit::Int=typemax(Int))
    lines = String[]
    if val_data isa AbstractDict
        atom_map = Dict{Any, Dict{Any, Any}}()
        for (k, v) in val_data
            if k isa Tuple && length(k) == 2
                w1_idx = findfirst(w -> isequal(w, k[1]), worlds_tuple)
                w2_idx = findfirst(w -> isequal(w, k[2]), worlds_tuple)
                if w1_idx !== nothing && w2_idx === nothing
                    w, a = k[1], k[2]
                elseif w2_idx !== nothing && w1_idx === nothing
                    a, w = k[1], k[2]
                else
                    a, w = k[1], k[2]
                end
                get!(atom_map, a, Dict{Any,Any}())[w] = v
            elseif any(w -> isequal(w, k), worlds_tuple)
                if v isa AbstractDict
                    for (a, val) in v
                        get!(atom_map, a, Dict{Any,Any}())[k] = val
                    end
                end
            else
                a = k
                worlds_for_atom = get!(atom_map, a, Dict{Any,Any}())
                if v isa AbstractSet || v isa AbstractVector || v isa Tuple
                    for w in v
                        worlds_for_atom[w] = true
                    end
                elseif v isa AbstractDict
                    for (w, val) in v
                        worlds_for_atom[w] = val
                    end
                else
                    worlds_for_atom[:all] = v
                end
            end
        end

        for a in sort(collect(keys(atom_map)); by=string)
            wdict = atom_map[a]
            if all(v -> v === true, values(wdict))
                sat_worlds = [w for w in worlds_tuple if get(wdict, w, false) === true]
                if isempty(sat_worlds)
                    push!(lines, "$(a): {}")
                else
                    push!(lines, "$(a): {$(_join_bounded(repr.(sat_worlds), limit))}")
                end
            else
                parts = String[]
                for w in worlds_tuple
                    if haskey(wdict, w)
                        push!(parts, "$(repr(w)) => $(fmt(wdict[w]))")
                    end
                end
                if isempty(parts)
                    push!(lines, "$(a): {}")
                else
                    push!(lines, "$(a): {$(_join_bounded(parts, limit))}")
                end
            end
        end
    end
    lines
end

function Base.show(io::IO, ::MIME"text/plain", model::Model)
    f = frame(model)
    nw = length(f.worlds)
    alg = algebra(model)
    relation_summary = if f.relations isa AbstractDict
        nrel = length(f.relations)
        "$nrel relation$(nrel == 1 ? "" : "s")"
    else
        "relations supplied on demand"
    end
    _display_header(io, "Model", "$nw world$(nw == 1 ? "" : "s"), $relation_summary, $(_model_algebra_summary(alg))")
    _display_worlds(io, f)
    _display_relations(io, f)

    val = valuation(model)
    val_data = val isa Valuation ? val.data : val
    if val_data isa AbstractDict && !isempty(val_data)
        lines = _format_valuation_summary(val_data, f.worlds, value -> _display_truth(alg, value),
            _display_limit(io))
        shown, elided = _display_bounded(io, lines, DISPLAY_ITEMS)
        _display_label(io, 2, "Valuation", ":")
        for line in shown
            print(io, "\n    ", line)
        end
        _display_elision_line(io, 4, elided)
    elseif val_data isa Function
        _display_label(io, 2, "Valuation")
        print(io, "<function>")
    end
end
