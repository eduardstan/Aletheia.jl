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

"""
    relation_holds(relation, source, target)

Return whether `target` is related to `source` by `relation`. This is the
extension point for relation families: a package or user can define a new
immutable relation value and add one method without changing Aletheia.
"""
function relation_holds(relation, source, target)
    throw(MethodError(relation_holds, (relation, source, target)))
end

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

# These six relations are defined for the integer linear orders used by the
# generated point frames. The min/max methods are completed by the frame's
# bounded-domain dispatcher in dimensional.jl.
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
