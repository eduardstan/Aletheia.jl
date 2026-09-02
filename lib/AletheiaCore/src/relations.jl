# Named relation values and their family protocols.
# A relation is data: modal connectives carry one of these values in a field.

"""A relation family marker. User-defined relation values need not subtype it.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RelationFamily"))
true
```
"""
abstract type RelationFamily end
"""
    IntervalRelation

Allen interval relations. The thirteen basic relationships follow Figure 2 of
Allen [allen1983; §3, Figures 1–2, p. 834](@cite); the non-equality `IA32IARelations(IA_I)` member list follows the
twelve relationships in Figure 4 [allen1983; Fig. 4](@cite).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("IntervalRelation"))
true
```
"""
abstract type IntervalRelation <: RelationFamily end
"""
    PointRelation

Point relations on a bounded linear order. These six utility relations are
Aletheia-specific frame helpers rather than a claim to implement a named
external calculus, so no external citation is asserted.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("PointRelation"))
true
```
"""
abstract type PointRelation <: RelationFamily end
"""
    RCCRelation

Region Connection Calculus relations. The primitive relation definitions and
the RCC8 basis follow Randell, Cui, and Cohn [randell1992; §4, Fig. 1,
pp. 167–168](@cite), with the RCC8 presentation and proper-part distinctions
also summarized by Cohn et al. [cohn1997](@cite).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RCCRelation"))
true
```
"""
abstract type RCCRelation <: RelationFamily end
"""
    Point2DRelation

Compass logic 2D point relations. Venema's interval tense logic provides the
foundational two-dimensional interval/product perspective [venema1990](@cite);
Marx and Reynolds study the resulting Compass Logic and its undecidability
[marx1999compass](@cite). Montanari, Puppis, and Sala give the projection-based
`N`, `S`, `E`, and `W` point predicates that match the axial relations here
[montanari2015cone; §2, p. 3](@cite). Aletheia adds the four strict quadrant
predicates `NE`, `NW`, `SE`, and `SW` as a package vocabulary extension; no claim
is made that either source defines those four additional values. Aletheia does
not add a coincident or undetermined-direction value.
"""
abstract type Point2DRelation <: RelationFamily end

"""
    relation_holds(relation, source, target)

Return whether `target` is related to `source` by `relation`. This is the
extension point for relation families: a package or user can define a new
immutable relation value and add one method without changing Aletheia. A
bounded relation may instead implement the domain-aware form
`relation_holds(relation, source, target, worlds)`.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("relation_holds"))
true
```
"""
function relation_holds(relation, source, target)
    throw(MethodError(relation_holds, (relation, source, target)))
end

"""Domain-aware relation predicate used by bounded generated frames.

The default preserves the three-argument protocol. Relation families whose
meaning depends on the finite world domain can specialize this four-argument
form without putting a mutable domain into a relation value.
"""
relation_holds(relation, source, target, worlds) = relation_holds(relation, source, target)

"""
    relation_successors(relation, source, worlds)

Optionally return the worlds related to `source` by `relation` without scanning
all of `worlds`. Generated dimensional frames use this hook when a family
provides it and otherwise fall back to filtering with [`relation_holds`](@ref).
External relation families need no method here.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("relation_successors"))
true
```
"""
relation_successors(relation, source, worlds) = nothing

"""Return the converse (inverse) of a relation value.

The result is the relation `r'` for which `relation_holds(r', a, b)` agrees
with `relation_holds(r, b, a)` on every ordered pair. A relation whose converse
this vocabulary does not name throws an `ArgumentError` explaining why, rather
than returning a relation that is not its converse; `MINIMUM`, `MAXIMUM`, and
`tocenterrel` are those values. An unknown relation still throws a `MethodError`
from the generic fallback.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("inverse"))
true
```
"""
function inverse(relation)
    throw(MethodError(inverse, (relation,)))
end
"""Return the converse relation of `relation`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> converse(BEFORE)
after
```
"""
converse(relation) = inverse(relation)

# A generic identity relation is useful when a frame needs equality explicitly.
"""A generic identity relation family.

# Examples
```jldoctest
julia> using AletheiaCore

julia> IDENTITY isa IdentityRelation
true
```
"""
struct IdentityRelation <: RelationFamily end
const IdentityRel = IdentityRelation
"""The identity relation singleton value (`IDENTITY`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> relation_holds(IDENTITY, 1, 1)
true
```
"""
const IDENTITY = IdentityRelation()
const ID = IDENTITY
relation_holds(::IdentityRelation, source, target) = isequal(source, target)
inverse(relation::IdentityRelation) = relation

