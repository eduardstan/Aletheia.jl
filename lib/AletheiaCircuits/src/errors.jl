# Typed failures make the deliberately narrow semantic boundary observable to callers.
abstract type CircuitError <: Exception end

struct UnsupportedFeatureError <: CircuitError
    feature::Symbol
    detail::String
end
function UnsupportedFeatureError(feature::Symbol)
    return UnsupportedFeatureError(feature, "unsupported feature")
end

struct ProgramValidationError <: CircuitError
    contract::Symbol
    detail::String
end

struct UnnormalizedWeightsError <: CircuitError
    variable::Any
    total::Any
    detail::String
end

struct ZeroMassEvidenceError <: CircuitError
    detail::String
end

struct UncertifiedCircuitError <: CircuitError
    detail::String
end

struct InvalidCircuitError <: CircuitError
    contract::Symbol
    detail::String
end

struct InvalidProbabilityError <: CircuitError
    contract::Symbol
    detail::String
end

struct GroundingError <: CircuitError
    contract::Symbol
    detail::String
end

function Base.showerror(io::IO, error::UnsupportedFeatureError)
    return print(io, "unsupported feature ", error.feature, ": ", error.detail)
end
function Base.showerror(io::IO, error::ProgramValidationError)
    return print(io, "program contract ", error.contract, " violated: ", error.detail)
end
function Base.showerror(io::IO, error::UnnormalizedWeightsError)
    return print(
        io,
        "normalized-choice contract violated for ",
        repr(error.variable),
        ": weights sum to ",
        error.total,
        "; ",
        error.detail,
    )
end
function Base.showerror(io::IO, error::ZeroMassEvidenceError)
    return print(io, "positive-evidence contract violated: ", error.detail)
end
function Base.showerror(io::IO, error::UncertifiedCircuitError)
    return print(io, "certified-circuit contract violated: ", error.detail)
end
function Base.showerror(io::IO, error::InvalidCircuitError)
    return print(io, "circuit contract ", error.contract, " violated: ", error.detail)
end
function Base.showerror(io::IO, error::InvalidProbabilityError)
    return print(io, "probability contract ", error.contract, " violated: ", error.detail)
end
function Base.showerror(io::IO, error::GroundingError)
    return print(io, "grounding contract ", error.contract, " violated: ", error.detail)
end
