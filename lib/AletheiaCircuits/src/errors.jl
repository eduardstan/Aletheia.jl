# Typed failures make the deliberately narrow semantic boundary observable to callers.
"""
Root exception type for violations of the finite circuit contracts.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> CircuitError isa Type
true
```
"""
abstract type CircuitError <: Exception end

"""
A typed rejection for a feature outside the supported fragment.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = UnsupportedFeatureError(:foo);

julia> err.feature
:foo
```
"""
struct UnsupportedFeatureError <: CircuitError
    feature::Symbol
    detail::String
end
function UnsupportedFeatureError(feature::Symbol)
    return UnsupportedFeatureError(feature, "unsupported feature")
end

"""
A typed rejection for an invalid program contract.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = ProgramValidationError(:contract, "detail");

julia> err.contract
:contract
```
"""
struct ProgramValidationError <: CircuitError
    contract::Symbol
    detail::String
end

"""
A typed rejection for weights that do not form a normalized choice.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = UnnormalizedWeightsError(:var, 0.5, "detail");

julia> err.variable
:var
```
"""
struct UnnormalizedWeightsError <: CircuitError
    variable::Any
    total::Any
    detail::String
end

"""
A typed rejection for zero-probability evidence.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = ZeroMassEvidenceError("detail");

julia> err.detail
"detail"
```
"""
struct ZeroMassEvidenceError <: CircuitError
    detail::String
end

"""
A typed rejection raised when evaluation is attempted without certification.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = UncertifiedCircuitError("detail");

julia> err.detail
"detail"
```
"""
struct UncertifiedCircuitError <: CircuitError
    detail::String
end

"""
A typed rejection for a malformed or inconsistent circuit certificate.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = InvalidCircuitError(:contract, "detail");

julia> err.contract
:contract
```
"""
struct InvalidCircuitError <: CircuitError
    contract::Symbol
    detail::String
end

"""
A typed rejection for an invalid probability or semiring value.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = InvalidProbabilityError(:contract, "detail");

julia> err.contract
:contract
```
"""
struct InvalidProbabilityError <: CircuitError
    contract::Symbol
    detail::String
end

"""
A typed rejection for a request that is not ground.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> err = GroundingError(:contract, "detail");

julia> err.contract
:contract
```
"""
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
