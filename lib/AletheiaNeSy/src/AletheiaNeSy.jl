"""Neural leaves and exact symbolic extraction at Aletheia's boundary.

This package deliberately treats a network as any callable object.  It does
not depend on a deep-learning framework and does not provide semantic loss.
"""
module AletheiaNeSy

using AletheiaCore
using AletheiaData
using AletheiaAudit

"""Root error for a violated neural-symbolic contract."""
struct NeSyContractError <: Exception
    contract::Symbol
    message::String
end
Base.showerror(io::IO, e::NeSyContractError) = print(io, e.contract, ": ", e.message)
"""Raised when a network value is not in the declared truth carrier."""
struct InvalidNeuralValueError <: Exception
    value::Any
    algebra::Any
end
function Base.showerror(io::IO, e::InvalidNeuralValueError)
    return print(io, "invalid neural truth value ", repr(e.value), " for ", e.algebra)
end
"""Raised for malformed finite case sets."""
struct MalformedCaseError <: Exception
    message::String
end
Base.showerror(io::IO, e::MalformedCaseError) = print(io, "malformed cases: ", e.message)
"""Raised when semantic loss is requested without a proven gradient profile."""
struct SemanticLossError <: Exception
    profile::Any
end
function Base.showerror(io::IO, e::SemanticLossError)
    return print(
        io,
        "semantic loss requires a proven gradient-soundness profile; got ",
        repr(e.profile),
    )
end
"""Raised for unsupported or malformed neural choice-label profiles."""
struct ChoiceLabelError <: Exception
    message::String
end
Base.showerror(io::IO, e::ChoiceLabelError) = print(io, "neural choice labels: ", e.message)

"""A callable neural valuation with scalar and batch callbacks."""
struct NeuralLeafValuation{N,E,S,B}
    network::N
    encoder::E
    scalar::S
    batch::B
end

"""The result of an exact extraction and verification round trip."""
struct SKERoundTrip
    extracted::SymbolicArtifact
    verification::VerificationReport
    metrics::MetricBundle
    audit::AuditRecord
end

function _encoded(encoder, atom, world)
    encoder === nothing && return world
    applicable(encoder, atom, world) && return encoder(atom, world)
    applicable(encoder, world) && return encoder(world)
    return throw(
        NeSyContractError(:encoder, "encoder must accept (atom, world) or (world)")
    )
end
function _raw(network, encoder, atom, world)
    return network(_encoded(encoder, atom, world))
end
function _checked(algebra, raw; threshold=nothing)
    T = truth_type(algebra)
    value = if T === Bool && threshold !== nothing && raw isa Real
        raw >= threshold
    elseif raw isa T
        raw
    else
        try
            convert(T, raw)
        catch
            throw(InvalidNeuralValueError(raw, algebra))
        end
    end
    try
        AletheiaCore._validate_atom_value(algebra, value)
    catch
        throw(InvalidNeuralValueError(raw, algebra))
    end
end

"""Build a `ValuationCallback` whose neural values are validated by `algebra`.

The vectorized callback is intentionally differential: it applies the same
network to each member of the supplied batch, so scalar and batch semantics
cannot silently diverge.
"""
function neural_valuation(
    network, encoder; algebra::TruthAlgebra, vectorized=true, threshold=nothing
)
    scalar =
        (atom, world) ->
            _checked(algebra, _raw(network, encoder, atom, world); threshold=threshold)
    batch = if vectorized === false
        nothing
    else
        (
            (atom, worlds) -> [
                _checked(algebra, _raw(network, encoder, atom, world); threshold=threshold) for world in worlds
            ]
        )
    end
    return AletheiaCore.ValuationCallback(scalar; vectorized=batch)
end

function _profile_get(profile, key, default=nothing)
    profile isa NamedTuple && hasproperty(profile, key) && return getproperty(profile, key)
    profile isa AbstractDict && haskey(profile, key) && return profile[key]
    profile isa Symbol && key === :name && return profile
    return default
end
function _normalise(xs)
    vals = collect(xs)
    isempty(vals) && throw(ChoiceLabelError("a finite label vector cannot be empty"))
    all(x -> x isa Real && isfinite(x) && x >= 0, vals) ||
        throw(ChoiceLabelError("labels must be finite nonnegative numbers"))
    total = sum(vals)
    total > 0 || throw(ChoiceLabelError("labels must have positive total mass"))
    return vals ./ total
