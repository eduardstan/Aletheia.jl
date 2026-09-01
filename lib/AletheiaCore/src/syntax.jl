# Syntax is deliberately independent of interpretation and truth values.

"""
    arity(connective)

Return the finite arity of a connective.  This is a trait: packages defining a
connective only need to add a method for their own value or type.
"""
function arity(connective)
    if connective isa Negation
        1
    elseif connective isa Conjunction || connective isa Fusion || connective isa Disjunction || connective isa Implication
        2
    elseif connective isa Diamond || connective isa Box
        1
    else
        throw(MethodError(arity, (connective,)))
    end
end

"""
    dual(connective)

Return the syntactic dual of `connective`, or throw when no dual is declared.
Duality is only a connective property; this layer does not interpret formulas.
"""
function dual(connective)
    if connective isa Negation
        NEGATION
    elseif connective isa Conjunction
        DISJUNCTION
    elseif connective isa Fusion
        throw(ArgumentError("no dual is declared for Fusion"))
    elseif connective isa Disjunction
        CONJUNCTION
    elseif connective isa Diamond
        Box(connective.relation)
    elseif connective isa Box
        Diamond(connective.relation)
    else
        throw(ArgumentError("no dual is declared for $(typeof(connective))"))
    end
end

"""
    hasdual(connective)

Return whether a connective has a syntactic dual.
"""
function hasdual(connective)
    connective isa Negation || connective isa Conjunction || connective isa Disjunction ||
        connective isa Diamond || connective isa Box
end

"""
    precedence(connective)

Return the binding precedence used by the printer and parser.  Larger values
bind more tightly.  Custom connectives should define this trait when they are
printed in infix or prefix notation.
"""
function precedence(connective)
    if connective isa Negation
        80
    elseif connective isa Diamond || connective isa Box
        90
    elseif connective isa Conjunction
        30
    elseif connective isa Fusion
        35
    elseif connective isa Disjunction
        20
    elseif connective isa Implication
        10
    else
        0
    end
end

"""
    associativity(connective)

Return `:left`, `:right`, or `:none` for a connective.  The default is
`:none`, which makes equal-precedence children parenthesized conservatively.
"""
function associativity(connective)
    if connective isa Negation || connective isa Diamond || connective isa Box
        :right
    elseif connective isa Conjunction || connective isa Fusion || connective isa Disjunction
        :left
    elseif connective isa Implication
        :right
    else
        :none
    end
end

"""
    commutative(connective)

Return whether a connective is commutative.  Commutativity is recorded as a
trait for later normalization stages; it never changes syntax or equality.
"""
function commutative(connective)
    connective isa Conjunction || connective isa Fusion || connective isa Disjunction
end

"""
    modality(connective)

Return whether a connective is a modality.  This is a syntactic trait and has
no semantic consequence in the syntax layer.
"""
function modality(connective)
    connective isa Diamond || connective isa Box
end

"""
    notation(connective)

Return the text used for a connective in formulas.  Defining this trait is the
only printing hook needed by a user-defined connective.
"""
function notation(connective)
    if connective isa Negation
        "¬"
    elseif connective isa Conjunction
        "∧"
    elseif connective isa Fusion
        "⊗"
    elseif connective isa Disjunction
        "∨"
    elseif connective isa Implication
        "→"
    elseif connective isa Diamond
        "⟨$(connective.relation)⟩"
    elseif connective isa Box
        "[$(connective.relation)]"
    else
        string(connective)
    end
end

"""Readable predicate alias for the internal `commutative` trait."""
iscommutative(connective) = commutative(connective)

"""Alias for [`modality`](@ref)."""
ismodality(connective) = modality(connective)

