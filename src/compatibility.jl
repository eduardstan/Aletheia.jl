# Compatibility vocabulary for consumers migrating from SoleLogics.
#
# This module is deliberately nested: `using Aletheia.SoleLogics` imports the
# incumbent spellings without adding them to Aletheia's own namespace.
"""
    Aletheia.SoleLogics

Opt-in vocabulary adapters for consumers migrating from SoleLogics. The
module keeps incumbent names out of Aletheia's top-level namespace and raises
explicit errors for concepts with no faithful equivalent.
"""
module SoleLogics

import ..Aletheia

const children = Aletheia.children
const value = Aletheia.value
const arity = Aletheia.arity
const hasdual = Aletheia.hasdual
const dual = Aletheia.dual
const relation = Aletheia.relation

"""An error-producing marker for an old API with no faithful Aletheia value.

The symbol is a type parameter so every marker has a distinct dispatch type.
That matters for consumers which define one method per legacy relation name.
"""
struct _UnsupportedName{Name} end
Base.show(io::IO, ::_UnsupportedName{Name}) where Name =
    print(io, "unsupported SoleLogics.", Name)
(value::_UnsupportedName{Name})(args...) where Name =
    _unsupported(Name, "this legacy value is a deliberate compatibility gap")
_unsupported_name(name::Symbol) = _UnsupportedName{name}()

function _unsupported(name::Symbol, detail::AbstractString)
    throw(ArgumentError("SoleLogics.$name has no faithful Aletheia equivalent: $detail"))
end

# Aletheia's explicit pool is hidden behind this one migration-only default.
# New code should use FormulaPool/Signature directly instead.
const _DEFAULT_SIGNATURE = Aletheia.Signature((Aletheia.:¬, Aletheia.:∧, Aletheia.:∨, Aletheia.:→))
const _DEFAULT_POOL = Aletheia.FormulaPool(_DEFAULT_SIGNATURE)

"""The Aletheia formula interface used in place of SoleLogics.Formula."""
const Formula = Aletheia.Formula
const SyntaxStructure = Aletheia.Formula
const AbstractSyntaxStructure = Aletheia.Formula
const SyntaxTree = Aletheia.Formula
abstract type NamedConnective{Name} end
struct _CompatConnective{Name,C} <: NamedConnective{Name}
    native::C
end
const _NOT = _CompatConnective{:¬,Aletheia.Negation}(Aletheia.:¬)
const _AND = _CompatConnective{:∧,Aletheia.Conjunction}(Aletheia.:∧)
const _OR = _CompatConnective{:∨,Aletheia.Disjunction}(Aletheia.:∨)
const _IMP = _CompatConnective{:→,Aletheia.Implication}(Aletheia.:→)
const _AnyConnective = Union{NamedConnective,Aletheia.Negation,Aletheia.Conjunction,
    Aletheia.Disjunction,Aletheia.Implication,Aletheia.AbstractRelationalConnective}
_named_connective(::Val{name}) where {name} = _unsupported(:NamedConnective,
    "Aletheia has no connective spelled $(name)")
_named_connective(::Val{:¬}) = _NOT
_named_connective(::Val{:∧}) = _AND
_named_connective(::Val{:∨}) = _OR
_named_connective(::Val{:→}) = _IMP
(::Type{NamedConnective{name}})() where {name} = _named_connective(Val(name))
const Operator = _AnyConnective
const Connective = _AnyConnective
const AbstractRelation = Aletheia.RelationFamily
const BoxRelationalConnective = Aletheia.Box{<:Any}
const DiamondRelationalConnective = Aletheia.Diamond{<:Any}
const _LegacyConnective = Union{Aletheia.Negation,Aletheia.Conjunction,Aletheia.Disjunction,Aletheia.Implication}
Base.:(==)(left::_CompatConnective, right::_LegacyConnective) = left.native === right
Base.:(==)(left::_LegacyConnective, right::_CompatConnective) = right.native === left
Base.isequal(left::_CompatConnective, right::_LegacyConnective) = left.native === right
Base.isequal(left::_LegacyConnective, right::_CompatConnective) = right.native === left
Base.hash(connective::_CompatConnective, h::UInt) = hash(connective.native, h)

# Truth values remain distinct from ordinary pooled DAG atoms. They subtype the
# compatibility Formula boundary so legacy tableaux can carry truth leaves,
# while direct Atom construction still fails instead of hiding a truth value in
# the evaluator's atom valuation path.
abstract type Truth <: Aletheia.Formula end
struct BooleanTruth <: Truth
    value::Bool
end
const TOP = BooleanTruth(true)
const BOT = BooleanTruth(false)
const ⊤ = TOP
const ⊥ = BOT
value(truth::BooleanTruth) = truth.value
istop(truth::BooleanTruth) = truth.value
isbot(truth::BooleanTruth) = !truth.value
istop(value) = false
isbot(value) = false
syntaxstring(truth::BooleanTruth; kwargs...) = truth.value ? "⊤" : "⊥"
Base.show(io::IO, truth::BooleanTruth) = print(io, syntaxstring(truth))
children(::Truth) = ()
arity(::Truth) = 0
function truths(formula::Aletheia.Formula)
    [node isa Truth ? node : value(node) for node in formulas(formula) if
        node isa Truth || ((node isa Atom || node isa Aletheia.Atom) && value(node) isa Truth)]
end
truths(value::Truth) = Truth[value]
collatetruth(args...) = _unsupported(:collatetruth,
    "Aletheia evaluates semantic values through TruthAlgebra and never treats them as formulas")


# Compatibility formulas wrap ordinary Aletheia DAG handles.  Keeping the
# wrapper type here (rather than extending Aletheia.Atom's constructor) makes
# the migration constructor local while allowing `Atom` in `isa` and dispatch.
# A tuple-shaped cached view keeps the legacy indexing/destructuring surface
# while reusing canonical child wrappers for every traversal.
struct _CompatChildren{N,P<:Aletheia.FormulaPool}
    pool::P
    ids::NTuple{N,Int}
end
Base.size(::_CompatChildren{N}) where N = (N,)
Base.length(::_CompatChildren{N}) where N = N
Base.firstindex(::_CompatChildren) = 1
Base.lastindex(children::_CompatChildren{N}) where N = N
Base.getindex(children::_CompatChildren, i::Int) =
    _wrap_id(children.pool, children.ids[i])
Base.iterate(::_CompatChildren{0}) = nothing
@inline Base.iterate(children::_CompatChildren{N}) where N =
    N == 0 ? nothing : (_wrap_id(children.pool, children.ids[1]), 2)
@inline function Base.iterate(children::_CompatChildren{N}, state::Int) where N
    state > N && return nothing
    (_wrap_id(children.pool, children.ids[state]), state + 1)
end
Base.IteratorSize(::_CompatChildren) = Base.HasLength()
Base.IteratorEltype(::_CompatChildren) = Base.EltypeUnknown()
Base.:(==)(children::_CompatChildren, values::Tuple) =
    length(children) == length(values) && all(children[i] == values[i] for i in eachindex(values))
Base.:(==)(values::Tuple, children::_CompatChildren) = children == values

# Compatibility formulas wrap ordinary Aletheia DAG handles.  Keeping the
# wrapper type here (rather than extending Aletheia.Atom's constructor) makes
# the migration constructor local while allowing `Atom` in `isa` and dispatch.
struct Atom{V,P<:Aletheia.FormulaPool} <: Aletheia.Formula
    pool::P
    id::Int
    payload::V
    Atom{V,P}(pool::P, id::Int, payload::V) where {V,P<:Aletheia.FormulaPool} = new{V,P}(pool, id, payload)
    Atom(native::Aletheia.Atom{V,P}, ::Val{:native}) where {V,P<:Aletheia.FormulaPool} =
        new{V,P}(native.pool, native.id, native.value)
end
struct _CompatBranch{C,N,P<:Aletheia.FormulaPool} <: Aletheia.Formula
    pool::P
    id::Int
    connective::C
    childview::_CompatChildren{N,P}
    function _CompatBranch{C,N,P}(pool::P, id::Int, connective::C, ids::NTuple{N,Int}) where {C,N,P<:Aletheia.FormulaPool}
        new{C,N,P}(pool, id, connective, _CompatChildren{N,P}(pool, ids))
    end
    _CompatBranch(native::Aletheia.Branch{C,N,P}) where {C,N,P<:Aletheia.FormulaPool} =
        _CompatBranch{C,N,P}(native.pool, native.id, native.connective, native.children)