# Relations used by the SoleLogics-compatible frame vocabulary.  They are values rather
# than syntax connectives; modal connectives carry one of these values in
# their relation field.
"""The global relation family.

# Examples
```jldoctest
julia> using AletheiaCore

julia> globalrel isa GlobalRelation
true
```
"""
struct GlobalRelation <: RelationFamily end
const GlobalRel = GlobalRelation
"""The global accessibility relation singleton (`globalrel`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> relation_holds(globalrel, 1, 2)
true
```
"""
const globalrel = GlobalRelation()
relation_holds(::GlobalRelation, source, target) = true
inverse(relation::GlobalRelation) = relation
arity(::GlobalRelation) = 2
syntaxstring(::GlobalRelation; kwargs...) = "G"

"""Nominal accessibility relation to a specific world `w`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> AtWorldRelation(1)
at-world
```
"""
struct AtWorldRelation{W} <: RelationFamily
    w::W
end
relation_holds(relation::AtWorldRelation, source, target) = isequal(target, relation.w)
arity(::AtWorldRelation) = 2
syntaxstring(relation::AtWorldRelation; kwargs...) = "@($(string(relation.w)))"

"""The to-center relation family.

# Examples
```jldoctest
julia> using AletheiaCore

julia> tocenterrel isa ToCenterRelation
true
```
"""
struct ToCenterRelation <: RelationFamily end
const ToCenterRel = ToCenterRelation
"""The to-center relation singleton (`tocenterrel`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> tocenterrel isa ToCenterRelation
true
```
"""
const tocenterrel = ToCenterRelation()
arity(::IdentityRelation) = 2
syntaxstring(::IdentityRelation; kwargs...) = "="
arity(::ToCenterRelation) = 2
syntaxstring(::ToCenterRelation; kwargs...) = "◉"
# `tocenterrel` has no source/target predicate at all: a frame defines its
# target through `centralworld`. There is therefore nothing for a converse to
# be the converse of, and `inverse` says so rather than raising a bare
# no-method error.
inverse(::ToCenterRelation) = throw(ArgumentError("`inverse(tocenterrel)` is undefined: \
    `tocenterrel` has no source/target predicate — a frame defines its target through \
    `centralworld` — so there is no relation for `inverse` to return. No relation in this \
    vocabulary is its converse."))

# SoleLogics names and Aletheia's established relation protocol use different
# spellings for identity; retain both as the same singleton value.
"""The identity relation singleton alias (`identityrel`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> identityrel === IDENTITY
true
```
"""
const identityrel = IDENTITY

"""Return whether a relation has source-independent accessibility targets.

A `true` result promises that evaluating accessibility from any world in a
frame yields the same target set; evaluators may use this contract when
constructing relation extensions.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("isgrounding"))
true
```
"""
isgrounding(::Any) = false
isgrounding(::GlobalRelation) = true
isgrounding(::AtWorldRelation) = true
isgrounding(::ToCenterRelation) = true

# Frame-level natural relations provide defaults for ordinary maps. Explicit
# stored/callable providers retain precedence, except the center relation whose
# target is defined by the frame itself. Each method returns an iterable so
# `accessible` can preserve its lazy generator boundary.
function _natural_targets(frame::Frame, world, relation, natural)
    _is_world(frame.worlds, world) || throw(KeyError(world))
    _has_stored_relation(frame, relation) &&
        return _stored_relation_targets(frame, world, relation)
    # Callable/provider frames are explicit accessibility definitions.  Keep
    # the center relation natural because dimensional providers do not define a
    # source predicate for it.
    relation isa ToCenterRelation && return natural()
    (frame.relations isa Function || frame.relations isa _RelationProvider) &&
        return _stored_relation_targets(frame, world, relation)
    natural()
end
_relation_targets(frame::Frame, world, relation::GlobalRelation) =
    _natural_targets(frame, world, relation, () -> frame.worlds)
_relation_targets(frame::Frame, world, relation::IdentityRelation) =
    _natural_targets(frame, world, relation, () -> (world,))
_relation_targets(frame::Frame, world, relation::AtWorldRelation) =
    _natural_targets(frame, world, relation, () -> (relation.w,))
_relation_targets(frame::Frame, world, relation::ToCenterRelation) =
    _natural_targets(frame, world, relation, () -> (centralworld(frame),))
