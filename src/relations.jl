# Named relation values and their family protocols.
# A relation is data: modal connectives carry one of these values in a field.

"""A relation family marker. User-defined relation values need not subtype it."""
abstract type RelationFamily end
"""Allen/Halpern–Shoham interval relations."""
abstract type IntervalRelation <: RelationFamily end
"""Point relations on a bounded linear order."""
abstract type PointRelation <: RelationFamily end
"""Region Connection Calculus relations."""
abstract type RCCRelation <: RelationFamily end
"""Compass logic 2D point relations."""
abstract type Point2DRelation <: RelationFamily end

"""
    relation_holds(relation, source, target)

Return whether `target` is related to `source` by `relation`. This is the
extension point for relation families: a package or user can define a new
immutable relation value and add one method without changing Aletheia. A
bounded relation may instead implement the domain-aware form
`relation_holds(relation, source, target, worlds)`.
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
"""
relation_successors(relation, source, worlds) = nothing

"""Return the converse (inverse) of a relation value."""
function inverse(relation)
    throw(MethodError(inverse, (relation,)))
end
converse(relation) = inverse(relation)

# A generic identity relation is useful when a frame needs equality explicitly.
struct IdentityRelation <: RelationFamily end
const IDENTITY = IdentityRelation()
const ID = IDENTITY
relation_holds(::IdentityRelation, source, target) = isequal(source, target)
inverse(relation::IdentityRelation) = relation

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

const BEFORE = BeforeRelation()
const MEETS = MeetsRelation()
const OVERLAPS = OverlapsRelation()
const STARTS = StartsRelation()
const DURING = DuringRelation()
const FINISHES = FinishesRelation()
const EQUALS = EqualsRelation()
const AFTER = AfterRelation()
const MET_BY = MetByRelation()
const OVERLAPPED_BY = OverlappedByRelation()
const STARTED_BY = StartedByRelation()
const CONTAINS = ContainsRelation()
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
# D=target-during-source, O=overlaps (the incumbent accessibility orientation).
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
# the corresponding incumbent values.
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

const MINIMUM = MinimumRelation()
const MAXIMUM = MaximumRelation()
const SUCCESSOR = SuccessorRelation()
const PREDECESSOR = PredecessorRelation()
const GREATER = GreaterRelation()
const LESSER = LesserRelation()
const MIN = MINIMUM
const MAX = MAXIMUM
const POINT_RELATIONS = (MINIMUM, MAXIMUM, SUCCESSOR, PREDECESSOR, GREATER, LESSER)
const PointRelations = POINT_RELATIONS

# The three-argument successor/predecessor methods describe arithmetic unit
# spacing. Generated finite point frames use the domain-aware four-argument
# protocol for positional order and its min/max boundaries.
relation_holds(::SuccessorRelation, a::Real, b::Real) = b == a + one(a)
relation_holds(::PredecessorRelation, a::Real, b::Real) = b == a - one(a)
relation_holds(::GreaterRelation, a::Real, b::Real) = b > a
relation_holds(::LesserRelation, a::Real, b::Real) = b < a
inverse(::MinimumRelation) = MINIMUM
inverse(::MaximumRelation) = MAXIMUM
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

const DC = DisconnectedRelation()
const EC = ExternallyConnectedRelation()
const PO = PartiallyOverlappingRelation()
const TPP = TangentialProperPartRelation()
const TPPi = TangentialProperPartInverseRelation()
const NTPP = NonTangentialProperPartRelation()
const NTPPi = NonTangentialProperPartInverseRelation()
const RCC_EQ = RCCEqualsRelation()
const RCC8_RELATIONS = (DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ)
const RCC8Relations = RCC8_RELATIONS
const RCC8_BASICS = (DC, EC, PO, TPP, TPPi, NTPP, NTPPi)
const Topo_DC = DC
const Topo_EC = EC
const Topo_PO = PO
const Topo_TPP = TPPi
const Topo_TPPi = TPP
const Topo_NTPP = NTPPi
const Topo_NTPPi = NTPP

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

const Topo_DR = RCC5DisjointRelation()
const Topo_PP = RCC5ProperPartRelation()
const Topo_PPi = RCC5ProperPartInverseRelation()
const RCC5_RELATIONS = (Topo_DR, PO, Topo_PP, Topo_PPi)
const RCC5Relations = RCC5_RELATIONS
const RCC5Relation = Union{RCC5DisjointRelation, typeof(PO), RCC5ProperPartRelation,
    RCC5ProperPartInverseRelation}

relation_holds(::RCC5DisjointRelation, a, b) = relation_holds(DC, a, b) || relation_holds(EC, a, b)
relation_holds(::RCC5ProperPartRelation, a, b) = relation_holds(TPP, a, b) || relation_holds(NTPP, a, b)
relation_holds(::RCC5ProperPartInverseRelation, a, b) = relation_holds(TPPi, a, b) || relation_holds(NTPPi, a, b)
inverse(::RCC5DisjointRelation) = Topo_DR
inverse(::RCC5ProperPartRelation) = Topo_PPi
inverse(::RCC5ProperPartInverseRelation) = Topo_PP

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

export Point2DRelation, CL_N, CL_S, CL_E, CL_W, CL_NE, CL_NW, CL_SE, CL_SW, POINT2D_RELATIONS, Point2DRelations