"""
    Signature(connectives)

A Blackburn–de Rijke–Venema similarity type: a finite tuple of connective
values together with the arity of each value.  Arity is read from the
[`arity`](@ref) trait, so extending a signature never requires changing
Aletheia's source.  `Signature(connectives, arities)` is also accepted when
an explicit declaration is useful, and is checked against the trait.
"""
struct Signature{C<:Tuple,A<:Tuple}
    connectives::C
    arities::A
    function Signature(cs::C, as::A) where {C<:Tuple,A<:Tuple}
        length(cs) == length(as) || throw(ArgumentError("connectives and arities must have equal lengths"))
        isempty(cs) && throw(ArgumentError("a signature must contain a connective"))
        checked = ntuple(i -> begin
            n = as[i]
            n isa Integer && n >= 0 || throw(ArgumentError("arity must be a non-negative integer"))
            Int(n)
        end, length(as))
        trait_arities = ntuple(i -> arity(cs[i]), length(cs))
        trait_arities == checked || throw(ArgumentError("declared arities disagree with arity traits"))
        texts = map(notation, cs)
        all(text -> text isa AbstractString && !isempty(text), texts) ||
            throw(ArgumentError("connective notation must be non-empty text"))
        all(text -> all(c -> !isspace(c) && c != '(' && c != ')' && c != ',' && c != '"', text), texts) ||
            throw(ArgumentError("connective notation cannot contain whitespace or delimiters"))
        length(unique(texts)) == length(cs) ||
            throw(ArgumentError("connective notation must be unique within a signature"))
        new{C,typeof(checked)}(cs, checked)
    end
end

function Signature(cs::AbstractVector)
    Signature(tuple(cs...))
end

function Signature(cs::AbstractVector, as::AbstractVector)
    Signature(tuple(cs...), tuple(as...))
end

function Signature(cs::Tuple)
    isempty(cs) && throw(ArgumentError("a signature must contain a connective"))
    as = ntuple(i -> begin
        n = arity(cs[i])
        n isa Integer && n >= 0 || throw(ArgumentError("arity must be a non-negative integer"))
        Int(n)
    end, length(cs))
    Signature(cs, as)
end

"""Return the connectives in a [`Signature`](@ref), in declaration order."""
connectives(signature::Signature) = signature.connectives

"""Return the arity declared for `connective` in `signature`."""
function arity(signature::Signature, connective)
    for i in eachindex(signature.connectives)
        isequal(signature.connectives[i], connective) && return signature.arities[i]
    end
    throw(ArgumentError("connective $(repr(connective)) is not in the signature"))
end

"""Return whether `connective` belongs to `signature`."""
function hasconnective(signature::Signature, connective)
    any(c -> isequal(c, connective), signature.connectives)
end

# Hash-consed payloads must not be mutable.  The check is recursive so an
# immutable wrapper around a mutable value (for example, `Diamond([:R])`) is
# rejected as well.  Strings and symbols are immutable at the language level
# even though Julia represents their types as mutable reference types.
#
# Most syntax payload types are closed immutable structs.  Classify those at
# compile time so the common guard does not allocate a cycle-detection table.
# A field with an abstract type (including `Any`) remains value-dependent and
# uses the original recursive walk, which is still required for mutable values
# hidden behind immutable wrappers and for cycles.
function _payload_static_immutability(T, active=Set{Any}())
    (T === String || T === Symbol || T <: Type) && return true
    T <: Ptr && return false
    if T isa Union
        statuses = map(U -> _payload_static_immutability(U, active), Base.uniontypes(T))
        all(status -> status === true, statuses) && return true
        all(status -> status === false, statuses) && return false
        return nothing
    end
    isconcretetype(T) || return nothing
    isbitstype(T) && !isstructtype(T) && return true
    ismutabletype(T) && return false
    fieldcount(T) == 0 && return true
    T in active && return nothing
    push!(active, T)
    try
        for i in 1:fieldcount(T)
            status = _payload_static_immutability(fieldtype(T, i), active)
            status === true || return status
        end
        true
    finally
        delete!(active, T)
    end
end

function _payload_is_immutable_dynamic(value, seen)
    (value isa String || value isa Symbol || value isa Type) && return true
    value isa Ptr && return false
    T = typeof(value)
    isbitstype(T) && !isstructtype(T) && return true
    ismutabletype(T) && return false
    haskey(seen, value) && return true
    seen[value] = nothing
    for i in 1:fieldcount(T)
        _payload_is_immutable_dynamic(getfield(value, i), seen) || return false
    end
    true