accessibles(frame::Frame, ::GlobalRelation) = worlds(frame)

# ---------------------------------------------------------------------------
# Allen's thirteen basic relations
# ---------------------------------------------------------------------------
struct BeforeRelation <: IntervalRelation end
struct MeetsRelation <: IntervalRelation end
struct OverlapsRelation <: IntervalRelation end
struct StartsRelation <: IntervalRelation end
struct DuringRelation <: IntervalRelation end
struct FinishesRelation <: IntervalRelation end
struct EqualsRelation <: IntervalRelation end
struct AfterRelation <: IntervalRelation end
struct MetByRelation <: IntervalRelation end
struct OverlappedByRelation <: IntervalRelation end
struct StartedByRelation <: IntervalRelation end
struct ContainsRelation <: IntervalRelation end
struct FinishedByRelation <: IntervalRelation end

"""Allen's interval-algebra relation: the first interval ends before the second begins [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("BEFORE"))
true
```
"""
const BEFORE = BeforeRelation()
"""Allen's interval-algebra relation: the first interval ends exactly when the second begins [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("MEETS"))
true
```
"""
const MEETS = MeetsRelation()
"""Allen's interval-algebra relation: the first interval starts before and ends inside the second [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("OVERLAPS"))
true
```
"""
const OVERLAPS = OverlapsRelation()
"""Allen's interval-algebra relation: both intervals start together, and the first ends earlier [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("STARTS"))
true
```
"""
const STARTS = StartsRelation()
"""Allen's interval-algebra relation: the first interval is strictly inside the second [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("DURING"))
true
```
"""
const DURING = DuringRelation()
"""Allen's interval-algebra relation: both intervals end together, and the first starts later [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("FINISHES"))
true
```
"""
const FINISHES = FinishesRelation()
"""Allen's interval-algebra relation: both intervals have the same endpoints [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("EQUALS"))
true
```
"""
const EQUALS = EqualsRelation()
"""Allen's interval-algebra relation: the first interval begins after the second ends [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("AFTER"))
true
```
"""
const AFTER = AfterRelation()
"""Allen's interval-algebra relation: the first interval begins exactly when the second ends [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("MET_BY"))
true
```
"""
const MET_BY = MetByRelation()
"""Allen's interval-algebra relation: the first interval starts inside and ends after the second [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("OVERLAPPED_BY"))
true
```
"""
const OVERLAPPED_BY = OverlappedByRelation()
"""Allen's interval-algebra relation: both intervals start together, and the first ends later [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("STARTED_BY"))
true
```
"""
const STARTED_BY = StartedByRelation()
"""Allen's interval-algebra relation: the first interval strictly contains the second [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("CONTAINS"))
true
```
"""
const CONTAINS = ContainsRelation()
"""Allen's interval-algebra relation: both intervals end together, and the first starts earlier [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("FINISHED_BY"))
true
```
"""
const FINISHED_BY = FinishedByRelation()

# Readable lower-case spellings and names used by several temporal-logic APIs.
const before = BEFORE
const meets = MEETS
const overlaps = OVERLAPS
const starts = STARTS
const during = DURING
const finishes = FINISHES
const equals = EQUALS
const after = AFTER
const met_by = MET_BY
const overlapped_by = OVERLAPPED_BY
const started_by = STARTED_BY
const contains = CONTAINS
const finished_by = FINISHED_BY
const IA_BEFORE = BEFORE
const IA_MEETS = MEETS
const IA_OVERLAPS = OVERLAPS
const IA_STARTS = STARTS
const IA_DURING = DURING
const IA_FINISHES = FINISHES
const IA_EQUALS = EQUALS
const IA_AFTER = AFTER
const IA_MET_BY = MET_BY
const IA_OVERLAPPED_BY = OVERLAPPED_BY
const IA_STARTED_BY = STARTED_BY
const IA_CONTAINS = CONTAINS
const IA_FINISHED_BY = FINISHED_BY
# Sole-compatible abbreviations, retaining their documented orientation:
# A=meets, L=before, B=target-starts-source, E=target-finishes-source,
# D=target-during-source, O=overlaps (the SoleLogics accessibility orientation).
const IA_A = MEETS
const IA_L = BEFORE
const IA_B = STARTED_BY
const IA_E = FINISHED_BY
const IA_D = CONTAINS
const IA_O = OVERLAPS
const IA_Ai = MET_BY
const IA_Li = AFTER
const IA_Bi = STARTS
const IA_Ei = FINISHES
const IA_Di = DURING
const IA_Oi = OVERLAPPED_BY

