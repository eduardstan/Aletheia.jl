"""Finite distribution-semantics circuits and semiring weighted model counting.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> isdefined(AletheiaCircuits, Symbol("AletheiaCircuits"))
true
```
"""
module AletheiaCircuits

using AletheiaCore
import Base: zero, one

include("errors.jl")
include("program.jl")
include("bdd.jl")
include("semiring.jl")

export CircuitError,
    UnsupportedFeatureError,
    ProgramValidationError,
    UnnormalizedWeightsError,
    ZeroMassEvidenceError,
    UncertifiedCircuitError,
    InvalidCircuitError,
    InvalidProbabilityError,
    GroundingError,
    ChoiceVariable,
    AbstractChoiceVariable,
    ChoiceAlternative,
    ChoiceLiteral,
    ProbabilisticFact,
    GroundRule,
    DSProgram,
    AbstractDSProgram,
    DSProfile,
    DSQuery,
    DSWorld,
    alternatives,
    weights,
    choice_id,
    facts,
    choices,
    rules,
    domain,
    total_choices,
    choice_probability,
    ground,
    validate_program,
    world,
    query_event,
    compile_event,
    AbstractEvent,
    EventSpec,
    AbstractEventCircuit,
    CircuitNode,
    BDDNode,
    BDD,
    CircuitCertificate,
    CertifiedCircuit,
    CompiledEvent,
    support,
    source_provenance,
    validate,
    variable_order,
    roots,
    nodes,
    EventNot,
    EventAnd,
    EventOr,
    Not,
    And,
    Or,
    not_event,
    and_event,
    or_event,
    AbstractCommutativeSemiring,
    ProbabilitySemiring,
    ProbabilityProfile,
    Float64Profile,
    RationalProfile,
    zero,
    one,
    add,
    mul,
    literal_label,
    neutral_sum,
    evaluate,
    amc,
    wmc,
    conditional_probability

# Accessors and marker types are public deliberately: they make certificates
# inspectable without exposing mutable compiler state.
@doc "Root exception type for violations of the finite circuit contracts." CircuitError
@doc "A typed rejection for a feature outside the supported fragment." UnsupportedFeatureError
@doc "A typed rejection for an invalid program contract." ProgramValidationError
@doc "A typed rejection for weights that do not form a normalized choice." UnnormalizedWeightsError
@doc "A typed rejection for zero-probability evidence." ZeroMassEvidenceError
@doc "A typed rejection raised when evaluation is attempted without certification." UncertifiedCircuitError
@doc "A typed rejection for a malformed or inconsistent circuit certificate." InvalidCircuitError
@doc "A typed rejection for an invalid probability or semiring value." InvalidProbabilityError
@doc "A typed rejection for a request that is not ground." GroundingError
@doc "The abstract supertype for finite primitive choices." AbstractChoiceVariable
@doc "The abstract supertype for distribution-semantics programs." AbstractDSProgram
@doc "A two-valued finite world represented by its true ground atoms." DSWorld
@doc "Return all finite primitive total choices." total_choices
@doc "Return the product probability of one total choice." choice_probability
@doc "Return the alternatives of a choice variable." alternatives
@doc "Return the normalized outcome weights of a choice variable." weights
@doc "Return a choice variable's stable identifier." choice_id
@doc "Return the source probabilistic facts in a program." facts
@doc "Return the independent primitive choices in a program." choices
@doc "Return the ground rules in a program." rules
@doc "Return the finite domain tuple carried by a program." domain
@doc "An event expression that conjoins child expressions." EventAnd
@doc "An event expression that disjoins child expressions." EventOr
@doc "Create a negated event expression." Not
@doc "Create a conjunction event expression." And
@doc "Create a disjunction event expression." Or
@doc "Compile a query and optional evidence into a certified BDD." compile_event
@doc "Compile a query event; this is the named front-end alias for `compile_event`." query_event
@doc "Create a negated event expression through the named helper." not_event
@doc "Create a conjunction event expression through the named helper." and_event
@doc "Create a disjunction event expression through the named helper." or_event
@doc "The abstract supertype for event circuits." AbstractEventCircuit
@doc "The abstract supertype for circuit nodes." CircuitNode
@doc "Return the node table of a circuit." nodes
@doc "Return root node indices of a circuit." roots
@doc "Return the variable order recorded by a certificate." variable_order
@doc "Return the additive identity of a probability semiring." zero
@doc "Return the multiplicative identity of a probability semiring." one
@doc "Construct a Float64 closed nonnegative probability semiring." Float64Profile
@doc "Construct an exact Rational closed nonnegative probability semiring." RationalProfile


@doc """
Return the additive identity of a probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> zero(ProbabilitySemiring())
0.0
```
""" zero

@doc """
Return the multiplicative identity of a probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> one(ProbabilitySemiring())
1.0
```
""" one
end