end

# Retain the explicit-seen form for internal callers that need to share a
# cycle detector; the one-argument form below takes the allocation-free path
# whenever the payload type is statically closed.
_payload_is_immutable(value, seen) = _payload_is_immutable_dynamic(value, seen)

@generated function _payload_is_immutable(value::T) where T
    status = _payload_static_immutability(T)
    status === true && return :(true)
    status === false && return :(false)
    :(_payload_is_immutable_dynamic(value, IdDict{Any,Nothing}()))
end

function _require_immutable_payload(value, role::AbstractString)
    _payload_is_immutable(value) ||
        throw(ArgumentError("$role must be immutable; mutable payloads cannot be interned"))
    value
end

# Internal pool records use ids in their key; no formula tree is ever used as a
# dictionary key.  This is the important difference from structural tree hashing.
struct _PoolNode
    kind::UInt8
    payload::Any
    children::Tuple{Vararg{Int}}
end

"""
    FormulaPool(signature)

Create an explicit, thread-safe hash-consing pool for formulas over `signature`.
Pools are explicit rather than global: formulas from different pools cannot be
mistaken for one another, while a pool may safely be shared by threads.
"""
mutable struct FormulaPool{S<:Signature}
    signature::S
    index::Dict{Any,Int}
    nodes::Vector{_PoolNode}
    lock::ReentrantLock
end

function FormulaPool(signature::Signature)
    FormulaPool(signature, Dict{Any,Int}(), _PoolNode[], ReentrantLock())
end

"""Return the signature associated with a formula pool."""
signature(pool::FormulaPool) = pool.signature

"""
    Formula

The common syntax-only interface implemented by [`Atom`](@ref) and
[`Branch`](@ref).  Formula subtypes are concrete immutable values; this marker
contains no truth values, semantic state, or evaluator hooks.
"""
abstract type Formula end

# Pool nodes are trusted after interning.  This private tag selects the
# allocation-only constructors used when rebuilding handles from those nodes;
# callers supplying formula fields still go through the validating methods.
struct _TrustedFormulaHandle end
const _trusted_formula_handle = _TrustedFormulaHandle()

"""
    Atom(pool, value)

Intern `value` as an atom in `pool`.  Atoms are immutable concrete formulas;
their integer id is stable for the lifetime of the pool.  The payload must be
immutable, including values nested in an immutable wrapper, so its hash cannot
change after interning.  Documented and exported construction paths validate
that the pool record exists and matches the supplied fields, so they cannot
forge a handle.  Internal reconstruction from an already-validated pool node
uses a private trusted path for performance; it is an implementation detail,
not an external trust boundary.
"""
struct Atom{V,P<:FormulaPool} <: Formula
    pool::P
    id::Int
    value::V

    # Internal reconstruction from an already-validated pool node.
    function Atom(pool::P, id::Int, value::V, ::_TrustedFormulaHandle) where {V,P<:FormulaPool}
        new{V,P}(pool, id, value)
    end

    function Atom(pool::P, id::Int, value::V) where {V,P<:FormulaPool}
        _require_immutable_payload(value, "atom payload")
        lock(pool.lock)
        try
            1 <= id <= length(pool.nodes) ||
                throw(ArgumentError("atom id $id is not present in its FormulaPool"))
            node = pool.nodes[id]
            node.kind == 0x01 ||
                throw(ArgumentError("formula id $id is not an atom"))
            isequal(node.payload, value) ||
                throw(ArgumentError("atom payload does not match formula id $id"))
        finally
            unlock(pool.lock)
        end
        new{V,P}(pool, id, value)
    end
end

