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

# Canonical frame reuse must not change the world object observed by a
# callable valuation. Translate the canonical representative back to the
# original frame before invoking such callbacks.
function _original_world(original::Frame, representative::Frame, world)
    position = findfirst(candidate -> isequal(candidate, world), worlds(representative))
    position === nothing && throw(KeyError(world))
    return worlds(original)[position]
end
function _rebase_valuation(original::Frame, representative::Frame, valuation::Function)
    return (atom, world) ->
        valuation(atom, _original_world(original, representative, world))
end
function _rebase_valuation(
    original::Frame, representative::Frame, valuation::ValuationCallback
)
    scalar =
        (atom, world) ->
            valuation.scalar(atom, _original_world(original, representative, world))
    batch = if valuation.vectorized === nothing
        nothing
    else
        (atom, worlds_value) -> valuation.vectorized(
        atom,
        tuple(
            (_original_world(original, representative, world) for world in worlds_value)...,
        ),
    )
    end
    return ValuationCallback(scalar; vectorized=batch)
end
function _rebase_valuation(original::Frame, representative::Frame, valuation::Valuation)
    return if valuation.data isa Function
        Valuation(_rebase_valuation(original, representative, valuation.data))
    else
        valuation
    end
end
_rebase_valuation(::Frame, ::Frame, valuation) = valuation

# Canonicalize semantically equal model frames at the family boundary so a
# uniform family uses one Core adjacency cache.
function _canonical_model_vector(models)
    result = Any[]
    representatives = Frame[]
    isempty(models) && return result
    expected_algebra = algebra(first(models))
    for (instance, model) in enumerate(models)
        isequal(algebra(model), expected_algebra) ||
            throw(MixedAlgebraError(expected_algebra, algebra(model), instance))
    end
    for model in models
        model_frame = frame(model)
        representative = findfirst(
            candidate -> _same_frame(candidate, model_frame), representatives
        )
        if representative === nothing
            push!(representatives, model_frame)
            push!(result, model)
        else
            push!(
                result,
                Model(
                    representatives[representative],
                    algebra(model),
                    _rebase_valuation(
                        model_frame, representatives[representative], valuation(model)
                    ),
                ),
            )
        end
    end
    return result
end
function ModelFamily(models::AbstractVector)
    # Route every model collection through the checked constructor, including
    # collections whose element type has been erased to `Any`.
    if all(model -> model isa Model, models)
        canonical = _canonical_model_vector(models)
        return ModelFamily{typeof(canonical)}(canonical)
    end
    return ModelFamily{typeof(models)}(models)
end
function ModelFamily(models::Tuple{Vararg{<:Model}})
    canonical = _canonical_model_vector(models)
    return ModelFamily{typeof(canonical)}(canonical)
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
    # Frame identity is intentionally irrelevant here: an equal world order and
    # relation mapping provide the same evaluation plan.  The world index is an
    # implementation detail and does not change frame semantics.
    return isequal(worlds(left), worlds(right)) &&
        isequal(relations(left), relations(right))
end

# Retain the first frame for each equal world/relation signature.  This is
# deduplication only; frames with different semantics keep their identity.
function _share_frames(frames)
    representatives = Any[]
    for position in eachindex(frames)
        candidate = frames[position]
        representative = findfirst(frame -> _same_frame(frame, candidate), representatives)
        if representative === nothing
            push!(representatives, candidate)
        else
            frames[position] = representatives[representative]
        end
    end
    return frames
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
function _batch_extension(normalized::Vector{Formula}, family::ModelFamily)
    nodes, positions = _batch_evaluation_nodes(normalized)
    models = family.models
    isempty(models) && return [Any[] for _ in normalized]
    first_model = first(models)
    last_frame = frame(first_model)
    plan = _evaluation_plan(nodes, first_model)
    first_batch = _batch_evaluate(normalized, nodes, positions, first_model, plan)
    results = [
        Vector{typeof(first_batch[position])}(undef, length(models)) for
        position in eachindex(normalized)
    ]
    for position in eachindex(normalized)
        results[position][1] = first_batch[position]
    end
    for (instance, model) in enumerate(models)
        instance == 1 && continue
        model_frame = frame(model)
        if model_frame !== last_frame
            last_frame = model_frame
            plan = _evaluation_plan(nodes, model)
        end
        batch = _batch_evaluate(normalized, nodes, positions, model, plan)
        for position in eachindex(normalized)
            results[position][instance] = batch[position]
        end
    end
    return results
end

function extension(formulas::AbstractVector, family::ModelFamily)
    normalized = _batch_formulas(formulas)
    isempty(normalized) && return Vector{Any}[]
    return _batch_extension(normalized, family)
end

# Retain the protocol fallback for custom family implementations.
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
