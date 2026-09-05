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
    slots::Tuple
end
function _field_typejoin(entries::Tuple, field::Symbol, fallback=Any)
    isempty(entries) && return fallback
    return reduce(typejoin, (typeof(getproperty(entry, field)) for entry in entries))
end
function _frozen_dict_slots(entries::Tuple)
    isempty(entries) && return ()
    capacity = nextpow(2, 2 * length(entries))
    slots = zeros(Int, capacity)
    for (entry_index, entry) in enumerate(entries)
        slot = Int(mod(hash(entry.first), UInt(capacity))) + 1
        while slots[slot] != 0
            slot = mod1(slot + 1, capacity)
        end
        slots[slot] = entry_index
    end
    return tuple(slots...)
end
function FrozenDict{K,V}(entries::Tuple) where {K,V}
    return FrozenDict{K,V}(entries, _frozen_dict_slots(entries))
end
FrozenDict{K,V}() where {K,V} = FrozenDict{K,V}(())
function FrozenDict(entries::Tuple)
    isempty(entries) && return FrozenDict{Any,Any}(entries)
    return FrozenDict{_field_typejoin(entries, :first),_field_typejoin(entries, :second)}(
        entries
    )
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
function _frozen_dict_entry(value::FrozenDict, key)
    isempty(value.slots) && return 0
    slot = Int(mod(hash(key), UInt(length(value.slots)))) + 1
    for _ in eachindex(value.slots)
        entry_index = value.slots[slot]
        entry_index == 0 && return 0
        isequal(value.entries[entry_index].first, key) && return entry_index
        slot = mod1(slot + 1, length(value.slots))
    end
    return 0
end
Base.haskey(value::FrozenDict, key) = _frozen_dict_entry(value, key) != 0
function Base.get(value::FrozenDict, key, default)
    entry_index = _frozen_dict_entry(value, key)
    return entry_index == 0 ? default : value.entries[entry_index].second
end
function Base.getindex(value::FrozenDict, key)
    entry_index = _frozen_dict_entry(value, key)
    entry_index == 0 && throw(KeyError(key))
    return value.entries[entry_index].second
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

function _frozen_set_slots(values::Tuple)
    isempty(values) && return ()
    capacity = nextpow(2, 2 * length(values))
    slots = zeros(Int, capacity)
    for (value_index, value) in enumerate(values)
        slot = Int(mod(hash(value), UInt(capacity))) + 1
        while slots[slot] != 0
            slot = mod1(slot + 1, capacity)
        end
        slots[slot] = value_index
    end
    return tuple(slots...)
end

"""An immutable set snapshot used in certified public values."""
struct FrozenSet{T} <: AbstractSet{T}
    values::Tuple
    slots::Tuple
    function FrozenSet{T}(values::Tuple) where {T}
        return new{T}(values, _frozen_set_slots(values))
    end
end
function FrozenSet(values::Tuple)
    isempty(values) && return FrozenSet{Any}(values)
    return FrozenSet{eltype(values)}(values)
end
Base.length(value::FrozenSet) = length(value.values)
Base.iterate(value::FrozenSet, state...) = iterate(value.values, state...)
function _frozen_set_entry(value::FrozenSet, item)
    isempty(value.slots) && return 0
    slot = Int(mod(hash(item), UInt(length(value.slots)))) + 1
    for _ in eachindex(value.slots)
        value_index = value.slots[slot]
        value_index == 0 && return 0
        isequal(value.values[value_index], item) && return value_index
        slot = mod1(slot + 1, length(value.slots))
    end
    return 0
end
Base.in(item, value::FrozenSet) = _frozen_set_entry(value, item) != 0
function Base.:(==)(left::FrozenSet, right::FrozenSet)
    return length(left) == length(right) && all(item -> item in right, left)
end
function Base.:(==)(left::FrozenSet, right::AbstractSet)
    return length(left) == length(right) && all(item -> item in right, left)
end
Base.:(==)(left::AbstractSet, right::FrozenSet) = right == left

"""Raised when a mutable opaque value crosses an owned semantic boundary."""
struct OwnershipError <: Exception
    value_type::DataType
    path::Tuple
    requirement::String
end
OwnershipError(value) = OwnershipError(typeof(value), (), "semantic values must be structurally immutable")
OwnershipError(value, path::Tuple) = OwnershipError(typeof(value), path, "semantic values must be structurally immutable")
OwnershipError(value, path::Tuple, requirement::String) =
    OwnershipError(typeof(value), path, requirement)

function _ownership_path(path::Tuple)
    isempty(path) && return "<root>"
    return join((part isa Symbol ? ".$(part)" : string(part) for part in path), "")
end
function Base.showerror(io::IO, error::OwnershipError)
    return print(
        io,
        "ownership contract violated by value of type ",
        error.value_type,
        " at path ",
        _ownership_path(error.path),
        "; ",
        error.requirement,
    )
end