"""
    Branch(pool, connective, children...)

Intern a connective application in `pool`.  The number of children must equal
the connective's declared arity.  A branch stores only pool-local child ids;
[`children`](@ref) reconstructs immutable handles when they are requested.
The connective payload must be immutable, including values nested in an
immutable wrapper.  Children must have been made by the same pool, which keeps
ids local and makes equality an integer comparison.  Documented and exported
construction paths validate that the pool record exists and matches the
supplied fields, so they cannot forge a handle.  Internal reconstruction from
an already-validated pool node uses a private trusted path for performance; it
is an implementation detail, not an external trust boundary.
"""
struct Branch{C,N,P<:FormulaPool} <: Formula
    pool::P
    id::Int
    connective::C
    children::NTuple{N,Int}

    # Internal reconstruction from an already-validated pool node.
    function Branch(pool::P, id::Int, connective::C, children::NTuple{N,Int}, ::_TrustedFormulaHandle) where {C,N,P<:FormulaPool}
        new{C,N,P}(pool, id, connective, children)
    end

    function Branch(pool::P, id::Int, connective::C, children::NTuple{N,Int}) where {C,N,P<:FormulaPool}
        _require_immutable_payload(connective, "branch connective")
        lock(pool.lock)
        try
            1 <= id <= length(pool.nodes) ||
                throw(ArgumentError("branch id $id is not present in its FormulaPool"))
            node = pool.nodes[id]
            node.kind == 0x02 ||
                throw(ArgumentError("formula id $id is not a branch"))
            isequal(node.payload, connective) ||
                throw(ArgumentError("branch connective does not match formula id $id"))
            node.children == children ||
                throw(ArgumentError("branch children do not match formula id $id"))
            all(1 <= child <= length(pool.nodes) for child in children) ||
                throw(ArgumentError("branch id $id contains an invalid child id"))
        finally
            unlock(pool.lock)
        end
        new{C,N,P}(pool, id, connective, children)
    end
end

"""Return the signature of an atom."""
signature(formula::Atom) = signature(formula.pool)

"""Return the signature of a branch."""
signature(formula::Branch) = signature(formula.pool)

@inline _formula_pool(atom::Atom) = atom.pool
@inline _formula_pool(branch::Branch) = branch.pool
@inline _formula_id(atom::Atom) = atom.id
@inline _formula_id(branch::Branch) = branch.id

"""Return the pool owning a formula."""
pool(formula::Atom) = _formula_pool(formula)
pool(formula::Branch) = _formula_pool(formula)

"""Return the hash-consed integer id of a formula."""
id(formula::Atom) = _formula_id(formula)
id(formula::Branch) = _formula_id(formula)

"""Return the atom's payload."""
value(atom::Atom) = atom.value

"""Return the connective at a branch."""
operator(branch::Branch) = branch.connective

"""Alias for [`operator`](@ref), useful when treating a branch as an application."""
head(branch::Branch) = operator(branch)

"""
    nchildren(formula)

Return the number of immediate children of a formula.  This name keeps the
formula accessor distinct from the `arity` trait for connective values.
"""
nchildren(::Atom) = 0
nchildren(branch::Branch) = length(branch.children)

"""Return the number of immediate children; retained as an alias for `nchildren`."""
arity(formula::Atom) = nchildren(formula)
arity(formula::Branch) = nchildren(formula)

function _branch_from_ids(pool::FormulaPool, id::Int, connective, ids, ::Val{N}) where N
    typed_ids = ntuple(i -> ids[i], N)
    Branch(pool, id, connective, typed_ids, _trusted_formula_handle)
end

function _formula_unlocked(pool::FormulaPool, id::Int)
    node = pool.nodes[id]
    if node.kind == 0x01
        Atom(pool, id, node.payload, _trusted_formula_handle)
    else
        _branch_from_ids(pool, id, node.payload, node.children, Val(length(node.children)))
    end
end

function _formula(pool::FormulaPool, id::Int)
    lock(pool.lock)
    try
        1 <= id <= length(pool.nodes) || throw(BoundsError(pool.nodes, id))
        _formula_unlocked(pool, id)
    finally
        unlock(pool.lock)
    end
end

"""Return a formula's immediate children, rebuilding pool handles as needed."""
children(::Atom) = ()

function children(branch::Branch{C,N,P}) where {C,N,P}
    pool = branch.pool
    lock(pool.lock)
    try
        ntuple(i -> _formula_unlocked(pool, branch.children[i]), N)
    finally
        unlock(pool.lock)
    end