end
const _CompatFormula = Union{Atom,_CompatBranch}
# A truth constant interned as a pool payload is still a truth value, not an
# atom.  SoleLogics puts the `Truth` itself in the tree, and consumers branch on
# the child object's type, so the wrapper cache stores the payload unchanged for
# those leaves.  `token` already unwrapped them; `children` did not, and that
# asymmetry silently disarmed the tableau closure rules that test
# `Tuple{Truth,Truth}`.
const _CompatCacheEntry = Union{Nothing,Atom,_CompatBranch,Truth}
const _WRAPPER_CACHE = IdDict{Aletheia.FormulaPool,Vector{_CompatCacheEntry}}()
const _WRAPPER_CACHE_LOCK = ReentrantLock()
const _NEGATION_CACHE = IdDict{Aletheia.FormulaPool,Vector{Int}}()
const _NEGATION_CACHE_LOCK = ReentrantLock()
const SyntaxLeaf = Atom
const AbstractAtom = Atom
@inline _wrap(formula::Atom) = formula
@inline _wrap(formula::_CompatBranch) = formula
@inline _wrap(formula::Truth) = formula
@inline _wrap(formula::Aletheia.Atom{V,P}) where {V,P<:Aletheia.FormulaPool} = _wrap_id(formula.pool, formula.id)
@inline _wrap(formula::Aletheia.Branch{C,N,P}) where {C,N,P<:Aletheia.FormulaPool} = _wrap_id(formula.pool, formula.id)
@inline _unwrap(formula::Atom) = Aletheia._formula_unlocked(formula.pool, formula.id)
@inline _unwrap(formula::_CompatBranch) = Aletheia._formula_unlocked(formula.pool, formula.id)
@inline _unwrap(formula::Aletheia.Formula) = formula
@inline _formula_pool(formula::Atom) = formula.pool
@inline _formula_pool(formula::_CompatBranch) = formula.pool
Base.:(==)(left::Atom, right::Atom) = left.pool === right.pool && left.id == right.id
Base.:(==)(left::_CompatBranch, right::_CompatBranch) = left.pool === right.pool && left.id == right.id
Base.isequal(left::Atom, right::Atom) = left == right
Base.isequal(left::_CompatBranch, right::_CompatBranch) = left == right
Base.hash(formula::Atom, h::UInt) = hash(objectid(formula.pool), hash(formula.id, h))
Base.hash(formula::_CompatBranch, h::UInt) = hash(objectid(formula.pool), hash(formula.id, h))
@inline function _wrap_id(pool::P, id::Int) where {P<:Aletheia.FormulaPool}
    cache = get(_WRAPPER_CACHE, pool, nothing)
    if cache !== nothing && id <= length(cache)
        cached = cache[id]
        cached === nothing || return cached
    end
    lock(_WRAPPER_CACHE_LOCK)
    try
        cache = get!(_WRAPPER_CACHE, pool) do
            _CompatCacheEntry[]
        end
        while id > length(cache)
            push!(cache, nothing)
        end
        cached = cache[id]
        cached === nothing || return cached
        node = pool.nodes[id]
        wrapped = node.kind == 0x01 ?
            (node.payload isa Truth ? node.payload :
                Atom{typeof(node.payload),P}(pool, id, node.payload)) :
            _CompatBranch{typeof(node.payload),length(node.children),P}(pool, id, node.payload, node.children)
        cache[id] = wrapped
        wrapped
    finally
        unlock(_WRAPPER_CACHE_LOCK)
    end
end

function Atom(value)
    value isa Truth && _unsupported(:Atom,
        "truth values are semantic values, not formulas in Aletheia")
    value isa Aletheia.Formula && _unsupported(:Atom,
        "Aletheia atoms cannot contain formulas; use children/branch instead")
    _wrap(Aletheia.atom(_DEFAULT_POOL, value))
end

# Sole treats connective values as constructors.  Keep Aletheia's values (and
# thus their type-level dispatch identity) while adding the opt-in call form.
function (connective::Aletheia.Negation)(formula::Aletheia.Formula)
    Branch(connective, formula)
end
function (connective::Union{Aletheia.Conjunction,Aletheia.Disjunction,
        Aletheia.Implication})(left::Aletheia.Formula, right::Aletheia.Formula)
    Branch(connective, left, right)
end
function (connective::Union{Aletheia.Diamond,Aletheia.Box})(formula::Aletheia.Formula)
    Branch(connective, formula)
end

@inline function _hasconnective(signature::Aletheia.Signature, connective)
    for candidate in Aletheia.connectives(signature)
        isequal(candidate, connective) && return true
    end
    false
end

# The overwhelmingly common construction path has compatibility children from
# one pool. Keep it straight-line: the previous generic pool merge allocated a
# temporary Vector and repeatedly rebuilt tuples for every branch.
function _formula_pool_for(connective, formulas::Tuple)
    isempty(formulas) && return _DEFAULT_POOL
    candidate = nothing
    same = true
    for formula in formulas
        pool = if formula isa Truth
            continue
        elseif formula isa _CompatFormula
            _formula_pool(formula)
        elseif formula isa Aletheia.Formula
            Aletheia.pool(formula)
        else
            continue
        end
        if candidate === nothing
            candidate = pool
        elseif pool !== candidate
            same = false
            break
        end
    end
    candidate === nothing && (candidate = _DEFAULT_POOL)
    if same && _hasconnective(Aletheia.signature(candidate), connective)
        return candidate
    end
    _merge_formula_pools(connective, formulas)
end

function _merge_formula_pools(connective, formulas::Tuple)
    merged = ()
    for formula in formulas
        formula isa Aletheia.Formula || continue
        formula isa Truth && continue
        pool = formula isa _CompatFormula ? _formula_pool(formula) : Aletheia.pool(formula)
        for candidate in Aletheia.connectives(Aletheia.signature(pool))
            any(existing -> existing === candidate, merged) || (merged = (merged..., candidate))
        end
    end
    any(candidate -> candidate === connective, merged) || (merged = (merged..., connective))
    Aletheia.FormulaPool(Aletheia.Signature(merged))
end

@inline function _repool(formula::Atom, target)
    formula.pool === target ? formula :
        _wrap(Aletheia.atom(target, value(formula)))
end
@inline function _repool(formula::_CompatBranch{C,N,P}, target) where {C,N,P}
    formula.pool === target ? formula : begin
        cs = children(formula)
        ids = ntuple(i -> _unwrap(_repool(cs[i], target)), N)
        _wrap(Aletheia.branch(target, formula.connective, ids))
    end
end
# A truth leaf is interned as a payload, so repooling yields the native atom:
# wrapping it would hand back the `Truth` again and lose the pool identity that
# branch construction needs.
function _repool(formula::Truth, target)
    Aletheia.atom(target, formula)
end
function _repool(formula::Aletheia.Formula, target)
    Aletheia.pool(formula) === target && return _wrap(formula)
    formula isa Aletheia.Atom && return _wrap(Aletheia.atom(target, Aletheia.value(formula)))
    formula isa Aletheia.Branch || _unsupported(:SyntaxBranch,
        "children must be Aletheia formulas (got $(typeof(formula)))")
    _wrap(Aletheia.branch(target, Aletheia.operator(formula),
        Tuple(_unwrap(_repool(child, target)) for child in Aletheia.children(formula))))
end

@inline _compat_child_id(child::Atom, pool) = child.pool === pool ? child.id : 0
@inline _compat_child_id(child::_CompatBranch, pool) = child.pool === pool ? child.id : 0
@inline _compat_child_id(child::Aletheia.Atom, pool) = Aletheia.pool(child) === pool ? Aletheia.id(child) : 0
@inline _compat_child_id(child::Aletheia.Branch, pool) = Aletheia.pool(child) === pool ? Aletheia.id(child) : 0
@inline _compat_child_id(child::Truth, pool) = Aletheia.id(Aletheia.atom(pool, child))
@inline _compat_child_id(child, pool) = 0

@inline function _compat_negation(pool::P, child_id::Int) where {P<:Aletheia.FormulaPool}
    cache = get(_NEGATION_CACHE, pool, nothing)
    if cache !== nothing && child_id <= length(cache)
        branch_id = cache[child_id]
        branch_id != 0 && return _wrap_id(pool, branch_id)
    end
    lock(_NEGATION_CACHE_LOCK)
    try
        cache = get!(_NEGATION_CACHE, pool) do
            Int[]
        end
        while child_id > length(cache)
            push!(cache, 0)
        end
        branch_id = cache[child_id]
        if branch_id == 0
            branch_id = Aletheia._intern!(pool, 0x02, Aletheia.:¬, (child_id,))
            cache[child_id] = branch_id
        end
        return _wrap_id(pool, branch_id)
    finally
        unlock(_NEGATION_CACHE_LOCK)
    end
end

@inline function _compat_branch(connective, child::F) where {F<:_CompatFormula}
    Aletheia.arity(connective) == 1 || return _compat_branch(connective, (child,))
    pool = child.pool
    _hasconnective(Aletheia.signature(pool), connective) || return _compat_branch(connective, (child,))
    connective isa Aletheia.Negation && return _compat_negation(pool, child.id)
    _wrap_id(pool, Aletheia._intern!(pool, 0x02, connective, (child.id,)))
end
@inline function _compat_branch(connective, left::F, right::G) where {F<:_CompatFormula,G<:_CompatFormula}
    Aletheia.arity(connective) == 2 || return _compat_branch(connective, (left, right))
    pool = left.pool
    if right.pool === pool && _hasconnective(Aletheia.signature(pool), connective)
        return _wrap_id(pool, Aletheia._intern!(pool, 0x02, connective, (left.id, right.id)))
    end
    _compat_branch(connective, (left, right))
