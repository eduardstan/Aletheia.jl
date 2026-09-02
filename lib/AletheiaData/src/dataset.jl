# Dependency-free protocol for evaluating a family of per-instance models.

"""
    AbstractModelFamily

A family of logical instances. Implementations provide `instance_count` and
`instance_model`; the latter returns an Aletheia [`Model`](@ref) for one
instance. A model's frame may differ between instances.

# Examples
```jldoctest
julia> using AletheiaData

julia> ModelFamily([]) isa AbstractModelFamily
true
```
"""
abstract type AbstractModelFamily end

"""
Return the number of instances in `family`.

# Examples
```jldoctest
julia> using AletheiaData

julia> fam = ModelFamily([1, 2, 3]);

julia> instance_count(fam)
3
```
"""
function instance_count(family::AbstractModelFamily)
    return throw(MethodError(instance_count, (family,)))
end

"""
Iterate stable instance handles (by default, one-based integer handles).

# Examples
```jldoctest
julia> using AletheiaData

julia> fam = ModelFamily([10, 20]);

julia> collect(eachinstance(fam))
2-element Vector{Int64}:
 1
 2
```
"""
eachinstance(family::AbstractModelFamily) = Base.OneTo(instance_count(family))

"""
Return the Aletheia model corresponding to one instance handle.

# Examples
```jldoctest
julia> using AletheiaData

julia> fam = ModelFamily([:m1, :m2]);

julia> instance_model(fam, 1)
:m1
```
"""
function instance_model(family::AbstractModelFamily, instance)
    return throw(MethodError(instance_model, (family, instance)))
end

"""
Return the frame corresponding to one instance handle.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> m = Model(Frame([:w1], Dict(); index=true), BOOLEAN, (a, w) -> true);

julia> fam = ModelFamily([m]);

julia> instance_frame(fam, 1) isa AbstractFrame
true
```
"""
function instance_frame(family::AbstractModelFamily, instance)
    return frame(instance_model(family, instance))
end

"""
    ModelFamily(models)

A concrete family for an indexable collection of Aletheia models. It is useful
for callers that already materialize models and is also the reference protocol
implementation for adapters.

# Examples
```jldoctest
julia> using AletheiaData

julia> fam = ModelFamily([:a, :b]);

julia> instance_count(fam)
2
```
"""
struct ModelFamily{M} <: AbstractModelFamily
    models::M
end

instance_count(family::ModelFamily) = length(family.models)
eachinstance(family::ModelFamily) = eachindex(family.models)
instance_model(family::ModelFamily, instance) = family.models[instance]

"""
    uniform_frame(family)

Return the shared frame when every instance has an equal frame, or `nothing`
for an empty or non-uniform family. Equality is checked on the frames rather
than assumed from the family type.
"""
function _same_frame(left::Frame, right::Frame)
    return worlds(left) == worlds(right) &&
           relations(left) == relations(right) &&
           world_index(left) == world_index(right)
end

"""
    uniform_frame(family)

Return the shared frame when every instance has an equal frame, or `nothing`
for an empty or non-uniform family.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> f = Frame([:w1], Dict(); index=true);

julia> m = Model(f, BOOLEAN, (a, w) -> true);

julia> fam = ModelFamily([m, m]);

julia> uniform_frame(fam) === f
true
```
"""
function uniform_frame(family::AbstractModelFamily)
    state = iterate(eachinstance(family))
    state === nothing && return nothing
    first_instance, iterator_state = state
    candidate = instance_frame(family, first_instance)
    while true
        state = iterate(eachinstance(family), iterator_state)
        state === nothing && return candidate
        instance, iterator_state = state
        _same_frame(candidate, instance_frame(family, instance)) || return nothing
    end
end

"""
Whether all instances in `family` use one equal frame.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> f = Frame([:w1], Dict(); index=true);

julia> m = Model(f, BOOLEAN, (a, w) -> true);

julia> fam = ModelFamily([m, m]);

julia> isuniform(fam)
true
```
"""
isuniform(family::AbstractModelFamily) = !isnothing(uniform_frame(family))

"""Evaluate a formula's extension for one instance in a model family."""
function extension(formula::Formula, family::AbstractModelFamily, instance)
    return extension(formula, instance_model(family, instance))
end

"""Evaluate a formula's extension for every instance, in instance order."""
function extension(formula::Formula, family::AbstractModelFamily)
    return [extension(formula, family, instance) for instance in eachinstance(family)]
end

"""
    extension(formulas, family)

Evaluate all formulas with one shared pooled-DAG pass per family instance.
The result is one vector per formula, and each vector contains extensions in
instance order.  This is the family counterpart of
[`extension(formulas, model)`](@ref).
"""
function extension(formulas::AbstractVector, family::AbstractModelFamily)
    normalized = _batch_formulas(formulas)
    isempty(normalized) && return Vector{Any}[]
    instances = eachinstance(family)
    state = iterate(instances)
    state === nothing && return [Any[] for _ in normalized]
    first_instance, iterator_state = state
    first_batch = extension(normalized, instance_model(family, first_instance))
    results = [
        Vector{typeof(first_batch[position])}() for position in eachindex(normalized)
    ]
    for position in eachindex(normalized)
        push!(results[position], first_batch[position])
    end
    while true
        state = iterate(instances, iterator_state)
        state === nothing && break
        instance, iterator_state = state
        batch = extension(normalized, instance_model(family, instance))
        for position in eachindex(normalized)
            push!(results[position], batch[position])
        end
    end
    return results
end

"""Evaluate all formulas for one instance of a model family."""
function extension(formulas::AbstractVector, family::AbstractModelFamily, instance)
    return extension(formulas, instance_model(family, instance))
end

"""Check a formula at one world of one instance in a model family."""
function check(formula::Formula, family::AbstractModelFamily, instance, world)
    return check(formula, instance_model(family, instance), world)
end
