"""Forward evaluation over a closed nonnegative commutative semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractCommutativeSemiring isa Type
true
```
"""
abstract type AbstractCommutativeSemiring{T} end

"""A named numeric profile for probability computation.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> ProbabilityProfile(Float64)
ProbabilityProfile{Float64}(:float64)
```
"""
struct ProbabilityProfile{T}
    name::Symbol
    function ProbabilityProfile{T}(name::Symbol) where {T}
        T <: Real ||
            throw(InvalidProbabilityError(:carrier, "the probability carrier must be real"))
        (T === Float64 || T <: Rational) || throw(
            InvalidProbabilityError(
                :carrier,
                "the supported probability carriers are Float64 and exact Rational",
            ),
        )
        return new{T}(name)
    end
end
function ProbabilityProfile{T}() where {T}
    return ProbabilityProfile{T}(T === Float64 ? :float64 : :rational)
end
ProbabilityProfile(::Type{T}) where {T} = ProbabilityProfile{T}()

"""The probability semiring used for WMC.

`Float64` is the practical profile. `Rational{Int}` gives exact finite-world
answers; Float64 weights are converted with `rationalize` using an eight-ulp
tolerance before rational evaluation.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> ProbabilitySemiring()
ProbabilitySemiring{Float64}(:float64)
```
"""
struct ProbabilitySemiring{T} <: AbstractCommutativeSemiring{T}
    numeric_profile::Symbol
    function ProbabilitySemiring{T}(numeric_profile::Symbol) where {T}
        T <: Real ||
            throw(InvalidProbabilityError(:carrier, "the probability carrier must be real"))
        (T === Float64 || T <: Rational) || throw(
            InvalidProbabilityError(
                :carrier,
                "the supported probability carriers are Float64 and exact Rational",
            ),
        )
        return new{T}(numeric_profile)
    end
end
function ProbabilitySemiring{T}() where {T}
    return ProbabilitySemiring{T}(T === Float64 ? :float64 : :rational)
end
ProbabilitySemiring() = ProbabilitySemiring{Float64}()
function ProbabilitySemiring(profile::ProbabilityProfile{T}) where {T}
    return ProbabilitySemiring{T}(profile.name)
end
ProbabilitySemiring(::Type{T}) where {T} = ProbabilitySemiring{T}()

"""
Construct a Float64 closed nonnegative probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> Float64Profile()
ProbabilitySemiring{Float64}(:float64)
```
"""
Float64Profile() = ProbabilitySemiring{Float64}(:float64)
"""
Construct an exact Rational closed nonnegative probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> RationalProfile()
ProbabilitySemiring{Rational{Int64}}(:rational)
```
"""
RationalProfile() = ProbabilitySemiring{Rational{Int}}(:rational)

function _carrier(s::ProbabilitySemiring{T}) where {T}
    return T
end
zero(::ProbabilitySemiring{T}) where {T} = zero(T)
one(::ProbabilitySemiring{T}) where {T} = one(T)

function _as_carrier(::ProbabilitySemiring{T}, value) where {T}
    converted = if value isa T
        value
    elseif T <: Rational && value isa AbstractFloat
        # Float64 inputs are converted to the nearest rational within an eight-ulp tolerance.
        convert(T, rationalize(Int, value; tol=eps(value) * 8))
    else
        try
            convert(T, value)
        catch
            throw(InvalidProbabilityError(:carrier, "cannot convert $(repr(value)) to $(T)"))
        end
    end
    converted isa Real && isfinite(converted) && converted >= zero(T) || throw(
        InvalidProbabilityError(
            :nonnegative_closed_carrier,
            "semiring values must be finite and nonnegative",
        ),
    )
    return converted
end

"""Add two values in a probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> add(ProbabilitySemiring(), 0.3, 0.4)
0.7
```
"""
function add(s::ProbabilitySemiring{T}, left, right) where {T}
    value = _as_carrier(s, left) + _as_carrier(s, right)
    return _as_carrier(s, value)
end
"""Multiply two values in a probability semiring.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> mul(ProbabilitySemiring(), 0.3, 0.4)
0.12
```
"""
function mul(s::ProbabilitySemiring{T}, left, right) where {T}
    value = _as_carrier(s, left) * _as_carrier(s, right)
    return _as_carrier(s, value)
end