end

function _compat_branch(connective, children::Tuple)
    pool = _formula_pool_for(connective, children)
    expected = Aletheia.arity(connective)
    expected == length(children) || throw(ArgumentError(
        "$(repr(connective)) expects $expected children, got $(length(children))"))
    ids = ntuple(i -> _compat_child_id(children[i], pool), length(children))
    if all(!iszero, ids) && _hasconnective(Aletheia.signature(pool), connective)
        connective isa Aletheia.Negation && return _compat_negation(pool, ids[1])
        branch_id = Aletheia._intern!(pool, 0x02, connective, ids)
        return _wrap_id(pool, branch_id)
    end
    normalized = ntuple(i -> _repool(children[i], pool), length(children))
    _wrap(Aletheia.branch(pool, connective, ntuple(i -> _unwrap(normalized[i]), length(normalized))))
end
function Branch(connective::_LegacyConnective, children::Tuple)
    connective isa _UnsupportedName && _unsupported(:SyntaxBranch,
        "the requested connective is not implemented by Aletheia")
    _compat_branch(connective, children)
end
Branch(connective::_LegacyConnective, children::Tuple{F}) where {F<:_CompatFormula} =
    Aletheia.arity(connective) == 1 ? _compat_branch(connective, children[1]) :
        _compat_branch(connective, children)
Branch(connective::_LegacyConnective, children::Tuple{F,G}) where {F<:_CompatFormula,G<:_CompatFormula} =
    Aletheia.arity(connective) == 2 ? _compat_branch(connective, children[1], children[2]) :
        _compat_branch(connective, children)
Branch(connective::_LegacyConnective, children...) = Branch(connective, children)
Branch(connective::_CompatConnective, children...) = Branch(connective.native, children...)
Branch(connective::Aletheia.Diamond, children...) = _compat_branch(connective, children)
Branch(connective::Aletheia.Box, children...) = _compat_branch(connective, children)
const SyntaxBranch = Branch

# Old accessors and tree walks.
@inline token(formula::Atom) = value(formula) isa Truth ? value(formula) : formula
@inline token(::_CompatBranch{Aletheia.Negation}) = _NOT
@inline token(::_CompatBranch{Aletheia.Conjunction}) = _AND
@inline token(::_CompatBranch{Aletheia.Disjunction}) = _OR
@inline token(::_CompatBranch{Aletheia.Implication}) = _IMP
@inline function token(formula::_CompatBranch)
    native = formula.connective
    native isa Aletheia.Negation && return _NOT
    native isa Aletheia.Conjunction && return _AND
    native isa Aletheia.Disjunction && return _OR
    native isa Aletheia.Implication && return _IMP
    native
end
token(formula::Aletheia.Atom) = value(formula) isa Truth ? value(formula) : formula
token(formula::Aletheia.Branch) = Aletheia.operator(formula)
Aletheia.arity(connective::_CompatConnective) = Aletheia.arity(connective.native)
Aletheia.notation(connective::_CompatConnective) = Aletheia.notation(connective.native)
token(value::Truth) = value
op(value) = token(value)
@inline value(formula::Atom) = formula.payload
@inline children(::Atom) = ()
@inline children(formula::_CompatBranch) = formula.childview
@inline nchildren(::Atom) = 0
@inline nchildren(formula::_CompatBranch{C,N,P}) where {C,N,P} = N
tree(formula::Aletheia.Formula) = formula
nchildren(formula::Aletheia.Formula) = Aletheia.nchildren(formula)

function _walk(formula::Aletheia.Formula, out::Vector)
    for child in children(formula)
        _walk(child, out)
    end
    push!(out, formula)
    out
end
const _FORMULA_CACHE_ENTRY = Union{Nothing,Vector{Aletheia.Formula}}
const _FORMULA_CACHE = IdDict{Aletheia.FormulaPool,Vector{_FORMULA_CACHE_ENTRY}}()
const _FORMULA_CACHE_LOCK = ReentrantLock()
function _cached_formulas(formula::Union{Atom,_CompatBranch})
    pool = formula.pool
    id = formula.id
    lock(_FORMULA_CACHE_LOCK)
    try
        cache = get!(_FORMULA_CACHE, pool) do
            _FORMULA_CACHE_ENTRY[]
        end
        while id > length(cache)
            push!(cache, nothing)
        end
        cached = cache[id]
        cached === nothing || return cached
    finally
        unlock(_FORMULA_CACHE_LOCK)
    end
    result = _walk(formula, Aletheia.Formula[])
    lock(_FORMULA_CACHE_LOCK)
    try
        cache = _FORMULA_CACHE[pool]
        cache[id] = result
        result
    finally
        unlock(_FORMULA_CACHE_LOCK)
    end
end
formulas(formula::Atom) = _cached_formulas(formula)
formulas(formula::_CompatBranch) = _cached_formulas(formula)
function formulas(formula::Aletheia.Formula)
    _walk(formula, Aletheia.Formula[])
end
const _SUBFORMULA_CACHE = IdDict{Aletheia.FormulaPool,Vector{_FORMULA_CACHE_ENTRY}}()
function _cached_subformulas(formula::Union{Atom,_CompatBranch})
    pool = formula.pool
    id = formula.id
    lock(_FORMULA_CACHE_LOCK)
    try
        cache = get!(_SUBFORMULA_CACHE, pool) do
            _FORMULA_CACHE_ENTRY[]
        end
        while id > length(cache)
            push!(cache, nothing)
        end
        cached = cache[id]
        cached === nothing || return cached
    finally
        unlock(_FORMULA_CACHE_LOCK)
    end
    result = sort!(copy(formulas(formula)), by=height)
    lock(_FORMULA_CACHE_LOCK)
    try
        cache = _SUBFORMULA_CACHE[pool]
        cache[id] = result
        result
    finally
        unlock(_FORMULA_CACHE_LOCK)
    end
end
function subformulas(formula::Union{Atom,_CompatBranch}; sorted=true)
    sorted ? _cached_subformulas(formula) : formulas(formula)
end
function subformulas(formula::Aletheia.Formula; sorted=true)
    result = formulas(formula)
    sorted ? sort!(result, by=height) : result
end
function atoms(formula::Aletheia.Formula)
    [node for node in formulas(formula) if
        (node isa Atom || node isa Aletheia.Atom) && !(value(node) isa Truth)]
end
function leaves(formula::Aletheia.Formula)
    [token(node) for node in formulas(formula) if
        node isa Truth || node isa Atom || node isa Aletheia.Atom]
end
function connectives(formula::Aletheia.Formula)
    [token(node) for node in formulas(formula) if node isa _CompatBranch || node isa Aletheia.Branch]
end
operators(formula::Aletheia.Formula) = connectives(formula)
ntokens(formula::Aletheia.Formula) = length(formulas(formula))
natoms(formula::Aletheia.Formula) = length(atoms(formula))
nleaves(formula::Aletheia.Formula) = length(leaves(formula))
nconnectives(formula::Aletheia.Formula) = length(connectives(formula))
noperators(formula::Aletheia.Formula) = nconnectives(formula)
function height(formula::Aletheia.Formula)::Int
    cs = children(formula)
    isempty(cs) && return 0
    child_height = 0
    for child in cs
        child_height = max(child_height, height(child))
    end
    1 + child_height
end

# Aletheia's normal forms are ordinary hash-consed formulas, not Sole's
# leftmost wrapper types. These helpers are useful for formulas after parsing.
@inline _native_connective(formula::_CompatBranch) = formula.connective
@inline _native_connective(formula::Aletheia.Branch) = Aletheia.operator(formula)
function _flatten!(out::Vector{Aletheia.Formula}, formula::Aletheia.Formula, connective)
    if (formula isa _CompatBranch || formula isa Aletheia.Branch) &&
            _native_connective(formula) isa connective
        child = children(formula)
        _flatten!(out, child[1], connective)
        _flatten!(out, child[2], connective)
    else
        push!(out, formula)
    end
    out
end
function _flatten(formula::Aletheia.Formula, connective)
    _flatten!(Aletheia.Formula[], formula, connective)
end
conjuncts(formula::Aletheia.Formula) = _flatten(formula, Aletheia.Conjunction)
disjuncts(formula::Aletheia.Formula) = _flatten(formula, Aletheia.Disjunction)
grandchildren(formula::Aletheia.Formula) = children(formula)
nconjuncts(formula::Aletheia.Formula) = length(conjuncts(formula))

# Poolless spellings remain available for old call sites; explicit pool forms
# are also accepted and preserve Aletheia's pool semantics.
atom(value) = Atom(value)
atom(pool::Aletheia.FormulaPool, value) = _wrap(Aletheia.atom(pool, value))
branch(pool::Aletheia.FormulaPool, connective, children...) =
    _wrap(Aletheia.branch(pool, connective, Tuple(_unwrap.(children))))