end

"""Return whether a formula is an atom."""
isatom(::Atom) = true
isatom(::Branch) = false

"""Return whether a formula is a connective branch."""
isbranch(::Atom) = false
isbranch(::Branch) = true

"""
    isgrounded(formula)

Return whether a formula is grounded according to SoleLogics' syntactic
criterion: a grounding relational connective grounds its whole branch, while
all other connective branches are grounded only when every child is grounded.
"""
function isgrounded(formula::Formula)
    isatom(formula) && return false
    connective = operator(formula)
    (connective isa AbstractRelationalConnective && isgrounding(relation(connective))) ||
        all(isgrounded, children(formula))
end

function _intern!(pool::FormulaPool, kind::UInt8, payload, childids::Tuple{Vararg{Int}})
    role = kind == 0x01 ? "atom payload" : "branch connective"
    _require_immutable_payload(payload, role)
    key = kind == 0x01 ? (:atom, payload) : (:branch, payload, childids)
    lock(pool.lock)
    try
        existing = get(pool.index, key, 0)
        existing != 0 && return existing
        new_id = length(pool.nodes) + 1
        push!(pool.nodes, _PoolNode(kind, payload, childids))
        pool.index[key] = new_id
        return new_id
    finally
        unlock(pool.lock)
    end
end

"""Intern an atom, returning the canonical atom value for this pool and payload."""
function atom(pool::FormulaPool, value)
    atom_id = _intern!(pool, 0x01, value, ())
    Atom(pool, atom_id, value, _trusted_formula_handle)
end

# This method makes the type constructor spelling useful; the full-field
# constructor above validates any externally supplied pool record and payload.
Atom(pool::FormulaPool, value) = atom(pool, value)

function _branch_children(pool::FormulaPool, childtuple::Tuple)
    ids = ntuple(i -> begin
        child = childtuple[i]
        (child isa Atom || child isa Branch) || throw(ArgumentError("branch children must be formulas"))
        _formula_pool(child) === pool || throw(ArgumentError("all children must belong to the same FormulaPool"))
        _formula_id(child)
    end, length(childtuple))
    ids
end

"""Intern a branch from a tuple of immediate children."""
function branch(pool::FormulaPool, connective, childtuple::Tuple)
    arity(pool.signature, connective) == length(childtuple) ||
        throw(ArgumentError("$(repr(connective)) expects $(arity(pool.signature, connective)) children, got $(length(childtuple))"))
    ids = _branch_children(pool, childtuple)
    branch_id = _intern!(pool, 0x02, connective, ids)
    _branch_from_ids(pool, branch_id, connective, ids, Val(length(ids)))
end

"""Intern a branch from vararg immediate children."""
branch(pool::FormulaPool, connective, children...) = branch(pool, connective, children)

# See the Atom constructor note above.
Branch(pool::FormulaPool, connective, children::Tuple) = branch(pool, connective, children)
Branch(pool::FormulaPool, connective, children...) = branch(pool, connective, children)

"""Return the number of distinct terms currently interned in `pool`."""
function nsubterms(pool::FormulaPool)
    lock(pool.lock)
    try
        length(pool.nodes)
    finally
        unlock(pool.lock)
    end
end

"""Return all pool ids in dependency order (children always precede parents)."""
function subterms(pool::FormulaPool)
    lock(pool.lock)
    try
        collect(1:length(pool.nodes))
    finally
        unlock(pool.lock)
    end
end

function _reachable!(pool::FormulaPool, current::Int, seen::Set{Int})
    current in seen && return
    push!(seen, current)
    node = pool.nodes[current]
    for child in node.children
        _reachable!(pool, child, seen)
    end
    nothing
end

"""Return the distinct ids in a formula's subterm DAG, dependency first."""
function subterms(formula::Atom)
    _subterms(formula)
end
function subterms(formula::Branch)
    _subterms(formula)
end

function _subterms(formula)
    p = _formula_pool(formula)
    seen = Set{Int}()
    lock(p.lock)
    try
        _reachable!(p, _formula_id(formula), seen)
    finally
        unlock(p.lock)
    end
    result = collect(seen)
    sort!(result)
    result
