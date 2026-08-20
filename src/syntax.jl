# Syntax is deliberately independent of interpretation and truth values.

"""
    arity(connective)

Return the finite arity of a connective.  This is a trait: packages defining a
connective only need to add a method for their own value or type.
"""
function arity(connective)
    throw(MethodError(arity, (connective,)))
end

"""
    dual(connective)

Return the syntactic dual of `connective`, or throw when no dual is declared.
Duality is only a connective property; this layer does not interpret formulas.
"""
function dual(connective)
    throw(ArgumentError("no dual is declared for $(typeof(connective))"))
end

"""
    hasdual(connective)

Return whether a connective has a syntactic dual.
"""
hasdual(connective) = false

"""
    precedence(connective)

Return the binding precedence used by the printer and parser.  Larger values
bind more tightly.  Custom connectives should define this trait when they are
printed in infix or prefix notation.
"""
precedence(connective) = 0

"""
    associativity(connective)

Return `:left`, `:right`, or `:none` for a connective.  The default is
`:none`, which makes equal-precedence children parenthesized conservatively.
"""
associativity(connective) = :none

"""
    commutative(connective)

Return whether a connective is commutative.  Commutativity is recorded as a
trait for later normalization stages; it never changes syntax or equality.
"""
commutative(connective) = false

"""
    modality(connective)

Return whether a connective is a modality.  This is a syntactic trait and has
no semantic consequence in the syntax layer.
"""
modality(connective) = false

"""
    notation(connective)

Return the text used for a connective in formulas.  Defining this trait is the
only printing hook needed by a user-defined connective.
"""
notation(connective) = string(connective)

"""Alias for [`commutative`](@ref), retained as a readable predicate."""
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

"""
    Atom(pool, value)

Intern `value` as an atom in `pool`.  Atoms are immutable concrete formulas;
their integer id is stable for the lifetime of the pool.
"""
struct Atom{V,P<:FormulaPool} <: Formula
    pool::P
    id::Int
    value::V
end

"""
    Branch(pool, connective, children...)

Intern a connective application in `pool`.  The number of children must equal
the connective's declared arity.  A branch stores only pool-local child ids;
[`children`](@ref) reconstructs immutable handles when they are requested.
Children must have been made by the same pool, which keeps ids local and makes
equality an integer comparison.
"""
struct Branch{C,N,P<:FormulaPool} <: Formula
    pool::P
    id::Int
    connective::C
    children::NTuple{N,Int}
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
    Branch(pool, id, connective, typed_ids)
end

function _formula_unlocked(pool::FormulaPool, id::Int)
    node = pool.nodes[id]
    if node.kind == 0x01
        Atom(pool, id, node.payload)
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

function _intern!(pool::FormulaPool, kind::UInt8, payload, childids::Tuple{Vararg{Int}})
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
    Atom(pool, atom_id, value)
end

# This method makes the type constructor spelling useful without exposing an
# unsafe constructor that can fabricate a formula id.
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
struct Disjunction end
struct Implication end
"""
    Diamond(relation)

A unary modal connective carrying `relation` as a value.  The relation is a
field, not a type parameter encoded in a singleton, so parametric relations
remain ordinary syntax values.
"""
struct Diamond{R}
    relation::R
end

"""
    Box(relation)

The syntactic dual modal connective for [`Diamond`](@ref), carrying its
relation as a value.
"""
struct Box{R}
    relation::R
end

const NEGATION = Negation()
const CONJUNCTION = Conjunction()
const DISJUNCTION = Disjunction()
const IMPLICATION = Implication()
const NOT = NEGATION
const AND = CONJUNCTION
const OR = DISJUNCTION
const IMPLIES = IMPLICATION
const ¬ = NEGATION
const ∧ = CONJUNCTION
const ∨ = DISJUNCTION
const → = IMPLICATION

arity(::Negation) = 1
arity(::Conjunction) = 2
arity(::Disjunction) = 2
arity(::Implication) = 2
arity(::Diamond) = 1
arity(::Box) = 1
precedence(::Negation) = 80
precedence(::Diamond) = 90
precedence(::Box) = 90
precedence(::Conjunction) = 30
precedence(::Disjunction) = 20
precedence(::Implication) = 10
associativity(::Negation) = :right
associativity(::Diamond) = :right
associativity(::Box) = :right
associativity(::Conjunction) = :left
associativity(::Disjunction) = :left
associativity(::Implication) = :right
commutative(::Conjunction) = true
commutative(::Disjunction) = true
modality(::Diamond) = true
modality(::Box) = true
hasdual(::Negation) = true
hasdual(::Conjunction) = true
hasdual(::Disjunction) = true
hasdual(::Diamond) = true
hasdual(::Box) = true
dual(::Negation) = NEGATION
dual(::Conjunction) = DISJUNCTION
dual(::Disjunction) = CONJUNCTION
dual(d::Diamond) = Box(d.relation)
dual(b::Box) = Diamond(b.relation)
notation(::Negation) = "¬"
notation(::Conjunction) = "∧"
notation(::Disjunction) = "∨"
notation(::Implication) = "→"
notation(d::Diamond) = "⟨$(d.relation)⟩"
notation(b::Box) = "[$(b.relation)]"

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
Base.show(io::IO, connective::Disjunction) = print(io, notation(connective))
Base.show(io::IO, connective::Implication) = print(io, notation(connective))
Base.show(io::IO, connective::Diamond) = print(io, notation(connective))
Base.show(io::IO, connective::Box) = print(io, notation(connective))