branch(connective::_LegacyConnective, children...) = Branch(connective, children...)

function syntaxstring(formula::Aletheia.Formula; kwargs...)
    allowed = (:threshold_digits, :function_notation, :remove_redundant_parentheses, :parenthesize_atoms)
    unknown = setdiff(collect(keys(kwargs)), collect(allowed))
    isempty(unknown) || _unsupported(:syntaxstring,
        "Aletheia's printer does not accept keyword(s) $(join(string.(unknown), ", ")).")
    Aletheia.syntaxstring(_unwrap(formula))
end
syntaxstring(connective::_CompatConnective; kwargs...) = Aletheia.notation(connective.native)
syntaxstring(connective::_LegacyConnective; kwargs...) = Aletheia.notation(connective)
syntaxstring(value; kwargs...) = string(value)

# Parser adapter. The callback returns an atom payload in Aletheia; callbacks
# written for SoleLogics may return the compatibility Atom constructor.
function _payload(atom_parser, text)
    parsed = atom_parser(text)
    parsed isa Truth && _unsupported(:parseformula,
        "truth values are not formula leaves in Aletheia")
    parsed isa Atom ? value(parsed) : parsed isa Aletheia.Atom ? Aletheia.value(parsed) : parsed
end
function _parse_pool(additional_operators)
    extras = additional_operators === nothing ? () : Tuple(additional_operators)
    all(c -> arity(c) isa Integer, extras)
    Aletheia.FormulaPool(Aletheia.Signature((Aletheia.:¬, Aletheia.:∧, Aletheia.:∨, Aletheia.:→, extras...)))
end
function parseformula(expr::AbstractString; atom_parser=identity,
        additional_operators=nothing, function_notation=false, kwargs...)
    ignored = (:additional_whitespaces, :opening_parenthesis, :closing_parenthesis, :arg_delim,
        :threshold_digits, :remove_redundant_parentheses, :parenthesize_atoms)
    unknown = setdiff(collect(keys(kwargs)), collect(ignored))
    isempty(unknown) || _unsupported(:parseformula,
        "Aletheia's parser does not accept keyword(s) $(join(string.(unknown), ", "))")
    pool = additional_operators === nothing ? _DEFAULT_POOL : _parse_pool(additional_operators)
    _wrap(Aletheia.parse(pool, expr; atom_parser=text -> _payload(atom_parser, text)))
end
parseformula(::Type{<:Aletheia.Formula}, expr::AbstractString; kwargs...) = parseformula(expr; kwargs...)
parseformula(expr::AbstractString, additional_operators; kwargs...) =
    parseformula(expr; additional_operators=additional_operators, kwargs...)
parseformula(::Type{<:Aletheia.Formula}, expr::AbstractString, additional_operators; kwargs...) =
    parseformula(expr; additional_operators=additional_operators, kwargs...)

# Core evaluation/model names retain their Aletheia meaning. In particular,
# check now consumes a Model rather than Sole's InterpretationSet.  Formula
# wrappers are unwrapped at this boundary.
check(formula::Aletheia.Formula, args...) =
    Aletheia.check(_unwrap(formula), args...)
interpret(formula::Aletheia.Formula, args...) =
    Aletheia.interpret(_unwrap(formula), args...)
frame = Aletheia.frame
algebra = Aletheia.algebra
domain = Aletheia.domain
top = Aletheia.top
bot = Aletheia.bot
worlds = Aletheia.worlds
worldtype(f) = eltype(Aletheia.worlds(Aletheia.frame(f)))
accessible = Aletheia.accessible
accessibles = Aletheia.accessibles
allworlds(f) = collect(Aletheia.worlds(f))
function collateworlds(frame, connective, truth_sets::Tuple)
    native = connective isa _CompatConnective ? connective.native : connective
    Aletheia.collateworlds(frame, native, truth_sets)
end

# Frame/world/relation vocabulary retained by Sole consumers.  These are
# direct aliases, so dispatch and singleton identity remain Aletheia's.
const AbstractFrame = Aletheia.AbstractFrame
const AbstractUniModalFrame = Aletheia.AbstractUniModalFrame
const AbstractMultiModalFrame = Aletheia.AbstractMultiModalFrame
const AbstractWorld = Aletheia.AbstractWorld
const AbstractWorlds = Aletheia.AbstractWorlds
const AnyWorld = Aletheia.AnyWorld
const AbstractRelationalConnective = Aletheia.AbstractRelationalConnective
const globalrel = Aletheia.globalrel
const identityrel = Aletheia.identityrel
const GlobalRel = Aletheia.GlobalRel
const IdentityRel = Aletheia.IdentityRel
const AtWorldRelation = Aletheia.AtWorldRelation
const tocenterrel = Aletheia.tocenterrel
const ToCenterRel = Aletheia.ToCenterRel
centralworld = Aletheia.centralworld
emptyworld = Aletheia.emptyworld
ismodal = Aletheia.ismodal
isunary = Aletheia.isunary
isdiamond = Aletheia.isdiamond
isbox = Aletheia.isbox
isgrounding = Aletheia.isgrounding
isgrounded(formula::Aletheia.Formula) = Aletheia.isgrounded(_unwrap(formula))

# Sole's leftmost linear forms are containers, not DAG nodes: a connective in
# the type parameter and a flat vector of operands.  They live entirely in this
# module.  Nothing here is ever interned in a FormulaPool; every operation that
# needs a real Aletheia formula goes through `tree`, which folds the container
# into ordinary binary branches.  That keeps the container shape available to
# migrating consumers without making it a core representation.
struct LeftmostLinearForm{C,SS} <: Aletheia.Formula
    grandchildren::Vector{SS}

    function LeftmostLinearForm{C,SS}(grandchildren::AbstractVector,
            allow_empty::Bool=false) where {C,SS}
        n = length(grandchildren)
        if !allow_empty
            n > 0 || throw(ArgumentError(
                "cannot instantiate LeftmostLinearForm{$C} with no grandchildren"))
            a = Aletheia.arity(C())
            if a == 1
                n == 1 || throw(ArgumentError(
                    "mismatching number of grandchildren ($n) and connective's arity ($a)"))
            else
                h = (n - 1) / (a - 1)
                (isinteger(h) && h >= 0) || throw(ArgumentError(
                    "mismatching number of grandchildren ($n) and connective's arity ($a)"))
            end
        end
        new{C,SS}(convert(Vector{SS}, grandchildren))
    end
end
const LeftmostConjunctiveForm{SS} = LeftmostLinearForm{Aletheia.Conjunction,SS}
const LeftmostDisjunctiveForm{SS} = LeftmostLinearForm{Aletheia.Disjunction,SS}
const CNF{SS} = LeftmostConjunctiveForm{LeftmostDisjunctiveForm{SS}}
const DNF{SS} = LeftmostDisjunctiveForm{LeftmostConjunctiveForm{SS}}
const AbstractInterpretationSet = _unsupported_name(:AbstractInterpretationSet)

function _element_type(grandchildren::AbstractVector)
    element = eltype(grandchildren)
    isconcretetype(element) && return element
    isempty(grandchildren) && return Aletheia.Formula
    reduce(typejoin, map(typeof, grandchildren))
end
LeftmostLinearForm{C}(grandchildren::AbstractVector, args...) where {C} =
    LeftmostLinearForm{C,_element_type(grandchildren)}(grandchildren, args...)
LeftmostLinearForm(connective::_AnyConnective, grandchildren::AbstractVector, args...) =
    LeftmostLinearForm{typeof(_native_operator(connective))}(grandchildren, args...)

# Sole also builds a container by flattening a syntax tree over one connective.
function LeftmostLinearForm(formula::Aletheia.Formula, connective=nothing, args...)
    formula isa LeftmostLinearForm && return LeftmostLinearForm(tree(formula), connective, args...)
    native = connective === nothing ? nothing : _native_operator(connective)
    if native === nothing
        (formula isa _CompatBranch || formula isa Aletheia.Branch) || _unsupported(:LeftmostLinearForm,
            "a leaf cannot be flattened without an explicit connective")
        native = _native_connective(formula)
    end
    LeftmostLinearForm(native, _flatten(_wrap(formula), typeof(native)), args...)
end
LeftmostLinearForm{C}(formula::Aletheia.Formula, args...) where {C} =
    LeftmostLinearForm(formula, C(), args...)

@inline _native_operator(connective::_CompatConnective) = connective.native
@inline _native_operator(connective) = connective
@inline _compat_operator(native::Aletheia.Negation) = _NOT
@inline _compat_operator(native::Aletheia.Conjunction) = _AND
@inline _compat_operator(native::Aletheia.Disjunction) = _OR
@inline _compat_operator(native::Aletheia.Implication) = _IMP
@inline _compat_operator(native) = native