end

"""Return the number of distinct subterms reachable from `formula`."""
nsubterms(formula::Atom) = length(subterms(formula))
nsubterms(formula::Branch) = length(subterms(formula))

"""
    DAGNode

A compact read-only view of one hash-consed DAG node.  `kind` is `:atom` or
`:branch`; `payload` is respectively the atom value or connective, and
`children` contains ids in the same pool.
"""
struct DAGNode
    id::Int
    kind::Symbol
    payload::Any
    children::Tuple{Vararg{Int}}
end

function _dag_node(pool::FormulaPool, i::Int)
    node = pool.nodes[i]
    if node.kind == 0x01
        DAGNode(i, :atom, node.payload, ())
    else
        DAGNode(i, :branch, node.payload, node.children)
    end
end

"""Return the complete pool DAG in dependency order."""
function dag(pool::FormulaPool)
    lock(pool.lock)
    try
        [_dag_node(pool, i) for i in eachindex(pool.nodes)]
    finally
        unlock(pool.lock)
    end
end

"""Return the subterm DAG reachable from `formula`, in dependency order."""
function dag(formula::Atom)
    _dag_formula(formula)
end
function dag(formula::Branch)
    _dag_formula(formula)
end

function _dag_formula(formula)
    p = _formula_pool(formula)
    ids = subterms(formula)
    lock(p.lock)
    try
        [_dag_node(p, i) for i in ids]
    finally
        unlock(p.lock)
    end
end

"""Return the DAG node for an id in `pool`."""
function dag(pool::FormulaPool, i::Integer)
    lock(pool.lock)
    try
        1 <= i <= length(pool.nodes) || throw(BoundsError(pool.nodes, i))
        _dag_node(pool, Int(i))
    finally
        unlock(pool.lock)
    end
end

# Equality is deliberately not recursive: ids are canonical within one pool.
Base.isequal(a::Atom, b::Atom) = a.pool === b.pool && a.id == b.id
Base.isequal(a::Branch, b::Branch) = a.pool === b.pool && a.id == b.id
Base.isequal(::Atom, ::Branch) = false
Base.isequal(::Branch, ::Atom) = false
Base.:(==)(a::Atom, b::Atom) = a.pool === b.pool && a.id == b.id
Base.:(==)(a::Branch, b::Branch) = a.pool === b.pool && a.id == b.id
Base.:(==)(::Atom, ::Branch) = false
Base.:(==)(::Branch, ::Atom) = false
Base.hash(a::Atom, h::UInt) = hash(objectid(a.pool), hash(a.id, h))
Base.hash(a::Branch, h::UInt) = hash(objectid(a.pool), hash(a.id, h))

# Built-in syntax-only connectives.  Their values are ordinary structs; the
# modal values carry their relation as data rather than encoding it in a type.
struct Negation end
struct Conjunction end
"""Stateless syntax marker for multiplicative conjunction (fusion)."""
struct Fusion end
struct Disjunction end
struct Implication end

"""Abstract vocabulary shared by relational modal connectives."""
abstract type AbstractRelationalConnective{R} end
"""
    Diamond(relation)

A unary modal connective carrying `relation` as a value.  The relation is a
field, not a type parameter encoded in a singleton, so parametric relations
remain ordinary syntax values.
"""
struct Diamond{R} <: AbstractRelationalConnective{R}
    relation::R
end

"""
    Box(relation)

The syntactic dual modal connective for [`Diamond`](@ref), carrying its
relation as a value.
"""
struct Box{R} <: AbstractRelationalConnective{R}
    relation::R
end

# SoleLogics-compatible modal/connective predicates.  These predicates
# intentionally default to `false` for non-connective values and
# classify a diamond as any modal connective that is not a box.
ismodal(::Any) = false
ismodal(::Type{<:Diamond}) = true
ismodal(::Type{<:Box}) = true
ismodal(connective::AbstractRelationalConnective) = ismodal(typeof(connective))
isunary(connective) = arity(connective) == 1
isbox(::Any) = false
isbox(::Type{<:Diamond}) = false
isbox(::Type{<:Box}) = true
isbox(connective::AbstractRelationalConnective) = isbox(typeof(connective))
isdiamond(::Any) = false
isdiamond(C::Type) = ismodal(C) && !isbox(C)
isdiamond(connective::AbstractRelationalConnective) = isdiamond(typeof(connective))