# Coarser Allen relation families used by the Sole ecosystem. Their members
# are unions of the primitive Allen relations, with the same orientation as
# the corresponding SoleLogics values.
struct IA_AorORelation <: IntervalRelation end
struct IA_DorBorERelation <: IntervalRelation end
struct IA_AiorOiRelation <: IntervalRelation end
struct IA_DiorBiorEiRelation <: IntervalRelation end
struct IA_IRelation <: IntervalRelation end

const IA_AorO = IA_AorORelation()
const IA_DorBorE = IA_DorBorERelation()
const IA_AiorOi = IA_AiorOiRelation()
const IA_DiorBiorEi = IA_DiorBiorEiRelation()
const IA_I = IA_IRelation()

const IA7Relation = Union{IA_AorORelation, IA_AiorOiRelation,
    IA_DorBorERelation, IA_DiorBiorEiRelation}
const IA3Relation = IA_IRelation

const IA7Relations = (IA_AorO, IA_L, IA_DorBorE, IA_AiorOi, IA_Li, IA_DiorBiorEi)
const IA3Relations = (IA_I, IA_L, IA_Li)

IA72IARelations(::IA_AorORelation) = (IA_A, IA_O)
IA72IARelations(::IA_AiorOiRelation) = (IA_Ai, IA_Oi)
IA72IARelations(::IA_DorBorERelation) = (IA_D, IA_B, IA_E)
IA72IARelations(::IA_DiorBiorEiRelation) = (IA_Di, IA_Bi, IA_Ei)
IA32IARelations(::IA_IRelation) = (IA_A, IA_O, IA_D, IA_B, IA_E,
    IA_Ai, IA_Oi, IA_Di, IA_Bi, IA_Ei)

relation_holds(::IA_AorORelation, a, b) = relation_holds(IA_A, a, b) || relation_holds(IA_O, a, b)
relation_holds(::IA_DorBorERelation, a, b) = relation_holds(IA_D, a, b) ||
    relation_holds(IA_B, a, b) || relation_holds(IA_E, a, b)
relation_holds(::IA_AiorOiRelation, a, b) = relation_holds(IA_Ai, a, b) || relation_holds(IA_Oi, a, b)
relation_holds(::IA_DiorBiorEiRelation, a, b) = relation_holds(IA_Di, a, b) ||
    relation_holds(IA_Bi, a, b) || relation_holds(IA_Ei, a, b)
relation_holds(::IA_IRelation, a, b) = any(r -> relation_holds(r, a, b), IA32IARelations(IA_I))

inverse(::IA_AorORelation) = IA_AiorOi
inverse(::IA_DorBorERelation) = IA_DiorBiorEi
inverse(::IA_AiorOiRelation) = IA_AorO
inverse(::IA_DiorBiorEiRelation) = IA_DorBorE
inverse(::IA_IRelation) = IA_I

"""The tuple of the thirteen basic Allen interval-algebra relations [allen1983](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("ALLEN_RELATIONS"))
true
```
"""
const ALLEN_RELATIONS = (BEFORE, MEETS, OVERLAPS, STARTS, DURING, FINISHES, EQUALS,
    AFTER, MET_BY, OVERLAPPED_BY, STARTED_BY, CONTAINS, FINISHED_BY)
const IntervalRelations = ALLEN_RELATIONS
const IARelations = ALLEN_RELATIONS

# Short stable spellings keep modal notation parseable and readable.
_relation_name(::BeforeRelation) = "before"
_relation_name(::MeetsRelation) = "meets"
_relation_name(::OverlapsRelation) = "overlaps"
_relation_name(::StartsRelation) = "starts"
_relation_name(::DuringRelation) = "during"
_relation_name(::FinishesRelation) = "finishes"
_relation_name(::EqualsRelation) = "equals"
_relation_name(::AfterRelation) = "after"
_relation_name(::MetByRelation) = "met-by"
_relation_name(::OverlappedByRelation) = "overlapped-by"
_relation_name(::StartedByRelation) = "started-by"
_relation_name(::ContainsRelation) = "contains"
_relation_name(::FinishedByRelation) = "finished-by"
_relation_name(::IA_AorORelation) = "AO"
_relation_name(::IA_DorBorERelation) = "DBE"
_relation_name(::IA_AiorOiRelation) = "A̅O̅"
_relation_name(::IA_DiorBiorEiRelation) = "D̅B̅E̅"
_relation_name(::IA_IRelation) = "I"
_relation_name(::IdentityRelation) = "identity"
Base.show(io::IO, relation::IntervalRelation) = print(io, _relation_name(relation))