grandchildren(form::LeftmostLinearForm) = form.grandchildren
ngrandchildren(form::LeftmostLinearForm) = length(form.grandchildren)
ngrandchildren(formula::Aletheia.Formula) = length(grandchildren(formula))
children(form::LeftmostLinearForm) = form.grandchildren
nchildren(form::LeftmostLinearForm) = length(form.grandchildren)
connective(::LeftmostLinearForm{C}) where {C} = C()
connective(formula::Union{_CompatBranch,Aletheia.Branch}) = _native_connective(formula)
token(form::LeftmostLinearForm) = _compat_operator(connective(form))
Base.getindex(form::LeftmostLinearForm, index::Integer) = form.grandchildren[index]
Base.getindex(form::LeftmostLinearForm{C}, indices::AbstractVector) where {C} =
    LeftmostLinearForm{C}(form.grandchildren[indices])
Base.length(form::LeftmostLinearForm) = length(form.grandchildren)
Base.iterate(form::LeftmostLinearForm, state...) = iterate(form.grandchildren, state...)
Base.push!(form::LeftmostLinearForm, element) = push!(form.grandchildren, element)
pushconjunct!(form::LeftmostLinearForm, element) = push!(form.grandchildren, element)
Base.:(==)(left::LeftmostLinearForm{C}, right::LeftmostLinearForm{C}) where {C} =
    left.grandchildren == right.grandchildren

# A literal is an atom or its negation.  Sole consumers read `.ispos`/`.atom`
# directly, so the field names are part of the contract.
struct Literal{T} <: Aletheia.Formula
    ispos::Bool
    atom::T
end
Literal(formula::Union{Atom,Aletheia.Atom,Truth}, flag::Bool=true) =
    Literal{typeof(formula)}(flag, formula)
function Literal(formula::Union{_CompatBranch,Aletheia.Branch}, flag::Bool=true)
    _native_connective(formula) isa Aletheia.Negation || _unsupported(:Literal,
        "cannot construct a Literal from $(syntaxstring(formula))")
    Literal(_wrap(children(formula)[1]), !flag)
end
ispos(literal::Literal) = literal.ispos
atom(literal::Literal) = literal.atom
children(::Literal) = ()
nchildren(::Literal) = 0
Base.:(==)(left::Literal, right::Literal) =
    left.ispos == right.ispos && left.atom == right.atom
hasdual(::Literal) = true
dual(literal::Literal) = Literal(!literal.ispos, literal.atom)

# Folding back into Aletheia's representation.  Sole unwinds leftmost, so the
# fold is right-nested for a binary connective: c(φ1, c(φ2, φ3)).
tree(literal::Literal) = literal.ispos ? tree(literal.atom) :
    Branch(Aletheia.:¬, tree(literal.atom))
function tree(form::LeftmostLinearForm{C}) where {C}
    c = C()
    subtrees = [tree(child) for child in form.grandchildren]
    length(subtrees) == 1 && return Aletheia.arity(c) == 1 ? Branch(c, subtrees[1]) : subtrees[1]
    foldr((left, right) -> Branch(c, left, right), subtrees)
end
@inline _unwrap(form::LeftmostLinearForm) = _unwrap(tree(form))
@inline _unwrap(literal::Literal) = _unwrap(tree(literal))
_repool(form::Union{LeftmostLinearForm,Literal}, target) = _repool(tree(form), target)
height(form::Union{LeftmostLinearForm,Literal}) = height(tree(form))
conjuncts(form::LeftmostLinearForm{Aletheia.Conjunction}) = form.grandchildren
disjuncts(form::LeftmostLinearForm{Aletheia.Disjunction}) = form.grandchildren
nconjuncts(form::LeftmostLinearForm{Aletheia.Conjunction}) = length(form.grandchildren)

function syntaxstring(form::LeftmostLinearForm{C}; kwargs...) where {C}
    separator = " " * Aletheia.notation(C()) * " "
    join((_bracket(child; kwargs...) for child in form.grandchildren), separator)
end
syntaxstring(literal::Literal; kwargs...) = syntaxstring(tree(literal); kwargs...)
function _bracket(child; kwargs...)
    text = syntaxstring(child; kwargs...)
    occursin(' ', text) ? "(" * text * ")" : text
end
Base.show(io::IO, form::LeftmostLinearForm) = print(io, syntaxstring(form))
Base.show(io::IO, literal::Literal) = print(io, syntaxstring(literal))

check(form::Union{LeftmostLinearForm,Literal}, model::Aletheia.Model, args...) =
    check(tree(form), model, args...)
interpret(form::Union{LeftmostLinearForm,Literal}, model::Aletheia.Model, args...) =
    interpret(tree(form), model, args...)

# Sole alphabets are collections of atoms.  The vocabulary is kept here because
# it is what `randformula`/`randatom` consume; the alphabets that a learner
# actually builds are SoleData objects and remain out of this module's reach.
abstract type AbstractAlphabet{V} end
struct ExplicitAlphabet{V} <: AbstractAlphabet{V}
    atoms::Vector{V}

    ExplicitAlphabet(atoms::Vector{V}) where {V<:Aletheia.Formula} = new{V}(atoms)
    ExplicitAlphabet(values) = ExplicitAlphabet(
        [value isa Aletheia.Formula ? value : Atom(value) for value in values])
end
struct UnionAlphabet{A<:AbstractAlphabet} <: AbstractAlphabet{Any}
    subalphabets::Vector{A}
end
UnionAlphabet(subalphabets) = UnionAlphabet(collect(subalphabets))
atoms(alphabet::ExplicitAlphabet) = alphabet.atoms
atoms(alphabet::UnionAlphabet) = reduce(vcat, atoms.(alphabet.subalphabets);
    init=Aletheia.Formula[])
subalphabets(alphabet::UnionAlphabet) = alphabet.subalphabets
subalphabets(alphabet::AbstractAlphabet) = [alphabet]
natoms(alphabet::AbstractAlphabet) = length(atoms(alphabet))
Base.in(formula::Aletheia.Formula, alphabet::AbstractAlphabet) = formula in atoms(alphabet)
Base.isfinite(::Type{<:AbstractAlphabet}) = true
Base.isfinite(alphabet::AbstractAlphabet) = isfinite(typeof(alphabet))
Base.eltype(alphabet::AbstractAlphabet) = eltype(atoms(alphabet))
alphabet(value::AbstractAlphabet) = value
alphabet(values::AbstractVector) = ExplicitAlphabet(values)

# Random generation.  Aletheia has no dependencies, so no random-number
# generator is constructed here: the caller supplies one, or Base's default is
# used.  Integer seeds are the one Sole spelling this cannot honour, because
# building a seeded generator would require Random.
@inline _atom_domain(alphabet::AbstractAlphabet) = atoms(alphabet)
@inline _atom_domain(values::AbstractVector) = values
@inline _rand(::Nothing, args...) = rand(args...)
@inline _rand(rng, args...) = rand(rng, args...)
function _rng(rng)
    rng isa Integer && _unsupported(:randformula,
        "an integer seed needs Random; pass an AbstractRNG instead")
    rng
end
function _weighted_pick(rng, items, weights)
    weights === nothing && return _rand(rng, items)
    total = sum(weights)
    total > 0 || throw(ArgumentError("sampling weights must sum to a positive value"))
    target = _rand(rng, Float64) * total
    accumulated = zero(total)
    for index in eachindex(items)
        accumulated += weights[index]
        accumulated >= target && return items[index]
    end
    items[end]
end
randatom(rng, alphabet) = _rand(_rng(rng), _atom_domain(alphabet))
randatom(alphabet) = randatom(nothing, alphabet)

"""
    randformula([rng], maxheight, alphabet, operators; kwargs...)

Sole's random formula generator, reproduced over Aletheia formulas. `mode`,
`basecase`, `opweights`, `atompicker`, `maxmodaldepth` and
`earlystoppingtreshold` keep SoleLogics' meaning.
"""
function randformula(rng, maxheight::Integer, alphabet, operators::AbstractVector;
        maxmodaldepth::Integer=maxheight,
        atompicker=randatom,
        opweights=nothing,
        basecase=nothing,
        mode::Symbol=:maxheight,
        earlystoppingtreshold::AbstractFloat=0.5,
        kwargs...)
    isempty(kwargs) || _unsupported(:randformula,
        "unsupported keyword(s) $(join(string.(keys(kwargs)), ", "))")
    rng = _rng(rng)
    domain = _atom_domain(alphabet)
    isempty(domain) && basecase === nothing && throw(ArgumentError(
        "cannot generate formulas from an empty alphabet"))
    picker = if atompicker isa Function
        atompicker
    elseif atompicker === nothing
        (generator, source) -> _rand(generator, _atom_domain(source))
    else
        weights = collect(atompicker)
        length(weights) == length(domain) || throw(ArgumentError(
            "mismatching numbers of atoms ($(length(domain))) and atompicker ($(length(weights)))"))
        (generator, source) -> _weighted_pick(generator, _atom_domain(source), weights)
    end
    weights = opweights === nothing ? nothing : collect(opweights)
    weights === nothing || length(weights) == length(operators) || throw(ArgumentError(
        "mismatching numbers of operators ($(length(operators))) and opweights ($(length(weights)))"))
    natives = [_native_operator(op) for op in operators]
    nonmodal = [index for index in eachindex(natives) if !Aletheia.ismodal(natives[index])]
    isempty(nonmodal) && maxmodaldepth < maxheight && throw(ArgumentError(
        "no non-modal operator is available below the modal depth limit"))
    function generate(height::Integer, modaldepth::Integer, must_honor::Bool)
        if height == 0 || (mode != :full && !must_honor &&
                _rand(rng, Float64) < earlystoppingtreshold)
            return basecase === nothing ? picker(rng, alphabet) : basecase(rng)
        end
        candidates, candidate_weights = modaldepth > 0 ? (natives, weights) :
            (natives[nonmodal], weights === nothing ? nothing : weights[nonmodal])
        operator = _weighted_pick(rng, candidates, candidate_weights)
        n = Aletheia.arity(operator)
        honored = must_honor && mode != :maxheight ? _rand(rng, 1:n) : 0
        subformulas = [generate(height - 1,
            modaldepth - (Aletheia.ismodal(operator) ? 1 : 0),
            must_honor && index == honored) for index in 1:n]
        Branch(operator, subformulas...)
    end
    generate(maxheight, maxmodaldepth, mode != :maxheight)
