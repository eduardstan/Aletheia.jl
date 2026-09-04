"""Dependency-free syntax and semantic foundations for Aletheia."""
module AletheiaCore

"""An immutable array snapshot used in certified public values."""
struct FrozenArray{T,N} <: AbstractArray{T,N}
    data::Tuple
    dims::NTuple{N,Int}
end
function FrozenArray(data::Tuple, dims::NTuple{N,Int}) where {N}
    return FrozenArray{eltype(data),N}(data, dims)
end
Base.size(value::FrozenArray) = value.dims
Base.IndexStyle(::Type{<:FrozenArray}) = IndexLinear()
Base.length(value::FrozenArray) = length(value.data)
Base.getindex(value::FrozenArray, i::Int) = value.data[i]
function Base.getindex(value::FrozenArray, I...)
    all(i -> i isa Integer || i isa CartesianIndex, I) &&
        return value.data[LinearIndices(value.dims)[I...]]
    return Array(value)[I...]
end
Base.Array(value::FrozenArray) = reshape(collect(value.data), value.dims)
Base.collect(value::FrozenArray) = Array(value)
function Base.:(==)(left::FrozenArray, right::FrozenArray)
    return size(left) == size(right) &&
           all(isequal(left[i], right[i]) for i in eachindex(left))
end
function Base.:(==)(left::FrozenArray, right::AbstractArray)
    return size(left) == size(right) &&
           all(isequal(left[i], right[i]) for i in eachindex(left))
end
Base.:(==)(left::AbstractArray, right::FrozenArray) = right == left

"""An immutable dictionary snapshot used in certified public values."""
struct FrozenDict{K,V} <: AbstractDict{K,V}
    entries::Tuple
end
function _field_typejoin(entries::Tuple, field::Symbol, fallback=Any)
    isempty(entries) && return fallback
    return reduce(typejoin, (typeof(getproperty(entry, field)) for entry in entries))
end
function FrozenDict(entries::Tuple)
    isempty(entries) && return FrozenDict{Any,Any}(entries)
    return FrozenDict{
        _field_typejoin(entries, :first),
        _field_typejoin(entries, :second),
    }(entries)
end
function FrozenDict{K,V}(entries::FrozenDict) where {K,V}
    return FrozenDict{K,V}(
        tuple((convert(K, entry.first) => convert(V, entry.second) for entry in entries)...)
    )
end
Base.length(value::FrozenDict) = length(value.entries)
Base.iterate(value::FrozenDict, state...) = iterate(value.entries, state...)
Base.keys(value::FrozenDict) = (entry.first for entry in value.entries)
Base.values(value::FrozenDict) = (entry.second for entry in value.entries)
Base.haskey(value::FrozenDict, key) = any(entry -> isequal(entry.first, key), value.entries)
Base.get(value::FrozenDict, key, default) = haskey(value, key) ? value[key] : default
function Base.getindex(value::FrozenDict, key)
    for entry in value.entries
        isequal(entry.first, key) && return entry.second
    end
    return throw(KeyError(key))
end
function Base.:(==)(left::FrozenDict, right::FrozenDict)
    return length(left) == length(right) &&
           all(haskey(right, p.first) && isequal(right[p.first], p.second) for p in left)
end
function Base.:(==)(left::FrozenDict, right::AbstractDict)
    return length(left) == length(right) &&
           all(haskey(right, p.first) && isequal(right[p.first], p.second) for p in left)
end
Base.:(==)(left::AbstractDict, right::FrozenDict) = right == left

"""An immutable set snapshot used in certified public values."""
struct FrozenSet{T} <: AbstractSet{T}
    values::Tuple
end
function FrozenSet(values::Tuple)
    isempty(values) && return FrozenSet{Any}(values)
    return FrozenSet{eltype(values)}(values)
end
Base.length(value::FrozenSet) = length(value.values)
Base.iterate(value::FrozenSet, state...) = iterate(value.values, state...)
Base.in(item, value::FrozenSet) = any(isequal(item, x) for x in value.values)

_immutable_copy(value::Function) = value
_immutable_copy(value::FrozenArray) = value
_immutable_copy(value::FrozenDict) = value
_immutable_copy(value::FrozenSet) = value
_immutable_copy(value::Tuple) = tuple((_immutable_copy(x) for x in value)...)
function _immutable_copy(value::NamedTuple{N}) where {N}
    return NamedTuple{N}((_immutable_copy(x) for x in values(value)))
end
function _immutable_copy(value::AbstractArray)
    items = tuple((_immutable_copy(x) for x in value)...)
    T = isempty(items) ? eltype(value) : eltype(items)
    return FrozenArray{T,ndims(value)}(items, size(value))
end
function _immutable_copy(value::AbstractDict)
    items = tuple((_immutable_copy(k) => _immutable_copy(v) for (k, v) in value)...)
    K = _field_typejoin(items, :first, keytype(value))
    V = _field_typejoin(items, :second, valtype(value))
    return FrozenDict{K,V}(items)
end
function _immutable_copy(value::AbstractSet)
    items = tuple((_immutable_copy(x) for x in value)...)
    T = isempty(items) ? eltype(value) : eltype(items)
    return FrozenSet{T}(items)
end
_immutable_copy(value) = value

# Defensive copies are mutable snapshots for compatibility with callers that
# intentionally edit a returned value. Internal certified fields use
# `_immutable_copy` instead.
_boundary_copy(value::FrozenArray) = map(_boundary_copy, Array(value))
function _boundary_copy(value::FrozenDict)
    return Dict{Any,Any}(
        _boundary_copy(pair.first) => _boundary_copy(pair.second) for pair in value
    )