@inline _left(i) = getproperty(i, :x)
@inline _right(i) = getproperty(i, :y)

# The arguments are (reference, accessible target). These are the standard
# endpoint definitions; in particular MEETS is equality at one boundary and
# BEFORE is strict separation.
relation_holds(::BeforeRelation, a, b) = _right(a) < _left(b)
relation_holds(::MeetsRelation, a, b) = _right(a) == _left(b)
relation_holds(::OverlapsRelation, a, b) = _left(a) < _left(b) < _right(a) < _right(b)
relation_holds(::StartsRelation, a, b) = _left(a) == _left(b) && _right(a) < _right(b)
relation_holds(::DuringRelation, a, b) = _left(b) < _left(a) && _right(a) < _right(b)
relation_holds(::FinishesRelation, a, b) = _left(b) < _left(a) && _right(a) == _right(b)
relation_holds(::EqualsRelation, a, b) = _left(a) == _left(b) && _right(a) == _right(b)
relation_holds(::AfterRelation, a, b) = _right(b) < _left(a)
relation_holds(::MetByRelation, a, b) = _left(a) == _right(b)
relation_holds(::OverlappedByRelation, a, b) = _left(b) < _left(a) < _right(b) < _right(a)
relation_holds(::StartedByRelation, a, b) = _left(a) == _left(b) && _right(b) < _right(a)
relation_holds(::ContainsRelation, a, b) = _left(a) < _left(b) && _right(b) < _right(a)
relation_holds(::FinishedByRelation, a, b) = _left(a) < _left(b) && _right(a) == _right(b)

inverse(::BeforeRelation) = AFTER
inverse(::MeetsRelation) = MET_BY
inverse(::OverlapsRelation) = OVERLAPPED_BY
inverse(::StartsRelation) = STARTED_BY
inverse(::DuringRelation) = CONTAINS
inverse(::FinishesRelation) = FINISHED_BY
inverse(::EqualsRelation) = EQUALS
inverse(::AfterRelation) = BEFORE
inverse(::MetByRelation) = MEETS
inverse(::OverlappedByRelation) = OVERLAPS
inverse(::StartedByRelation) = STARTS
inverse(::ContainsRelation) = DURING
inverse(::FinishedByRelation) = FINISHES

# ---------------------------------------------------------------------------
# Point relations
# ---------------------------------------------------------------------------
struct MinimumRelation <: PointRelation end
struct MaximumRelation <: PointRelation end
struct SuccessorRelation <: PointRelation end
struct PredecessorRelation <: PointRelation end
struct GreaterRelation <: PointRelation end
struct LesserRelation <: PointRelation end

"""Point relation holding when the target is the first point in a bounded domain.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("MINIMUM"))
true
```
"""
const MINIMUM = MinimumRelation()
"""Point relation holding when the target is the last point in a bounded domain.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("MAXIMUM"))
true
```
"""
const MAXIMUM = MaximumRelation()
"""Point relation holding when the target is the immediate successor of the source.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("SUCCESSOR"))
true
```
"""
const SUCCESSOR = SuccessorRelation()
"""Point relation holding when the target is the immediate predecessor of the source.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("PREDECESSOR"))
true
```
"""
const PREDECESSOR = PredecessorRelation()
"""Point relation holding when the target is greater than the source.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("GREATER"))
true
```
"""
const GREATER = GreaterRelation()
"""Point relation holding when the target is less than the source.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("LESSER"))
true
```
"""
const LESSER = LesserRelation()
const MIN = MINIMUM
const MAX = MAXIMUM
"""The tuple of point relations supported by bounded generated frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("POINT_RELATIONS"))
true
```
"""
const POINT_RELATIONS = (MINIMUM, MAXIMUM, SUCCESSOR, PREDECESSOR, GREATER, LESSER)
const PointRelations = POINT_RELATIONS