end
randformula(maxheight::Integer, alphabet, operators::AbstractVector; kwargs...) =
    randformula(nothing, maxheight, alphabet, operators; kwargs...)

# Modal and dimensional spellings with a direct data-level equivalent.
const Interval = Aletheia.Interval
const Interval2D = Aletheia.Interval2D
const Point = Aletheia.Point
const Point1D = Aletheia.Point
const Point2D = Aletheia.Point
const FullDimensionalFrame = Aletheia.FullDimensionalFrame
diamond(relation_value) = Aletheia.Diamond(relation_value)
box(relation_value) = Aletheia.Box(relation_value)
const IA_A = Aletheia.IA_A
const IA_L = Aletheia.IA_L
const IA_B = Aletheia.IA_B
const IA_E = Aletheia.IA_E
const IA_D = Aletheia.IA_D
const IA_O = Aletheia.IA_O
const IA_Ai = Aletheia.IA_Ai
const IA_Li = Aletheia.IA_Li
const IA_Bi = Aletheia.IA_Bi
const IA_Ei = Aletheia.IA_Ei
const IA_Di = Aletheia.IA_Di
const IA_Oi = Aletheia.IA_Oi
const IA_AorO = Aletheia.IA_AorO
const IA_DorBorE = Aletheia.IA_DorBorE
const IA_AiorOi = Aletheia.IA_AiorOi
const IA_DiorBiorEi = Aletheia.IA_DiorBiorEi
const IA_I = Aletheia.IA_I
const IA7Relations = Aletheia.IA7Relations
const IA3Relations = Aletheia.IA3Relations
const RCC5Relations = Aletheia.RCC5Relations
const RCC8Relations = Aletheia.RCC8Relations
const Topo_DR = Aletheia.Topo_DR
const Topo_PP = Aletheia.Topo_PP
const Topo_PPi = Aletheia.Topo_PPi
const TruthDict = Aletheia.Valuation
KripkeStructure(frame_value, valuation_value) = Aletheia.Model(frame_value, Aletheia.BOOLEAN, valuation_value)

# Names used by Sole's modal and collection helpers.
const IARelations = (IA_A, IA_L, IA_B, IA_E, IA_D, IA_O, IA_Ai, IA_Li, IA_Bi, IA_Ei, IA_Di, IA_Oi)
function alphabet(args...)
    _unsupported(:alphabet, "Aletheia has no model-wide alphabet object; collect Atom payloads from a Formula")
end
function feature(args...)
    _unsupported(:feature, "feature metadata belongs to SoleData conditions, not Aletheia syntax")
end
function condition(args...)
    _unsupported(:condition, "condition metadata belongs to SoleData conditions, not Aletheia syntax")
end
function threshold(args...)
    _unsupported(:threshold, "threshold metadata belongs to SoleData conditions, not Aletheia syntax")
end
function normalize(args...)
    _unsupported(:normalize, "Aletheia's normal-form conversion is explicit: use cnf or dnf")
end
function sample(args...)
    _unsupported(:sample, "random SoleLogics generation is not part of Aletheia's compatibility surface")
end
function worldtype(::Aletheia.Frame)
    _unsupported(:worldtype, "Aletheia frames are heterogeneous tuples; use eltype(worlds(frame)) explicitly")
end
name(connective) = Symbol(Aletheia.notation(connective))

# These names preserve the incumbent aliases to Aletheia's relation values;
# use the definitions from SoleLogics rather than guessing from their spelling.
const CL_N = Aletheia.CL_N
const CL_S = Aletheia.CL_S
const CL_E = Aletheia.CL_E
const CL_W = Aletheia.CL_W
const CL_NE = Aletheia.CL_NE
const CL_NW = Aletheia.CL_NW
const CL_SE = Aletheia.CL_SE
const CL_SW = Aletheia.CL_SW
const HS_A = Aletheia.IA_A
const HS_L = Aletheia.IA_L
const HS_B = Aletheia.IA_B
const HS_E = Aletheia.IA_E
const HS_D = Aletheia.IA_D
const HS_O = Aletheia.IA_O
const HS_Ai = Aletheia.IA_Ai
const HS_Li = Aletheia.IA_Li
const HS_Bi = Aletheia.IA_Bi
const HS_Ei = Aletheia.IA_Ei
const HS_Di = Aletheia.IA_Di
const HS_Oi = Aletheia.IA_Oi
const LRCC8_Rec_DC = Aletheia.Topo_DC
const LRCC8_Rec_EC = Aletheia.Topo_EC
const LRCC8_Rec_PO = Aletheia.Topo_PO
const LRCC8_Rec_TPP = Aletheia.Topo_TPP
const LRCC8_Rec_TPPi = Aletheia.Topo_TPPi
const LRCC8_Rec_NTPP = Aletheia.Topo_NTPP
const LRCC8_Rec_NTPPi = Aletheia.Topo_NTPPi
const LTLFP_F = Aletheia.GREATER
const LTLFP_P = Aletheia.LESSER

# A small, explicit nested replacement for SoleLogics.ManyValuedLogics.
module ManyValuedLogics
import ...Aletheia
import ..Truth, ..BooleanTruth, ..istop, ..isbot, ..syntaxstring
import Base: convert

# Sole's finite tableau code keeps the carrier object (including its index) in
# assertions and StaticArrays.  The core Aletheia evaluator intentionally uses
# UInt8 indices instead.  This small boundary object preserves the old
# protocol without putting boxed values back into the evaluator.
struct FiniteTruth <: Truth
    index::UInt8

    function FiniteTruth(index::UInt8)
        index == 0 && error("0 is not a valid index in Julia")
        new(index)
    end
end
function FiniteTruth(index::Integer)
    index == 0 && error("0 is not a valid index in Julia")
    1 <= index <= typemax(UInt8) ||
        throw(ArgumentError("finite truth index $index is outside 1:255"))
    FiniteTruth(UInt8(index))
end

Base.convert(::Type{FiniteTruth}, value::FiniteTruth) = value
Base.convert(::Type{FiniteTruth}, value::UInt8) = FiniteTruth(value)
Base.convert(::Type{FiniteTruth}, value::Integer) = FiniteTruth(value)
Base.convert(::Type{FiniteTruth}, value::BooleanTruth) = FiniteTruth(istop(value) ? UInt8(1) : UInt8(2))
Base.convert(::Type{UInt8}, value::FiniteTruth) = value.index

function Base.convert(::Type{FiniteTruth}, value::Char)
    code = UInt16(value)
    if 945 <= code < 1198
        return FiniteTruth(Int(code) - 942)
    elseif 8868 <= code < 8870
        return FiniteTruth(Int(code) - 8867)
    end
    error("Please, provide a character between α and ҭ, ⊤ and ⊥")
end
Base.convert(::Type{FiniteTruth}, value::AbstractString) =
    length(value) == 1 ? convert(FiniteTruth, only(value)) :
    error("Please, provide a string of one character")

@inline istop(value::FiniteTruth) = value.index == UInt8(1)
@inline isbot(value::FiniteTruth) = value.index == UInt8(2)
function syntaxstring(value::FiniteTruth; kwargs...)
    value.index < UInt8(3) ? Char(UInt16(8867) + value.index) :
        Char(UInt16(942) + value.index)
end
Base.show(io::IO, value::FiniteTruth) = print(io, syntaxstring(value))

# Convert an old carrier value to the unboxed Aletheia table index only while
# crossing into the core algebra.  Results are wrapped again at this boundary.
@inline _index(value::FiniteTruth) = value.index
@inline _index(value::UInt8) = value
@inline _index(value::Integer) = convert(FiniteTruth, value).index
@inline _index(value::BooleanTruth) = convert(FiniteTruth, value).index

struct _FiniteOperation{N}
    table::Matrix{UInt8}