function _lookup_label(labels, key)
    if labels isa AbstractDict
        haskey(labels, key) && return (true, labels[key])
    elseif labels isa NamedTuple && key isa Symbol && hasproperty(labels, key)
        return (true, getproperty(labels, key))
    end
    return (false, nothing)
end

function _label_value(
    s::ProbabilitySemiring{T}, labels, variable, index, polarity
) where {T}
    outcome = variable isa ChoiceAlternative ? variable : ChoiceAlternative(variable, index)
    id = outcome.variable
    found, value = _lookup_label(labels, ChoiceLiteral(outcome, true))
    found || ((found, value) = _lookup_label(labels, outcome))
    found || ((found, value) = _lookup_label(labels, (id, outcome.index)))
    if !found
        found, value = _lookup_label(labels, id)
    end
    if found
        if value isa ChoiceVariable
            index <= length(value) || throw(
                InvalidProbabilityError(
                    :literal_label, "alternative index exceeds choice-variable arity"
                ),
            )
            value = value.weights[index]
        elseif value isa AbstractVector || value isa Tuple
            index <= length(value) || throw(
                InvalidProbabilityError(
                    :literal_label, "alternative index exceeds label arity"
                ),
            )
            value = value[index]
        elseif variable isa ChoiceAlternative
            # A scalar label is the positive probability of a binary variable.
            index <= 2 || throw(
                InvalidProbabilityError(
                    :literal_label, "a scalar label is only valid for a binary choice"
                ),
            )
            value = index == 1 ? value : one(value) - value
        elseif !polarity
            value = one(value) - value
        end
        return _as_carrier(s, value)
    end
    # A direct signed literal is convenient for ordinary Boolean labels.
    signed = ChoiceLiteral(id, polarity)
    found, value = _lookup_label(labels, signed)
    found || throw(
        InvalidProbabilityError(:literal_label, "no label supplied for choice $(repr(id))"),
    )
    return _as_carrier(s, value)
end

"""Map a choice literal to its semiring label.

For a multi-outcome choice use `ChoiceLiteral(ChoiceAlternative(id, index), true)`.
For a binary choice, `ChoiceLiteral(id, true)` and `ChoiceLiteral(id, false)`
select the positive and negative labels.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> lit = ChoiceLiteral(ChoiceAlternative(:c1, 1), true);

julia> literal_label(ProbabilitySemiring(), lit, Dict(:c1 => (0.4, 0.6)))
0.4
```
"""
function literal_label(s::ProbabilitySemiring, literal::ChoiceLiteral, labels)
    variable = literal.variable
    if variable isa ChoiceAlternative
        _label_value(s, labels, variable, variable.index, literal.polarity)
    else
        _label_value(s, labels, variable, literal.polarity ? 2 : 1, literal.polarity)
    end
end

"""Sum labels for all outcomes of a choice omitted by a smooth decision.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> neutral_sum(ProbabilitySemiring(), :c1, Dict(:c1 => (0.4, 0.6)))
1.0
```
"""
function neutral_sum(s::ProbabilitySemiring{T}, variable, labels) where {T}
    if variable isa ChoiceVariable
        return foldl(
            (acc, index) -> add(
                s,
                acc,
                literal_label(
                    s,
                    ChoiceLiteral(ChoiceAlternative(variable.id, index), true),
                    labels,
                ),
            ),
            eachindex(variable.alternatives);
            init=zero(s),
        )
    end
    found, value = _lookup_label(labels, variable)
    found || throw(
        InvalidProbabilityError(
            :neutral_sum, "no labels supplied for choice $(repr(variable))"
        ),
    )
    if value isa ChoiceVariable
        values = value.weights
        return foldl((acc, x) -> add(s, acc, x), values; init=zero(s))
    elseif value isa Tuple || value isa AbstractVector
        return foldl((acc, x) -> add(s, acc, x), value; init=zero(s))
    end
    # A scalar label denotes the positive side of a binary choice.
    return add(s, value, one(s) - value)
end