const NEGATION = Negation()
const CONJUNCTION = Conjunction()
const FUSION = Fusion()
const DISJUNCTION = Disjunction()
const IMPLICATION = Implication()
const NOT = NEGATION
const AND = CONJUNCTION
const OR = DISJUNCTION
const IMPLIES = IMPLICATION
"""The prefix negation connective (`¬`)."""
const ¬ = NEGATION
"""The conjunction connective (`∧`)."""
const ∧ = CONJUNCTION
"""The fusion connective (`⊗`)."""
const ⊗ = FUSION
"""The disjunction connective (`∨`)."""
const ∨ = DISJUNCTION
"""The implication connective (`→`)."""
const → = IMPLICATION

"""Return the modal relation carried by a [`Diamond`](@ref) or [`Box`](@ref)."""
relation(modal::Diamond) = modal.relation
relation(modal::Box) = modal.relation

function _atom_text(value, pool::FormulaPool)
    text = string(value)
    spellings = notation.(pool.signature.connectives)
    safe = !isempty(text) && all(c -> !isspace(c) && c != '(' && c != ')' && c != ',' && c != '"', text) &&
        all(spelling -> !occursin(spelling, text), spellings)
    safe && return text
    escaped = replace(replace(text, "\\" => "\\\\"), "\"" => "\\\"")
    "\"$(escaped)\""
end

function _needs_parentheses(parent, child, position::Symbol)
    child isa Branch || return false
    cp = precedence(child.connective)
    pp = precedence(parent)
    cp < pp && return true
    cp > pp && return false
    assoc = associativity(parent)
    assoc == :none && return true
    assoc == :left && position == :right && return true
    assoc == :right && position == :left && return true
    false
end

function _print_formula(formula::Atom, parent, position::Symbol)
    _atom_text(formula.value, formula.pool)
end

function _print_formula(formula::Branch, parent, position::Symbol)
    c = formula.connective
    formula_children = children(formula)
    n = length(formula_children)
    token = notation(c)
    result = if n == 0
        token
    elseif n == 1
        child = formula_children[1]
        text = _print_formula(child, c, :only)
        token * text
    elseif n == 2
        left, right = formula_children
        lt = _print_formula(left, c, :left)
        rt = _print_formula(right, c, :right)
        "$(lt) $(token) $(rt)"
    else
        "$(token)(" * join((_print_formula(ch, nothing, :only) for ch in formula_children), ", ") * ")"
    end
    if parent !== nothing && _needs_parentheses(parent, formula, position)
        "(" * result * ")"
    else
        result
    end
end

"""
    syntaxstring(formula)

Return the canonical parseable text for an atom or branch.  Parentheses are
introduced only when precedence and associativity require them, so modal
examples such as `⟨G⟩p → [G]q` stay readable.
"""
syntaxstring(formula::Atom) = _print_formula(formula, nothing, :root)
syntaxstring(formula::Branch) = _print_formula(formula, nothing, :root)

Base.show(io::IO, formula::Atom) = print(io, syntaxstring(formula))
Base.show(io::IO, formula::Branch) = print(io, syntaxstring(formula))
Base.string(formula::Atom) = syntaxstring(formula)
Base.string(formula::Branch) = syntaxstring(formula)

"""Return a compact text representation of a connective."""
Base.show(io::IO, connective::Negation) = print(io, notation(connective))
Base.show(io::IO, connective::Conjunction) = print(io, notation(connective))
Base.show(io::IO, connective::Fusion) = print(io, notation(connective))
Base.show(io::IO, connective::Disjunction) = print(io, notation(connective))
Base.show(io::IO, connective::Implication) = print(io, notation(connective))
Base.show(io::IO, connective::Diamond) = print(io, notation(connective))
Base.show(io::IO, connective::Box) = print(io, notation(connective))