# The three-argument successor/predecessor methods describe arithmetic unit
# spacing. Generated finite point frames use the domain-aware four-argument
# protocol for positional order and its min/max boundaries.
relation_holds(::SuccessorRelation, a::Real, b::Real) = b == a + one(a)
relation_holds(::PredecessorRelation, a::Real, b::Real) = b == a - one(a)
relation_holds(::GreaterRelation, a::Real, b::Real) = b > a
relation_holds(::LesserRelation, a::Real, b::Real) = b < a
# MINIMUM and MAXIMUM relate every source to one fixed boundary world, so
# their converse relates that one world to every target: a different relation,
# and not one this vocabulary names. Returning MINIMUM/MAXIMUM here would break
# both the converse contract above and `isgrounding`, so `inverse` refuses, and
# it says why rather than leaving the caller a bare no-method error.
function _no_converse(name, boundary)
    throw(ArgumentError("`inverse($name)` is undefined: `$name` relates every source to the \
        $boundary world of the domain, so its converse relates that one world to every \
        target. That relation is not part of this vocabulary, and returning `$name` would be \
        a wrong converse. The point relations that do have one are `SUCCESSOR`/`PREDECESSOR` \
        and `GREATER`/`LESSER`."))
end
inverse(::MinimumRelation) = _no_converse("MINIMUM", "first")
inverse(::MaximumRelation) = _no_converse("MAXIMUM", "last")
inverse(::SuccessorRelation) = PREDECESSOR
inverse(::PredecessorRelation) = SUCCESSOR
inverse(::GreaterRelation) = LESSER
inverse(::LesserRelation) = GREATER

# ---------------------------------------------------------------------------
# RCC8 (including EQ, which is the eighth basic relation)
# ---------------------------------------------------------------------------
struct DisconnectedRelation <: RCCRelation end
struct ExternallyConnectedRelation <: RCCRelation end
struct PartiallyOverlappingRelation <: RCCRelation end
struct TangentialProperPartRelation <: RCCRelation end
struct TangentialProperPartInverseRelation <: RCCRelation end
struct NonTangentialProperPartRelation <: RCCRelation end
struct NonTangentialProperPartInverseRelation <: RCCRelation end
struct RCCEqualsRelation <: RCCRelation end

"""RCC8 disconnected relation: the two regions share no point [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("DC"))
true
```
"""
const DC = DisconnectedRelation()
"""RCC8 externally connected relation: the two regions touch at their boundaries but do not overlap [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("EC"))
true
```
"""
const EC = ExternallyConnectedRelation()
"""RCC8 partially overlapping relation: the regions overlap, but neither contains the other [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("PO"))
true
```
"""
const PO = PartiallyOverlappingRelation()
"""RCC8 tangential proper-part relation: the first region is a proper part of the second and touches its boundary [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("TPP"))
true
```
"""
const TPP = TangentialProperPartRelation()
"""RCC8 inverse tangential proper-part relation: the second region is a tangential proper part of the first [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("TPPi"))
true
```
"""
const TPPi = TangentialProperPartInverseRelation()
"""RCC8 non-tangential proper-part relation: the first region is a proper part of the second without touching its boundary [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("NTPP"))
true
```
"""
const NTPP = NonTangentialProperPartRelation()
"""RCC8 inverse non-tangential proper-part relation: the second region is a non-tangential proper part of the first [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("NTPPi"))
true
```
"""
const NTPPi = NonTangentialProperPartInverseRelation()
"""RCC8 equality relation: the two regions have the same extent [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RCC_EQ"))
true
```
"""
const RCC_EQ = RCCEqualsRelation()
"""The tuple of the eight RCC8 relations, including equality [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RCC8_RELATIONS"))
true
```
"""
const RCC8_RELATIONS = (DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ)
const RCC8Relations = RCC8_RELATIONS
"""The seven non-equality RCC8 base relations [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RCC8_BASICS"))
true
```
"""
const RCC8_BASICS = (DC, EC, PO, TPP, TPPi, NTPP, NTPPi)

