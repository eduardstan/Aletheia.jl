import Base: join

# Semantic structures: truth algebras, frames, models, and atom interpretation.
# Formula syntax remains in syntax.jl; this file never turns a truth value into a
# Formula, nor does it evaluate a Branch.

"""
    TruthAlgebra{T}

Interface for a truth algebra whose carrier is `T`.  Implementations provide
`top`, `bottom`, `meet`, `join`, `implication`, and `negation`.  Keeping `T` in
the type makes an interpretation's result type part of the model's type rather
than a `Union` of unrelated truth domains.
"""
abstract type TruthAlgebra{T} end

"""Return the carrier type `T` of a truth algebra."""
truth_type(::Type{<:TruthAlgebra{T}}) where T = T
truth_type(algebra::TruthAlgebra) = truth_type(typeof(algebra))

"""Return the carrier type of `algebra` (an alias for [`truth_type`](@ref))."""
carrier(algebra::TruthAlgebra) = truth_type(algebra)

"""ASCII alias for [`truth_type`](@ref)."""
truthtype(algebra) = truth_type(algebra)

"""Return the greatest truth value of `algebra`."""
function top(algebra::TruthAlgebra)
    throw(MethodError(top, (algebra,)))
end

"""Return the least truth value of `algebra`."""
function bottom(algebra::TruthAlgebra)
    throw(MethodError(bottom, (algebra,)))
end

"""Short alias for [`bottom`](@ref)."""
bot(algebra::TruthAlgebra) = bottom(algebra)

"""Meet operation of `algebra`."""
function meet(algebra::TruthAlgebra, left, right)
    throw(MethodError(meet, (algebra, left, right)))
end

"""Join operation of `algebra`."""
function join(algebra::TruthAlgebra, left, right)
    throw(MethodError(join, (algebra, left, right)))
end

"""Residual implication operation of `algebra`."""
function implication(algebra::TruthAlgebra, left, right)
    throw(MethodError(implication, (algebra, left, right)))
end

"""Negation operation of `algebra`."""
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
Goranko, *Logic as a Tool* [goranko2016](@cite).
"""
struct BooleanAlgebra <: TruthAlgebra{Bool} end

const BOOLEAN = BooleanAlgebra()

truth_type(::Type{BooleanAlgebra}) = Bool
top(::BooleanAlgebra) = true
bottom(::BooleanAlgebra) = false
meet(::BooleanAlgebra, left::Bool, right::Bool) = left & right
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
and negation is `1` at `0` and `0` elsewhere.  This is the Gödel residuated
chain operation; see Goranko, *Logic as a Tool* [goranko2016](@cite).
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
equally spaced members (`n ≥ 2`).  `top = 1`, `bottom = 0`, meet is the Łukasiewicz t-norm
`max(0, left + right - 1)`, join is `max`, implication is
`min(1, 1 - left + right)`, and negation is `1 - value`.  These are the standard Łukasiewicz operations; see Goranko,
*Logic as a Tool* [goranko2016](@cite).
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
function meet(algebra::LukasiewiczAlgebra, left::Real, right::Real)
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

"""Return the ordered finite levels of a chain algebra."""
function levels(::Union{GodelAlgebra{N},LukasiewiczAlgebra{N}}) where N
    N == 0 && throw(ArgumentError("the unit-interval algebra has infinitely many levels"))
    (Float64(i) / (N - 1) for i in 0:(N - 1))
end

"""Return whether `algebra` is a finite chain rather than the unit interval."""
isfinitechain(::Union{GodelAlgebra{N},LukasiewiczAlgebra{N}}) where N = N != 0

"""Return the finite carrier values, or the `(bottom, top)` interval bounds."""
domain(::BooleanAlgebra) = (false, true)
domain(algebra::GodelAlgebra{0}) = (0.0, 1.0)
domain(algebra::LukasiewiczAlgebra{0}) = (0.0, 1.0)
domain(algebra::Union{GodelAlgebra,LukasiewiczAlgebra}) = Tuple(levels(algebra))

abstract type _RelationProvider end

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
"""
struct Frame{W<:Tuple,RS,I}
    worlds::W
    relations::RS
    index::I
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
    Frame{typeof(worldtuple),typeof(normalized),typeof(indexed)}(worldtuple, normalized, indexed)