end
@inline function (operation::_FiniteOperation)(left, right)
    FiniteTruth(operation.table[Int(_index(left)), Int(_index(right))])
end
Base.getindex(operation::_FiniteOperation, left, right) =
    FiniteTruth(operation.table[Int(_index(left)), Int(_index(right))])

function _operation_table(operation, n::Int, name::AbstractString)
    source = if operation isa _FiniteOperation
        size(operation.table) == (n, n) ||
            throw(ArgumentError("$name table must have size ($n, $n)"))
        operation.table
    elseif operation isa AbstractMatrix
        size(operation) == (n, n) || throw(ArgumentError("$name table must have size ($n, $n)"))
        operation
    elseif operation isa AbstractVector || operation isa Tuple
        length(operation) == n * n || throw(ArgumentError("$name table must contain $(n * n) entries"))
        reshape(collect(operation), n, n)
    elseif applicable(operation, FiniteTruth(1), FiniteTruth(1))
        [operation(FiniteTruth(i), FiniteTruth(j)) for i in 1:n, j in 1:n]
    else
        throw(ArgumentError("$name must be an N×N table or callable binary operation"))
    end
    result = Matrix{UInt8}(undef, n, n)
    for i in 1:n, j in 1:n
        result[i, j] = _index(source[i, j])
    end
    result
end

"""A Sole-compatible finite FLew view over an Aletheia integer-table algebra."""
struct FiniteFLewAlgebra{N}
    join::_FiniteOperation{N}
    meet::_FiniteOperation{N}
    monoid::_FiniteOperation{N}
    implication::_FiniteOperation{N}
    bot::FiniteTruth
    top::FiniteTruth
    native::Aletheia.FiniteFLewAlgebra{N}
end

Base.show(io::IO, algebra::FiniteFLewAlgebra) = print(io, string(typeof(algebra)))
# The payload keeps SoleLogics' shape — a domain of boxed truths and the raw
# carrier tables — because migrating consumers read this view for parity with
# the incumbent.  Only the presentation conventions are Aletheia's: colour when
# the IO context has it, and a shape summary instead of a wall of indices for a
# table too large to read.
function Base.show(io::IO, ::MIME"text/plain", algebra::FiniteFLewAlgebra{N}) where N
    table(operation) = N <= 10 || Aletheia._display_limit(io) == typemax(Int) ?
        string(operation.table) : "$(N)×$(N) carrier table"
    Aletheia._display_header(io, string(typeof(algebra)))
    for (label, content) in (("Domain", getdomain(algebra)), ("Bot", algebra.bot), ("Top", algebra.top),
            ("Join", table(algebra.join)), ("Meet", table(algebra.meet)),
            ("T-norm", table(algebra.monoid)), ("Implication", table(algebra.implication)))
        Aletheia._display_label(io, 0, label)
        print(io, content)
    end
end

function _wrap_algebra(native::Aletheia.FiniteFLewAlgebra{N}) where N
    FiniteFLewAlgebra{N}(
        _FiniteOperation{N}(native.join),
        _FiniteOperation{N}(native.meet),
        _FiniteOperation{N}(native.monoid),
        _FiniteOperation{N}(native.implication),
        FiniteTruth(native.bot), FiniteTruth(native.top), native)
end
FiniteFLewAlgebra(native::Aletheia.FiniteFLewAlgebra) = _wrap_algebra(native)

function FiniteFLewAlgebra{N}(join, meet, monoid, bot, top) where N
    N isa Integer && 1 <= N <= typemax(UInt8) ||
        throw(ArgumentError("FiniteFLewAlgebra parameter N must be an integer in 1:255"))
    n = Int(N)
    native = Aletheia.FiniteFLewAlgebra(
        _operation_table(join, n, "join"),
        _operation_table(meet, n, "meet"),
        _operation_table(monoid, n, "monoid"),
        _index(bot), _index(top))
    _wrap_algebra(native)
end

function FiniteFLewAlgebra(join, meet, monoid, bot, top)
    n = if join isa AbstractMatrix
        size(join, 1) == size(join, 2) || throw(ArgumentError("join table must be square"))
        size(join, 1)
    elseif join isa AbstractVector || join isa Tuple
        r = isqrt(length(join)); r * r == length(join) ||
            throw(ArgumentError("join table must contain a square number of entries"))
        r
    else
        throw(ArgumentError("use FiniteFLewAlgebra{N} for callable operations"))
    end
    FiniteFLewAlgebra{n}(join, meet, monoid, bot, top)
end

# Sole's order and domain protocol, with the same threshold semantics as its
# order-utilities.jl implementation.  Values are wrapped on the way out.
getdomain(algebra::FiniteFLewAlgebra{N}) where N = ntuple(FiniteTruth, N)
getdomain(algebra::Aletheia.FiniteFLewAlgebra{N}) where N = ntuple(FiniteTruth, N)
getdomain(algebra::Aletheia.TruthAlgebra) = Aletheia.domain(algebra)
getdomain(args...) = _unsupported(:getdomain, "the supplied value is not a finite algebra")

@inline function precedeq(algebra::FiniteFLewAlgebra, left, right)
    l, r = convert(FiniteTruth, left), convert(FiniteTruth, right)
    algebra.meet(l, r) == l
end
@inline succeedeq(algebra::FiniteFLewAlgebra, left, right) = precedeq(algebra, right, left)
@inline function precedes(algebra::FiniteFLewAlgebra, left, right)
    l, r = convert(FiniteTruth, left), convert(FiniteTruth, right)
    l != r && precedeq(algebra, l, r)
end
@inline succeedes(algebra::FiniteFLewAlgebra, left, right) =
    precedes(algebra, right, left)

function maximalmembers(algebra::FiniteFLewAlgebra, threshold)
    threshold = convert(FiniteTruth, threshold)
    candidates = filter(value -> !succeedeq(algebra, value, threshold), getdomain(algebra))
    [candidate for candidate in candidates if
        isempty(filter(value -> succeedes(algebra, value, candidate), candidates))]
end
function minimalmembers(algebra::FiniteFLewAlgebra, threshold)
    threshold = convert(FiniteTruth, threshold)
    candidates = filter(value -> !precedeq(algebra, value, threshold), getdomain(algebra))
    [candidate for candidate in candidates if
        isempty(filter(value -> precedes(algebra, value, candidate), candidates))]
end

# Native Aletheia finite algebras are accepted at this boundary as well.  The
# order protocol still returns Sole carriers, so a consumer can mix a native
# table with the compatibility thresholds without an accidental dispatch gap.
precedeq(algebra::Aletheia.FiniteFLewAlgebra, left, right) =
    precedeq(_wrap_algebra(algebra), left, right)
precedes(algebra::Aletheia.FiniteFLewAlgebra, left, right) =
    precedes(_wrap_algebra(algebra), left, right)
succeedeq(algebra::Aletheia.FiniteFLewAlgebra, left, right) =
    succeedeq(_wrap_algebra(algebra), left, right)
succeedes(algebra::Aletheia.FiniteFLewAlgebra, left, right) =
    succeedes(_wrap_algebra(algebra), left, right)
maximalmembers(algebra::Aletheia.FiniteFLewAlgebra, threshold) =
    maximalmembers(_wrap_algebra(algebra), threshold)
minimalmembers(algebra::Aletheia.FiniteFLewAlgebra, threshold) =
    minimalmembers(_wrap_algebra(algebra), threshold)

function _unsupported(name::Symbol, detail::AbstractString)
    throw(ArgumentError("SoleLogics.ManyValuedLogics.$name has no faithful Aletheia equivalent: $detail"))
end
precedeq(args...) = _unsupported(:precedeq, "the first argument must be a finite FLew algebra")
succeedeq(args...) = _unsupported(:succeedeq, "the first argument must be a finite FLew algebra")
maximalmembers(args...) = _unsupported(:maximalmembers, "the first argument must be a finite FLew algebra")
minimalmembers(args...) = _unsupported(:minimalmembers, "the first argument must be a finite FLew algebra")

# Continuous truth remains outside this bridge; finite values are the protocol
# needed by SoleReasoners' tableaux.
abstract type ContinuousTruth end
(::Type{ContinuousTruth})(args...) = _unsupported(:ContinuousTruth,
    "Aletheia's continuous chains use Float64 values rather than Sole truth objects")

const GodelAlgebra = Aletheia.GodelAlgebra
const LukasiewiczAlgebra = Aletheia.LukasiewiczAlgebra
const BooleanAlgebra = Aletheia.BooleanAlgebra

