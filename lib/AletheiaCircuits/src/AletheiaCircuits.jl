"""Finite distribution-semantics circuits and semiring weighted model counting."""
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
@doc """
Root exception type for violations of the finite circuit contracts.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> CircuitError isa Type
true
```
""" CircuitError

@doc """
A typed rejection for a feature outside the supported fragment.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = UnsupportedFeatureError(:foo);

julia> err.feature
:foo
```
""" UnsupportedFeatureError

@doc """
A typed rejection for an invalid program contract.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = ProgramValidationError(:contract, "detail");

julia> err.contract
:contract
```
""" ProgramValidationError

@doc """
A typed rejection for weights that do not form a normalized choice.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = UnnormalizedWeightsError(:var, 0.5, "detail");

julia> err.variable
:var
```
""" UnnormalizedWeightsError

@doc """
A typed rejection for zero-probability evidence.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = ZeroMassEvidenceError("detail");

julia> err.detail
"detail"
```
""" ZeroMassEvidenceError

@doc """
A typed rejection raised when evaluation is attempted without certification.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = UncertifiedCircuitError("detail");

julia> err.detail
"detail"
```
""" UncertifiedCircuitError

@doc """
A typed rejection for a malformed or inconsistent circuit certificate.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = InvalidCircuitError(:contract, "detail");

julia> err.contract
:contract
```
""" InvalidCircuitError

@doc """
A typed rejection for an invalid probability or semiring value.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = InvalidProbabilityError(:contract, "detail");

julia> err.contract
:contract
```
""" InvalidProbabilityError

@doc """
A typed rejection for a request that is not ground.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = GroundingError(:contract, "detail");

julia> err.contract
:contract
```
""" GroundingError

@doc """
The abstract supertype for finite primitive choices.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractChoiceVariable isa Type
true
```
""" AbstractChoiceVariable

@doc """
The abstract supertype for distribution-semantics programs.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractDSProgram isa Type
true
```
""" AbstractDSProgram

@doc """
A two-valued finite world represented by its true ground atoms.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> DSWorld isa Type
true
```
""" DSWorld

@doc """
Return all finite primitive total choices.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> total_choices(prog)
2-element Vector{Dict{Any, Any}}:
 Dict(:c1 => :a)
 Dict(:c1 => :b)
```
""" total_choices

@doc """
Return the product probability of one total choice.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> choice_probability(prog, Dict(:c1 => :a))
0.4
```
""" choice_probability

@doc """
Return the alternatives of a choice variable.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> alternatives(c)
(:a, :b)
```
""" alternatives

@doc """
Return the normalized outcome weights of a choice variable.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> weights(c)
(0.4, 0.6)
```
""" weights

@doc """
Return a choice variable's stable identifier.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> choice_id(c)
:c1
```
""" choice_id

@doc """
Return the source probabilistic facts in a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(probabilistic_facts=[ProbabilisticFact(:f1, 0.3)]);

julia> facts(prog)
(ProbabilisticFact{Symbol, Float64}(:f1, 0.3),)
```
""" facts

@doc """
Return the independent primitive choices in a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> choices(prog)
(ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6)),)
```
""" choices

@doc """
Return the ground rules in a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(rules=[GroundRule(:a, (:b,))]);

julia> rules(prog)
(GroundRule{Symbol, Tuple{Symbol}}(:a, (:b,)),)
```
""" rules

@doc """
Return the finite domain tuple carried by a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(domain=(:a, :b));

julia> domain(prog)
(:a, :b)
```
""" domain

@doc """
An event expression that conjoins child expressions.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> EventAnd((:a, :b))
EventAnd{Tuple{Symbol, Symbol}}((:a, :b))
```
""" EventAnd

@doc """
An event expression that disjoins child expressions.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> EventOr((:a, :b))
EventOr{Tuple{Symbol, Symbol}}((:a, :b))
```
""" EventOr

@doc """
Create a negated event expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> Not(:a)
EventNot{Symbol}(:a)
```
""" Not

@doc """
Create a conjunction event expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> And(:a, :b)
EventAnd{Tuple{Symbol, Symbol}}((:a, :b))
```
""" And

@doc """
Create a disjunction event expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> Or(:a, :b)
EventOr{Tuple{Symbol, Symbol}}((:a, :b))
```
""" Or

@doc """
Compile a query and optional evidence into a certified BDD.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> compile_event(prog, :a) isa CompiledEvent
true
```
""" compile_event

@doc """
Compile a query event; this is the named front-end alias for `compile_event`.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> query_event(prog, :a) isa CompiledEvent
true
```
""" query_event

@doc """
Create a negated event expression through the named helper.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> not_event(:a)
EventNot{Symbol}(:a)
```
""" not_event

@doc """
Create a conjunction event expression through the named helper.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> and_event(:a, :b)
EventAnd{Tuple{Symbol, Symbol}}((:a, :b))
```
""" and_event

@doc """
Create a disjunction event expression through the named helper.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> or_event(:a, :b)
EventOr{Tuple{Symbol, Symbol}}((:a, :b))
```
""" or_event

@doc """
The abstract supertype for event circuits.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractEventCircuit isa Type
true
```
""" AbstractEventCircuit

@doc """
The abstract supertype for circuit nodes.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> CircuitNode isa Type
true
```
""" CircuitNode

@doc """
Return the node table of a circuit.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> nodes(ev.circuit) isa Vector{BDDNode}
true
```
""" nodes

@doc """
Return root node indices of a circuit.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> roots(ev.circuit)
(3,)
```
""" roots

@doc """
Return the variable order recorded by a certificate.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> variable_order(ev.circuit)
(:c1,)
```
""" variable_order

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

@doc """
Construct a Float64 closed nonnegative probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> Float64Profile()
ProbabilitySemiring{Float64}(:float64)
```
""" Float64Profile

@doc """
Construct an exact Rational closed nonnegative probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> RationalProfile()
ProbabilitySemiring{Rational{Int64}}(:rational)
```
""" RationalProfile

end