end

Frame(worlds; index=false, world_index=nothing) = Frame(worlds, Dict(); index=index, world_index=world_index)
"""Return the worlds of a frame in stable enumeration order."""
worlds(frame::Frame) = frame.worlds

"""Return the relation mapping stored by a frame."""
relations(frame::Frame) = frame.relations

"""Return the optional world-to-position index, or `nothing` when absent."""
world_index(frame::Frame) = frame.index

"""Return whether a frame carries an explicit world-to-position index."""
hasworldindex(frame::Frame) = frame.index !== nothing

"""Return the stable position of `world`, using or building no allocation when indexed."""
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
"""
function accessible(frame::Frame, world, relation_name)
    targets = _relation_targets(frame, world, relation_name)
    targets isa AbstractString && return (target for target in (targets,))
    targets isa Nothing && throw(ArgumentError("accessibility must return an iterable"))
    (target for target in targets)
end

Base.iterate(frame::Frame, state...) = iterate(frame.worlds, state...)
Base.length(frame::Frame) = length(frame.worlds)

"""
    Valuation(data)

A lightweight wrapper for a valuation.  `data` may be a function
`(atom_value, world) -> truth`, a dictionary keyed by `(atom_value, world)`, a
nested atom/world or world/atom dictionary, or a dictionary mapping atom values
to sets of worlds (the usual Boolean valuation presentation).
"""
struct Valuation{V}
    data::V
end

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

function (valuation::Valuation)(atom_value, world)
    _lookup_valuation(valuation.data, atom_value, world)
end

struct _RelationAdjacency
    rows::Vector{Vector{Int}}
    columns::Vector{BitVector}
end

mutable struct _ModelEvaluationCache
    positions::Dict{Any,Int}
    adjacency::Dict{Any,_RelationAdjacency}
    lock::ReentrantLock
end

function _model_positions(frame::Frame)
    indexed = world_index(frame)
    indexed === nothing ?
        Dict{Any,Int}(world => position for (position, world) in enumerate(worlds(frame))) :
        Dict{Any,Int}(world => Int(indexed[world]) for world in worlds(frame))
end

"""
    Model(frame, algebra, valuation)

A model is a frame enriched by a valuation and a `TruthAlgebra`.  The algebra
is part of the model so Boolean, Gödel, and Łukasiewicz models all use exactly
the same interpretation path.  This is the many-valued analogue of the
frame-plus-valuation model of Blackburn, de Rijke, and Venema, *Modal Logic*,
§1.3 [blackburn2001](@cite).
"""
struct Model{T,A<:TruthAlgebra{T},F<:Frame,V}
    frame::F
    algebra::A
    valuation::V
    cache::_ModelEvaluationCache
end

function Model(frame::Frame, algebra::TruthAlgebra, valuation)
    cache = _ModelEvaluationCache(_model_positions(frame), Dict{Any,_RelationAdjacency}(), ReentrantLock())
    Model(frame, algebra, valuation, cache)
end


Model(frame::Frame, valuation::AbstractDict, algebra::TruthAlgebra) = Model(frame, algebra, valuation)
Model(frame::Frame, valuation::Function, algebra::TruthAlgebra) = Model(frame, algebra, valuation)
Model(frame::Frame, valuation::Valuation, algebra::TruthAlgebra) = Model(frame, algebra, valuation)
Model(frame::Frame, valuation; algebra::TruthAlgebra=BOOLEAN) = Model(frame, algebra, valuation)

"""Return the frame underlying `model`."""
frame(model::Model) = model.frame

"""Return the truth algebra carried by `model`."""
algebra(model::Model) = model.algebra

"""Return the raw valuation carried by `model`."""
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
"""
function interpret(atom::Atom, model::Model{T}, world)::T where T
    _check_world(model.frame, world)
    raw = _lookup_atom(model.valuation, atom, world)
    raw isa T || throw(ArgumentError("valuation returned $(typeof(raw)); expected $T"))
    _validate_atom_value(model.algebra, raw)
end