# Aletheia's named algebras are the source of truth.  The compatibility view
# only supplies the old callable operation/carrier vocabulary at the boundary.
const booleanalgebra = _wrap_algebra(Aletheia.BooleanFLewAlgebra)
const G3 = _wrap_algebra(Aletheia.G3)
const G4 = _wrap_algebra(Aletheia.G4)
const G5 = _wrap_algebra(Aletheia.G5)
const G6 = _wrap_algebra(Aletheia.G6)
const H4 = _wrap_algebra(Aletheia.H4)
const H6 = _wrap_algebra(Aletheia.H6)
const H6_1 = _wrap_algebra(Aletheia.H6_1)
const H6_2 = _wrap_algebra(Aletheia.H6_2)
const H6_3 = _wrap_algebra(Aletheia.H6_3)
const H9 = _wrap_algebra(Aletheia.H9)
const Ł3 = _wrap_algebra(Aletheia.Ł3)
const Ł4 = _wrap_algebra(Aletheia.Ł4)
const α = FiniteTruth(3)
const β = FiniteTruth(4)
const BASE_MANY_VALUED_CONNECTIVES = [Aletheia.:∨, Aletheia.:∧, Aletheia.:→]

export FiniteTruth, ContinuousTruth, FiniteFLewAlgebra, getdomain
export GodelAlgebra, LukasiewiczAlgebra, BooleanAlgebra
export booleanalgebra, precedeq, precedes, succeedeq, succeedes, maximalmembers, minimalmembers
export α, β, BASE_MANY_VALUED_CONNECTIVES
end

# Truth leaves are represented as payloads in Aletheia's atom-only DAG.  Keep
# that representation out of the core evaluator's hot path, but adapt it when
# the opt-in compatibility `check`/`interpret` entry point sees one: a truth
# payload is a constant of the model's algebra, never a valuation key.
function _truth_payload(node)
    node isa Truth && return node
    if node isa Atom || node isa Aletheia.Atom
        payload = value(node)
        payload isa Truth && return payload
    end
    nothing
end
function _contains_truth(formula)
    formula isa Truth && return true
    any(node -> _truth_payload(node) !== nothing, formulas(formula))
end
function _truth_carrier(truth::Truth, algebra::Aletheia.TruthAlgebra)
    if truth isa BooleanTruth
        return istop(truth) ? Aletheia.top(algebra) : Aletheia.bottom(algebra)
    elseif truth isa ManyValuedLogics.FiniteTruth
        if algebra isa Aletheia.FiniteFLewAlgebra
            truth.index <= length(algebra) || throw(ArgumentError(
                "finite truth index $(truth.index) is outside the model algebra domain"))
            return truth.index
        elseif algebra isa Aletheia.BooleanAlgebra
            truth.index == UInt8(1) && return true
            truth.index == UInt8(2) && return false
        end
    end
    _unsupported(:check,
        "truth leaf $(repr(truth)) cannot be interpreted in $(typeof(algebra))")
end
function _truth_model(model::Aletheia.Model)
    valuation = (atom, world) -> begin
        truth = _truth_payload(atom)
        truth === nothing ?
            Aletheia._lookup_valuation(Aletheia.valuation(model), atom, world) :
            _truth_carrier(truth, Aletheia.algebra(model))
    end
    Aletheia.Model(Aletheia.frame(model), Aletheia.algebra(model), valuation)
end
function check(formula::Truth, model::Aletheia.Model, world)
    _truth_carrier(formula, Aletheia.algebra(model))
end
function check(formula::Aletheia.Formula, model::Aletheia.Model, args...)
    native = _unwrap(formula)
    _contains_truth(formula) ? Aletheia.check(native, _truth_model(model), args...) :
        Aletheia.check(native, model, args...)
end
function interpret(formula::Truth, model::Aletheia.Model, world)
    _truth_carrier(formula, Aletheia.algebra(model))
end
function interpret(formula::Aletheia.Formula, model::Aletheia.Model, args...)
    native = _unwrap(formula)
    _contains_truth(formula) ? Aletheia.interpret(native, _truth_model(model), args...) :
        Aletheia.interpret(native, model, args...)
end

export Formula, SyntaxStructure, SyntaxTree, SyntaxLeaf, SyntaxBranch, Branch
export Atom, AbstractAtom, AbstractRelation, Operator, Connective, NamedConnective
export BoxRelationalConnective, DiamondRelationalConnective
export Interval, Interval2D, Point, Point1D, Point2D, FullDimensionalFrame, diamond, box
export IA_A, IA_L, IA_B, IA_E, IA_D, IA_O, IA_Ai, IA_Li, IA_Bi, IA_Ei, IA_Di, IA_Oi
export token, op, tree, children, value, nchildren, arity, syntaxstring, hasdual, dual, relation
export formulas, subformulas, atoms, leaves, connectives, operators, ntokens, natoms, nleaves
export nconnectives, noperators, height, conjuncts, disjuncts, grandchildren, nconjuncts
export AbstractSyntaxStructure, ngrandchildren, connective, pushconjunct!
export AbstractAlphabet, ExplicitAlphabet, UnionAlphabet, subalphabets, randatom, randformula
export parseformula, check, interpret, frame, algebra, domain, top, bot, worlds, allworlds
export accessible, accessibles, collateworlds, worldtype
export AbstractFrame, AbstractUniModalFrame, AbstractMultiModalFrame
export AbstractWorld, AbstractWorlds, AnyWorld, AbstractRelationalConnective
export globalrel, identityrel, GlobalRel, IdentityRel, AtWorldRelation
export tocenterrel, ToCenterRel, centralworld, emptyworld
export ismodal, isunary, isdiamond, isbox, isgrounding, isgrounded
export Truth, BooleanTruth, TOP, BOT, ⊤, ⊥, istop, isbot, truths, collatetruth
export dnf, cnf, normalize, LeftmostLinearForm, LeftmostConjunctiveForm
export LeftmostDisjunctiveForm, DNF, CNF, Literal, AbstractInterpretationSet, ispos
export IARelations, IA7Relations, IA3Relations, IA_AorO, IA_DorBorE, IA_AiorOi,
    IA_DiorBiorEi, IA_I, RCC5Relations, RCC8Relations, Topo_DR, Topo_PP, Topo_PPi,
    alphabet, feature, condition, threshold, name, sample
export TruthDict, KripkeStructure
export ManyValuedLogics
for name in (:CL_N, :CL_S, :CL_E, :CL_W, :CL_NE, :CL_NW, :CL_SE, :CL_SW,
    :LRCC8_Rec_DC, :LRCC8_Rec_EC, :LRCC8_Rec_PO, :LRCC8_Rec_TPP,
    :LRCC8_Rec_TPPi, :LRCC8_Rec_NTPP, :LRCC8_Rec_NTPPi,
    :HS_A, :HS_L, :HS_B, :HS_E, :HS_D, :HS_O,
    :HS_Ai, :HS_Li, :HS_Bi, :HS_Ei, :HS_Di, :HS_Oi,
    :LTLFP_F, :LTLFP_P)
    @eval export $(name)
end

# Sole's dnf/cnf return leftmost containers of literals, and consumers dispatch
# on that shape.  The normal form itself is Aletheia's; only the container is
# rebuilt here.
function _literal(formula, literaltype::Type)
    literaltype === Literal || _unsupported(:dnf,
        "literal type $(literaltype) is not supported; use Literal")
    if (formula isa _CompatBranch || formula isa Aletheia.Branch) &&
            _native_connective(formula) isa Aletheia.Negation
        return Literal(false, _wrap(children(formula)[1]))
    end
    Literal(true, _wrap(formula))
end
function _normal_form(formula::Aletheia.Formula, native, outer, inner, literaltype)
    terms = _flatten(_wrap(native(_unwrap(formula))), outer)
    LeftmostLinearForm(outer(), [LeftmostLinearForm(inner(),
        [_literal(literal, literaltype) for literal in _flatten(term, inner)]) for term in terms])
end
function dnf(formula::Aletheia.Formula, literaltype::Type=Literal; kwargs...)
    isempty(kwargs) || _unsupported(:dnf,
        "Aletheia's normal forms take no normalization keyword(s)")
    _normal_form(formula, Aletheia.dnf, Aletheia.Disjunction, Aletheia.Conjunction, literaltype)
end
function cnf(formula::Aletheia.Formula, literaltype::Type=Literal; kwargs...)
    isempty(kwargs) || _unsupported(:cnf,
        "Aletheia's normal forms take no normalization keyword(s)")
    _normal_form(formula, Aletheia.cnf, Aletheia.Conjunction, Aletheia.Disjunction, literaltype)
end

# Aletheia names useful to a consumer that is being migrated incrementally.
const FormulaPool = Aletheia.FormulaPool
const Signature = Aletheia.Signature
const parse = Aletheia.parse
const Model = Aletheia.Model
const Valuation = Aletheia.Valuation
const TruthAlgebra = Aletheia.TruthAlgebra
const BooleanAlgebra = Aletheia.BooleanAlgebra
const GodelAlgebra = Aletheia.GodelAlgebra
const LukasiewiczAlgebra = Aletheia.LukasiewiczAlgebra
export FormulaPool, Signature, atom, branch, parse, Model, Valuation, TruthAlgebra
export BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export ¬, ∧, ∨, →
const ¬ = Aletheia.:¬
const ∧ = Aletheia.:∧
const ∨ = Aletheia.:∨
const → = Aletheia.:→

end