_relation_name(::MinimumRelation) = "min"
_relation_name(::MaximumRelation) = "max"
_relation_name(::SuccessorRelation) = "successor"
_relation_name(::PredecessorRelation) = "predecessor"
_relation_name(::GreaterRelation) = "greater"
_relation_name(::LesserRelation) = "lesser"
_relation_name(::DisconnectedRelation) = "dc"
_relation_name(::ExternallyConnectedRelation) = "ec"
_relation_name(::PartiallyOverlappingRelation) = "po"
_relation_name(::TangentialProperPartRelation) = "tpp"
_relation_name(::TangentialProperPartInverseRelation) = "tppi"
_relation_name(::NonTangentialProperPartRelation) = "ntpp"
_relation_name(::NonTangentialProperPartInverseRelation) = "ntppi"
_relation_name(::RCCEqualsRelation) = "rcc-equals"
Base.show(io::IO, relation::PointRelation) = print(io, _relation_name(relation))
Base.show(io::IO, relation::RCCRelation) = print(io, _relation_name(relation))
Base.show(io::IO, relation::IdentityRelation) = print(io, _relation_name(relation))
_relation_name(::GlobalRelation) = "global"
_relation_name(::AtWorldRelation) = "at-world"
_relation_name(::ToCenterRelation) = "to-center"
Base.show(io::IO, relation::GlobalRelation) = print(io, _relation_name(relation))
Base.show(io::IO, relation::AtWorldRelation) = print(io, _relation_name(relation))
Base.show(io::IO, relation::ToCenterRelation) = print(io, _relation_name(relation))

const DISCONNECTED = DC
const EXTERNALLY_CONNECTED = EC
const PARTIALLY_OVERLAPPING = PO
const TANGENTIAL_PROPER_PART = TPP
const TANGENTIAL_PROPER_PART_INVERSE = TPPi
const NON_TANGENTIAL_PROPER_PART = NTPP
const NON_TANGENTIAL_PROPER_PART_INVERSE = NTPPi

# RCC8 on one-dimensional closed intervals. End-point contact is EC, while
# strict separation is DC; this is the interval realization used by Sole.
relation_holds(::DisconnectedRelation, a, b) = _right(a) < _left(b) || _right(b) < _left(a)
relation_holds(::ExternallyConnectedRelation, a, b) =
    !relation_holds(DC, a, b) && (_right(a) == _left(b) || _right(b) == _left(a))
relation_holds(::PartiallyOverlappingRelation, a, b) =
    !relation_holds(DC, a, b) && !relation_holds(EC, a, b) &&
    !_contains_interval(a, b) && !_contains_interval(b, a) && !relation_holds(RCC_EQ, a, b)
relation_holds(::TangentialProperPartRelation, a, b) =
    _proper_subset(a, b) && (_left(a) == _left(b) || _right(a) == _right(b))
relation_holds(::TangentialProperPartInverseRelation, a, b) = relation_holds(TPP, b, a)
relation_holds(::NonTangentialProperPartRelation, a, b) = _left(b) < _left(a) && _right(a) < _right(b)
relation_holds(::NonTangentialProperPartInverseRelation, a, b) = relation_holds(NTPP, b, a)
relation_holds(::RCCEqualsRelation, a, b) = _left(a) == _left(b) && _right(a) == _right(b)

@inline _contains_interval(a, b) = _left(a) <= _left(b) && _right(b) <= _right(a)
@inline _proper_subset(a, b) = _contains_interval(b, a) && !relation_holds(RCC_EQ, a, b)

inverse(::DisconnectedRelation) = DC
inverse(::ExternallyConnectedRelation) = EC
inverse(::PartiallyOverlappingRelation) = PO
inverse(::TangentialProperPartRelation) = TPPi
inverse(::TangentialProperPartInverseRelation) = TPP
inverse(::NonTangentialProperPartRelation) = NTPPi
inverse(::NonTangentialProperPartInverseRelation) = NTPP
inverse(::RCCEqualsRelation) = RCC_EQ

# RCC5 coarsens RCC8 by joining disconnected/contact and proper-part cases.
struct RCC5DisjointRelation <: RCCRelation end
struct RCC5ProperPartRelation <: RCCRelation end
struct RCC5ProperPartInverseRelation <: RCCRelation end

"""RCC5 disjoint relation: the regions are disconnected or externally connected [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("DR"))
true
```
"""
const DR = RCC5DisjointRelation()
"""RCC5 proper-part relation: the first region is a proper part of the second [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("PP"))
true
```
"""
const PP = RCC5ProperPartRelation()
"""RCC5 inverse proper-part relation: the second region is a proper part of the first [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("PPi"))
true
```
"""
const PPi = RCC5ProperPartInverseRelation()
"""The tuple of the four RCC5 relations [randell1992](@cite).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RCC5_RELATIONS"))
true
```
"""
const RCC5_RELATIONS = (DR, PO, PP, PPi)
"""The union type of concrete RCC5 relation values.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("RCC5Relation"))
true
```
"""
const RCC5Relation = Union{RCC5DisjointRelation, typeof(PO), RCC5ProperPartRelation,
    RCC5ProperPartInverseRelation}