end
_boundary_copy(value::FrozenSet) = Set(_boundary_copy(x) for x in value)
_boundary_copy(value::Tuple) = tuple((_boundary_copy(x) for x in value)...)
_boundary_copy(value) = value isa Function ? value : deepcopy(value)

include("syntax.jl")
include("parse.jl")
include("display.jl")
include("semantics.jl")
include("algebras.jl")
include("relations.jl")
include("dimensional.jl")
include("frameclasses.jl")
include("evaluation.jl")
include("firstorder.jl")
include("normalforms.jl")
include("bisimulation.jl")
include("prover.jl")

export Signature,
    Formula,
    FormulaPool,
    Atom,
    Branch,
    DEFAULT_SIGNATURE,
    DEFAULT_POOL,
    atom,
    branch,
    children,
    nchildren,
    value
export operator,
    head,
    pool,
    id,
    isatom,
    isbranch,
    dag,
    subterms,
    nsubterms,
    signature,
    connectives,
    arity
export dual,
    hasconnective,
    hasdual,
    precedence,
    associativity,
    iscommutative,
    ismodal,
    isunary,
    isdiamond,
    isbox,
    isgrounded,
    notation
export relation,
    syntaxstring,
    AbstractRelationalConnective,
    Negation,
    Conjunction,
    Fusion,
    Disjunction,
    Implication,
    Diamond,
    Box,
    NEGATION,
    CONJUNCTION
export FUSION,
    DISJUNCTION,
    IMPLICATION,
    ¬,
    ∧,
    ⊗,
    ∨,
    →,
    TruthAlgebra,
    BooleanAlgebra,
    GodelAlgebra,
    LukasiewiczAlgebra
export FiniteTruth,
    FiniteFLewAlgebra, BooleanFLewAlgebra, G3, G4, G5, G6, Ł3, Ł4, H4, H6, H6_1
export H6_2,
    H6_3,
    H9,
    RelationFamily,
    IntervalRelation,
    PointRelation,
    RCCRelation,
    RectangleRelation,
    relation_holds,
    relation_successors,
    inverse,
    converse
export rectangle_relation,
    globalrel,
    identityrel,
    GlobalRelation,
    IdentityRelation,
    AtWorldRelation,
    ToCenterRelation,
    tocenterrel,
    centralworld,
    emptyworld,
    isgrounding,
    Interval
export Rectangle,
    Point,
    interval_frame,
    rectangle_frame,
    point_frame,
    BEFORE,
    MEETS,
    OVERLAPS,
    STARTS,
    DURING,
    FINISHES,
    EQUALS
export AFTER,
    MET_BY,
    OVERLAPPED_BY,
    STARTED_BY,
    CONTAINS,
    FINISHED_BY,
    ALLEN_RELATIONS,
    IDENTITY,
    MINIMUM,
    MAXIMUM,
    SUCCESSOR,
    PREDECESSOR
export GREATER,
    LESSER, POINT_RELATIONS, DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ, RCC8_RELATIONS
export RCC8_BASICS,
    DR, PP, PPi, RCC5_RELATIONS, RCC5Relation, FrameClass, K, T, S4, S5, REFLEXIVE
export TRANSITIVE,
    SYMMETRIC,
    SERIAL,
    isreflexive,
    istransitive,
    issymmetric,
    isserial,
    reflexive,
    transitive,
    symmetric,
    serial,
    satisfies
export axioms,
    axiom, validates, BOOLEAN, truth_type, carrier, top, bottom, bot, meet, join, fusion
export domain,
    implication,
    negation,
    levels,
    isfinitechain,
    precedeq,
    precedes,
    succeedeq,
    succeeds,
    maximalmembers,
    minimalmembers,
    AbstractFrame
export AbstractUniModalFrame,
    AbstractMultiModalFrame,
    AbstractWorld,
    AbstractWorlds,
    AnyWorld,
    Frame,
    worlds,
    relations,
    hasworldindex,
    world_position,
    accessible,
    collateworlds
export check,
    extension,
    describe,
    EvaluationCache,
    clear!,
    Valuation,
    Model,
    frame,
    algebra,
    valuation,
    interpret,
    FirstOrderTerm
export FirstOrderFormula,
    Variable,
    Constant,
    FunctionTerm,
    Predicate,
    Equality,
    FONegation,
    FOConjunction,
    FODisjunction,
    FOImplication,
    Exists,
    Forall
export FirstOrderInterpretation,
    evaluate,
    standard_translation,
    first_order_interpretation,
    iscnf,
    isdnf,
    to_cnf,
    to_dnf,
    bisimilar,
    BisimulationClass,
    BisimulationContraction,
    QuotientModel
export bisimulation_contraction,
    contraction_world,
    model,
    classes,
    world_map,
    AbstractProver,
    ProverResult,
    PropositionalProver,
    FiniteModelProver,
    BoundedFiniteProver,
    prove,
    prove_valid
export prove_entails, issatisfiable, isvalid, entails

@doc """Return whether the left finite truth value succeeds or equals the right value.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("succeedeq"))
true
```
""" succeedeq

@doc """Clear all extensions retained by an [`EvaluationCache`](@ref).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("clear!"))
true
```
""" clear!

@doc """The prefix negation connective (`¬`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ¬
¬
```
""" var"¬"

@doc """The conjunction connective (`∧`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ∧
∧
```
""" var"∧"

@doc """The fusion connective (`⊗`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ⊗
⊗
```
""" var"⊗"

@doc """The disjunction connective (`∨`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ∨
∨
```
""" var"∨"

@doc """The implication connective (`→`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> →
→
```
""" var"→"
end