function _evaluate_root(
    circuit::CertifiedCircuit, semiring::AbstractCommutativeSemiring, root, labels
)
    memo = Dict{Int,Any}()
    function level(index)
        node = circuit.nodes[index]
        return node.var == 0 ? length(circuit.variables) + 1 : node.var
    end
    function include_skipped(value, first_level, last_level)
        for skipped in first_level:last_level
            value = mul(
                semiring, value, neutral_sum(semiring, circuit.variables[skipped], labels)
            )
        end
        return value
    end
    function visit(index)
        haskey(memo, index) && return memo[index]
        node = circuit.nodes[index]
        result = if node.var == 0
            index == 2 ? one(semiring) : zero(semiring)
        else
            total = zero(semiring)
            for (alternative, child) in enumerate(node.branches)
                literal = ChoiceLiteral(
                    ChoiceAlternative(circuit.variables[node.var], alternative), true
                )
                child_value = visit(child)
                child_value = include_skipped(child_value, node.var + 1, level(child) - 1)
                total = add(
                    semiring,
                    total,
                    mul(semiring, literal_label(semiring, literal, labels), child_value),
                )
            end
            total
        end
        return memo[index] = result
    end
    result = visit(root)
    return include_skipped(result, 1, level(root) - 1)
end

"""Evaluate a certified circuit bottom-up with explicit semiring operations.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> evaluate(ev, ProbabilitySemiring())
0.4
```
"""
function evaluate(
    circuit::CertifiedCircuit, semiring::AbstractCommutativeSemiring; labels=nothing
)
    validate(circuit)
    labels === nothing &&
        throw(InvalidProbabilityError(:labels, "literal labels are required"))
    values = tuple(
        (_evaluate_root(circuit, semiring, root, labels) for root in circuit.roots)...
    )
    return length(values) == 1 ? values[1] : values
end
function evaluate(::BDD, ::AbstractCommutativeSemiring; labels=nothing)
    return throw(UncertifiedCircuitError("a circuit must be certified before evaluation"))
end
function evaluate(::AbstractEventCircuit, ::AbstractCommutativeSemiring; labels=nothing)
    return throw(UncertifiedCircuitError("unknown event circuits are not certified"))
end

function evaluate(
    event::CompiledEvent, semiring::AbstractCommutativeSemiring; labels=nothing
)
    labels === nothing && (labels = event.labels)
    return evaluate(event.circuit, semiring; labels=labels)
end

"""Algebraic model counting for a certified event circuit.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> amc(ev, ProbabilitySemiring())
0.4
```
"""
function amc(event::CompiledEvent, semiring::AbstractCommutativeSemiring; labels=nothing)
    labels === nothing && (labels = event.labels)
    return evaluate(event.circuit, semiring; labels=labels)
end
function amc(
    circuit::AbstractEventCircuit, semiring::AbstractCommutativeSemiring; labels=nothing
)
    return evaluate(circuit, semiring; labels=labels)
end

"""Compute the weighted model count of a compiled event or certified circuit.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> wmc(ev)
0.4
```
"""
function wmc(event::CompiledEvent; labels=nothing, semiring=ProbabilitySemiring())
    labels === nothing && (labels = event.labels)
    return amc(event, semiring; labels=labels)
end
function wmc(circuit::AbstractEventCircuit; labels=nothing, semiring=ProbabilitySemiring())
    return amc(circuit, semiring; labels=labels)
end

function _positive(value, semiring::ProbabilitySemiring)
    return value isa Real && isfinite(value) && value > zero(semiring)
end

"""Compute `P(query | evidence)` when the evidence has positive mass.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> q = compile_event(prog, :a);

julia> e = compile_event(prog, Or(:a, :b));

julia> conditional_probability(q, e)
0.4
```
"""
function conditional_probability(
    query::CompiledEvent,
    evidence::CompiledEvent;
    labels=nothing,
    semiring=ProbabilitySemiring(),
)
    semiring isa ProbabilitySemiring || throw(
        UnsupportedFeatureError(
            :conditional_semiring,
            "conditional probability requires an ordered probability profile",
        ),
    )
    _same_program(query, evidence) || throw(
        ProgramValidationError(
            :shared_program, "query and evidence must use the same finite program"
        ),
    )
    labels === nothing && (labels = query.labels)
    denominator = wmc(evidence; labels=labels, semiring=semiring)
    _positive(denominator, semiring) || throw(
        ZeroMassEvidenceError("the evidence event has zero or non-finite probability")
    )
    numerator_event = query.event.evidence === nothing ? _joint(query, evidence) : query
    numerator = wmc(numerator_event; labels=labels, semiring=semiring)
    return numerator / denominator
end

function conditional_probability(
    query::CompiledEvent, evidence; labels=nothing, semiring=ProbabilitySemiring()
)
    return throw(
        ProgramValidationError(
            :evidence_event, "evidence must be a separately compiled event"
        ),
    )
end