# ---------------------------------------------------------------------------
# Implicit default pool
#
# The pool is what makes formulas hash-consed; it is not something a reader of
# `(φ ∧ ψ)` should have to name.  These spellings drop the pool argument and
# route to one process-wide pool.  They are opt-in per call site: the pool a
# formula belongs to is still readable from the code, because a call that
# names no pool is exactly a call on `DEFAULT_POOL`.  There is no global mode
# switch, and the explicit `FormulaPool` path is unchanged.

"""
    DEFAULT_SIGNATURE

The similarity type behind the pool-free spellings: the five built-in
propositional connectives [`¬`](@ref), [`∧`](@ref), [`⊗`](@ref), [`∨`](@ref),
and [`→`](@ref).

This tuple is fixed.  Modal and user-defined connectives are not in it, so a
modal language declares its own [`Signature`](@ref) and [`FormulaPool`](@ref);
that is also the textbook reading, in which a modal similarity type is
declared before its formulas are formed.
"""
const DEFAULT_SIGNATURE = Signature((NEGATION, CONJUNCTION, FUSION, DISJUNCTION, IMPLICATION))

"""
    DEFAULT_POOL

The single process-wide [`FormulaPool`](@ref) used by `atom(value)`,
`branch(connective, children...)`, and `parse(Formula, source)` when no pool is
given.

Three properties are worth knowing before using it:

  * **One signature, so no silent collision.** Every formula built through the
    pool-free path lives in this pool over [`DEFAULT_SIGNATURE`](@ref).  Two
    such formulas can never come from incompatible signatures.  A connective
    outside that signature is an `ArgumentError`, and mixing a default-path
    formula with an explicit-pool formula is an `ArgumentError` as well, never
    a wrong answer.
  * **Thread-safe, like every pool.** `FormulaPool` interning is guarded by a
    lock, and the default pool is an ordinary pool.
  * **Never released.** A `const` pool lives for the whole process, so every
    distinct term interned through it is retained.  Long-running processes
    that intern unboundedly many distinct formulas should use an explicit
    `FormulaPool`, which is collected once it goes out of scope.
"""
const DEFAULT_POOL = FormulaPool(DEFAULT_SIGNATURE)

"""
    atom(value)

Intern `value` as an atom in [`DEFAULT_POOL`](@ref).  Equivalent to
`atom(DEFAULT_POOL, value)`.
"""
atom(value) = atom(DEFAULT_POOL, value)

"""
    branch(connective, children...)

Intern a connective application in [`DEFAULT_POOL`](@ref).  Equivalent to
`branch(DEFAULT_POOL, connective, children...)`; every child must already
belong to the default pool.  Only the vararg spelling is given a pool-free
form: `branch(pool, childtuple)` and `branch(connective, childtuple)` would be
ambiguous, and the explicit path owns the tuple spelling.
"""
branch(connective, children...) = branch(DEFAULT_POOL, connective, children)

# Connective values are callable on pooled formulas, so the formation rule
# reads as it is written in the textbook: `p ∧ q`, `¬p`, `Diamond(r)(p)`.  The
# pool is taken from the operands, which keeps the explicit path spelled the
# same way; a cross-pool application is rejected by `branch`.
#
# The connective parameters below are deliberately spelled to match the
# migration-only call methods in `compatibility.jl`, whose operand type is the
# wider `Formula`; matching them keeps these strictly more specific instead of
# ambiguous with them.
const _PooledFormula = Union{Atom,Branch}

(connective::Negation)(formula::_PooledFormula) =
    branch(_formula_pool(formula), connective, (formula,))
(connective::Union{Conjunction,Disjunction,Implication})(left::_PooledFormula, right::_PooledFormula) =
    branch(_formula_pool(left), connective, (left, right))
(connective::Fusion)(left::_PooledFormula, right::_PooledFormula) =
    branch(_formula_pool(left), connective, (left, right))
(connective::Union{Diamond,Box})(formula::_PooledFormula) =
    branch(_formula_pool(formula), connective, (formula,))