end

"""Return normalized finite choice labels on a path separate from truth values.

`profile` must declare a finite output (`(finite=true,)` or a dictionary with
that key). The returned vector/dictionary is suitable for a distribution
semantics front end; it is never read as a `TruthAlgebra` value.
"""
function neural_choice_labels(network, encoder; profile)
    finite = _profile_get(
        profile, :finite, profile isa Symbol ? profile === :finite : false
    )
    finite === true || throw(ChoiceLabelError("profile must declare finite=true"))
    raw = if applicable(network)
        network()
    elseif encoder === nothing
        network(nothing)
    elseif applicable(encoder, nothing)
        network(encoder(nothing))
    else
        network(encoder)
    end
    if raw isa AbstractDict
        result = Dict{Any,Any}()
        for (key, value) in raw
            result[key] = _normalise(
                value isa AbstractVector || value isa Tuple ? value : (value,)
            )
        end
        isempty(result) && throw(ChoiceLabelError("label dictionary cannot be empty"))
        return result
    elseif raw isa AbstractVector || raw isa Tuple
        values = _normalise(raw)
        ids = _profile_get(profile, :choices, nothing)
        if ids !== nothing
            length(ids) == 1 ||
                throw(ChoiceLabelError("choices must identify one output vector"))
            return Dict(first(ids) => values)
        end
        return values
    end
    return throw(ChoiceLabelError("finite network output must be a vector or dictionary"))
end

function _nesy_cases(cases)
    cases isa AbstractVector ||
        cases isa Tuple ||
        throw(MalformedCaseError("cases must be a finite vector or tuple"))
    result = ArtifactCase[]
    for c in cases
        if c isa ArtifactCase
            push!(result, c)
        elseif c isa NamedTuple
            hasproperty(c, :input) ||
                throw(MalformedCaseError("named cases need an input field"))
            scope = hasproperty(c, :scope) ? c.scope : :global
            scope in (:global, :local) ||
                throw(MalformedCaseError("case scope must be :global or :local"))
            output = hasproperty(c, :oracle_output) ? c.oracle_output : missing
            state = hasproperty(c, :state) ? c.state : nothing
            push!(result, ArtifactCase(c.input, state, output, scope))
        else
            push!(result, ArtifactCase(c, nothing, missing, :global))
        end
    end
    isempty(result) && throw(MalformedCaseError("cases cannot be empty"))
    return result
end

"""Extract, exactly evaluate, verify, and audit a finite neural model."""
function ske_roundtrip(
    network,
    encoder,
    cases;
    algebra=BOOLEAN,
    artifact=:rule,
    profile=nothing,
    trace=true,
    provenance=Provenance(),
)
    cs = _nesy_cases(cases)
    expected = ArtifactCase[]
    for c in cs
        raw = _raw(network, encoder, c.input, c.state === nothing ? c.input : c.state)
        # SKE compares model outputs directly; truth validation is separate from extraction.
        push!(expected, ArtifactCase(c.input, c.state, raw, c.scope))
    end
    extracted = extract_artifact(
        network,
        cs;
        encoder=encoder,
        artifact=artifact,
        profile=profile,
        provenance=provenance,
    )
    oracle =
        (input, state) -> _raw(network, encoder, input, state === nothing ? input : state)
    verification = verify_artifact(extracted, expected; oracle=oracle, profile=profile)
    metrics = metric_bundle(extracted, expected; scope=:all)
    record = audit(extracted, expected; oracle=oracle, provenance=provenance, scope=:all)
    return SKERoundTrip(extracted, verification, metrics, record)
end

"""Semantic loss is intentionally unavailable until a proven gradient profile exists."""
function semantic_loss(
    formula::Formula,
    valuation::AletheiaCore.ValuationCallback;
    algebra::TruthAlgebra=BOOLEAN,
    gradient_profile=:disabled,
)
    return throw(SemanticLossError(gradient_profile))
end

export NeSyContractError,
    InvalidNeuralValueError,
    MalformedCaseError,
    SemanticLossError,
    ChoiceLabelError,
    NeuralLeafValuation,
    SKERoundTrip,
    neural_valuation,
    neural_choice_labels,
    extract_artifact,
    ske_roundtrip,
    semantic_loss

end