relation_holds(::RCC5DisjointRelation, a, b) = relation_holds(DC, a, b) || relation_holds(EC, a, b)
relation_holds(::RCC5ProperPartRelation, a, b) = relation_holds(TPP, a, b) || relation_holds(NTPP, a, b)
relation_holds(::RCC5ProperPartInverseRelation, a, b) = relation_holds(TPPi, a, b) || relation_holds(NTPPi, a, b)
inverse(::RCC5DisjointRelation) = DR
inverse(::RCC5ProperPartRelation) = PPi
inverse(::RCC5ProperPartInverseRelation) = PP

_relation_name(::RCC5DisjointRelation) = "dr"
_relation_name(::RCC5ProperPartRelation) = "pp"
_relation_name(::RCC5ProperPartInverseRelation) = "ppi"

# ---------------------------------------------------------------------------
# Compass logic 2D point relations
# ---------------------------------------------------------------------------
struct ClosestNorthRelation <: Point2DRelation end
struct ClosestSouthRelation <: Point2DRelation end
struct ClosestEastRelation <: Point2DRelation end
struct ClosestWestRelation <: Point2DRelation end
struct ClosestNorthEastRelation <: Point2DRelation end
struct ClosestNorthWestRelation <: Point2DRelation end
struct ClosestSouthEastRelation <: Point2DRelation end
struct ClosestSouthWestRelation <: Point2DRelation end

const CL_N  = ClosestNorthRelation()
const CL_S  = ClosestSouthRelation()
const CL_E  = ClosestEastRelation()
const CL_W  = ClosestWestRelation()
const CL_NE = ClosestNorthEastRelation()
const CL_NW = ClosestNorthWestRelation()
const CL_SE = ClosestSouthEastRelation()
const CL_SW = ClosestSouthWestRelation()

const POINT2D_RELATIONS = (CL_N, CL_S, CL_E, CL_W, CL_NE, CL_NW, CL_SE, CL_SW)
const Point2DRelations = POINT2D_RELATIONS

_relation_name(::ClosestNorthRelation) = "N"
_relation_name(::ClosestSouthRelation) = "S"
_relation_name(::ClosestEastRelation) = "E"
_relation_name(::ClosestWestRelation) = "W"
_relation_name(::ClosestNorthEastRelation) = "NE"
_relation_name(::ClosestNorthWestRelation) = "NW"
_relation_name(::ClosestSouthEastRelation) = "SE"
_relation_name(::ClosestSouthWestRelation) = "SW"

Base.show(io::IO, relation::Point2DRelation) = print(io, _relation_name(relation))
istransitive(::Point2DRelation) = true

inverse(::ClosestNorthRelation) = CL_S
inverse(::ClosestSouthRelation) = CL_N
inverse(::ClosestEastRelation) = CL_W
inverse(::ClosestWestRelation) = CL_E
inverse(::ClosestNorthEastRelation) = CL_SW
inverse(::ClosestSouthWestRelation) = CL_NE
inverse(::ClosestNorthWestRelation) = CL_SE
inverse(::ClosestSouthEastRelation) = CL_NW

@inline _point_coords(p::Tuple) = p
@inline _point_coords(p) = hasproperty(p, :coordinates) ? getproperty(p, :coordinates) : p

@inline _px(p) = _point_coords(p)[1]
@inline _py(p) = _point_coords(p)[2]

relation_holds(::ClosestNorthRelation, a, b) = _px(a) == _px(b) && _py(b) > _py(a)
relation_holds(::ClosestSouthRelation, a, b) = _px(a) == _px(b) && _py(b) < _py(a)
relation_holds(::ClosestEastRelation, a, b) = _px(b) > _px(a) && _py(a) == _py(b)
relation_holds(::ClosestWestRelation, a, b) = _px(b) < _px(a) && _py(a) == _py(b)
relation_holds(::ClosestNorthEastRelation, a, b) = _px(b) > _px(a) && _py(b) > _py(a)
relation_holds(::ClosestNorthWestRelation, a, b) = _px(b) < _px(a) && _py(b) > _py(a)
relation_holds(::ClosestSouthEastRelation, a, b) = _px(b) > _px(a) && _py(b) < _py(a)
relation_holds(::ClosestSouthWestRelation, a, b) = _px(b) < _px(a) && _py(b) < _py(a)
