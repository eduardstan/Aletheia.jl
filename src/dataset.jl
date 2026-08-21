# Dependency-free protocol for evaluating a family of per-instance models.

"""
    AbstractModelFamily

A family of logical instances.  Implementations provide `instance_count` and
`instance_model`; the latter returns an Aletheia [`Model`](@ref) for one
instance.  A model's frame may differ between instances.
"""
abstract type AbstractModelFamily end

"""Return the number of instances in `family`."""
function instance_count(family::AbstractModelFamily)
    throw(MethodError(instance_count, (family,)))
end

"""Iterate stable instance handles (by default, one-based integer handles)."""
eachinstance(family::AbstractModelFamily) = Base.OneTo(instance_count(family))

"""Return the Aletheia model corresponding to one instance handle."""
function instance_model(family::AbstractModelFamily, instance)
    throw(MethodError(instance_model, (family, instance)))
end

"""Return the frame corresponding to one instance handle."""
instance_frame(family::AbstractModelFamily, instance) = frame(instance_model(family, instance))

"""
    ModelFamily(models)

A concrete family for an indexable collection of Aletheia models.  It is useful
for callers that already materialize models and is also the reference protocol
implementation for adapters.
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
for an empty or non-uniform family.  Equality is checked on the frames rather
than assumed from the family type.
"""
function _same_frame(left::Frame, right::Frame)
    worlds(left) == worlds(right) && relations(left) == relations(right) &&
        world_index(left) == world_index(right)
end

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

"""Whether all instances in `family` use one equal frame."""
isuniform(family::AbstractModelFamily) = !isnothing(uniform_frame(family))

"""Evaluate a formula's extension for one instance in a model family."""
extension(formula::Formula, family::AbstractModelFamily, instance) =
    extension(formula, instance_model(family, instance))

"""Evaluate a formula's extension for every instance, in instance order."""
extension(formula::Formula, family::AbstractModelFamily) =
    [extension(formula, family, instance) for instance in eachinstance(family)]

"""Check a formula at one world of one instance in a model family."""
check(formula::Formula, family::AbstractModelFamily, instance, world) =
    check(formula, instance_model(family, instance), world)