# This is the single ownership predicate used by constructors and structural
# tests.  Caches are implementation state, not semantic payload; a method for
# their type is added next to its definition in semantics.jl.
function _is_owned(value, seen=IdDict{Any,Bool}())
    T = typeof(value)
    isbitstype(T) && return true
    value isa FrozenArray && return all(_is_owned(x, seen) for x in value.data)
    value isa FrozenDict && return all(_is_owned(x, seen) for pair in value for x in pair)
    value isa FrozenSet && return all(_is_owned(x, seen) for x in value)
    value isa Tuple && return all(_is_owned(x, seen) for x in value)
    (value isa AbstractArray || value isa AbstractDict || value isa AbstractSet) && return false
    Base.ismutabletype(T) && return false
    fieldcount(T) == 0 && return true
    haskey(seen, value) && return true
    seen[value] = true
    try
        return all(
            _is_owned(getfield(value, field), seen) for
            (field, _name, _type) in zip(1:fieldcount(T), fieldnames(T), fieldtypes(T))
        )
    finally
        delete!(seen, value)
    end
end

# The single recursive snapshot used at every owned semantic boundary.  It
# snapshots standard collections and rebuilds immutable wrappers when their
# fields can accept the resulting owned values; otherwise it reports the
# offending leaf and its field path.
function _lookup_equivalent(left, right)
    try
        return isequal(left, right) && hash(left) == hash(right)
    catch
        return false
    end
end

function _immutable_copy(value, path::Tuple, seen::IdDict{Any,Bool})
    _is_owned(value) && return value
    T = typeof(value)
    Base.ismutabletype(T) && throw(OwnershipError(value, path))
    fieldcount(T) == 0 && return value
    haskey(seen, value) && throw(OwnershipError(value, path))
    seen[value] = true
    try
        fields = Any[]
        changed = false
        for (field, name, _type) in zip(1:fieldcount(T), fieldnames(T), fieldtypes(T))
            original = getfield(value, field)
            owned = _immutable_copy(original, (path..., name), seen)
            push!(fields, owned)
            changed |= owned !== original
        end
        !changed && return value
        candidate = try
            T(fields...)
        catch
            # The collection was snapshot-able, but the enclosing opaque type
            # cannot retain the replacement without changing its field type.
            nothing
        end
        if candidate !== nothing && _is_owned(candidate)
            _lookup_equivalent(value, candidate) || throw(
                OwnershipError(
                    value,
                    path,
                    "snapshot would change lookup identity; define == and hash for this type or pass owned fields",
                ),
            )
            return candidate
        end
        for (field_number, name) in zip(1:fieldcount(T), fieldnames(T))
            original = getfield(value, field_number)
            owned = fields[field_number]
            owned !== original && throw(OwnershipError(original, (path..., name)))
        end
        throw(OwnershipError(value, path))
    finally
        delete!(seen, value)
    end
end

function _immutable_copy(value::Tuple, path::Tuple, seen::IdDict{Any,Bool})
    return tuple((_immutable_copy(x, (path..., i), seen) for (i, x) in enumerate(value))...)
end
function _immutable_copy(value::NamedTuple{N}, path::Tuple, seen::IdDict{Any,Bool}) where {N}
    return NamedTuple{N}(tuple((_immutable_copy(x, (path..., name), seen) for (name, x) in zip(N, values(value)))...))
end
function _immutable_copy(value::AbstractArray, path::Tuple, seen::IdDict{Any,Bool})
    items = tuple((_immutable_copy(x, (path..., i), seen) for (i, x) in enumerate(value))...)
    T = isempty(items) ? eltype(value) : eltype(items)
    return FrozenArray{T,ndims(value)}(items, size(value))
end
function _immutable_copy(value::AbstractDict, path::Tuple, seen::IdDict{Any,Bool})
    items = tuple((
        _immutable_copy(k, (path..., "{key}"), seen) =>
        _immutable_copy(v, (path..., "[$(repr(k))]"), seen) for (k, v) in value
    )...)
    K = _field_typejoin(items, :first, keytype(value))
    V = _field_typejoin(items, :second, valtype(value))
    return FrozenDict{K,V}(items)
end
function _immutable_copy(value::AbstractSet, path::Tuple, seen::IdDict{Any,Bool})
    items = tuple((_immutable_copy(x, (path..., "{item}"), seen) for x in value)...)
    T = isempty(items) ? eltype(value) : eltype(items)
    return FrozenSet{T}(items)
end
function _immutable_copy(value::FrozenArray, path::Tuple, seen::IdDict{Any,Bool})
    items = tuple((_immutable_copy(x, (path..., i), seen) for (i, x) in enumerate(value))...)
    return items == value.data ? value : FrozenArray{eltype(items),ndims(value)}(items, size(value))
end
function _immutable_copy(value::FrozenDict, path::Tuple, seen::IdDict{Any,Bool})
    items = tuple((_immutable_copy(k, (path..., "{key}"), seen) => _immutable_copy(v, (path..., "[$(repr(k))]"), seen) for (k, v) in value)...)
    return items == value.entries ? value : FrozenDict(items)
end
function _immutable_copy(value::FrozenSet, path::Tuple, seen::IdDict{Any,Bool})
    items = tuple((_immutable_copy(x, (path..., "{item}"), seen) for x in value)...)
    return items == value.values ? value : FrozenSet(items)
end
_immutable_copy(value) = _immutable_copy(value, (), IdDict{Any,Bool}())

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
    AbstractFrame,
    OwnershipError
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
