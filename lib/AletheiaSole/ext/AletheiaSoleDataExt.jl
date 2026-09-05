"""SoleData bridge for Aletheia model families.

This extension is loaded only when SoleData is present.  SoleData remains the
owner of feature and condition evaluation; Aletheia owns the frame/model
semantics and formula evaluation.
"""
module AletheiaSoleDataExt

import AletheiaSole
import AletheiaCore
import AletheiaData
import SoleData

const Aletheia = AletheiaCore

"""A family of Aletheia models backed by a SoleData modal logiset.

The adapter materialises one Aletheia model per SoleData instance.  `relation`
is the relation passed to SoleData's `accessibles` method; the converted
Aletheia frame exposes that adjacency as `:R`, which lets formulas use one
stable relation name independently of SoleData's relation vocabulary.  For a
unimodal SoleData frame, leave `relation` as `nothing`.

Set `vectorized=false` to disable the optional batch atom callback.  This is a
correctness option for comparing scalar callbacks; the default batch callback
is the efficient path for `extension`.
"""
struct SoleDataFamily{D,M,R} <: AletheiaData.AbstractModelFamily
    dataset::D
    models::M
    relation::R
end

function _source_accessibles(source_frame, world, relation)
    isnothing(relation) ?
        SoleData.accessibles(source_frame, world) :
        SoleData.accessibles(source_frame, world, relation)
end

function _aletheia_frame(source_frame, relation)
    source_worlds = collect(SoleData.allworlds(source_frame))
    adjacency = Dict(
        world => Tuple(_source_accessibles(source_frame, world, relation))
        for world in source_worlds
    )
    Aletheia.Frame(source_worlds, Dict(:R => adjacency); index=true)
end

function _aletheia_model(dataset, i_instance, vectorized, converted_frame)
    prepared = AletheiaData.prepare_scalar(dataset; instances=[i_instance])
    scalar = (condition, world) ->
        AletheiaData.scalar_check(condition, prepared, i_instance, world)
    batch = vectorized ?
        ((condition, worlds) -> BitVector(
            AletheiaData.scalar_check(condition, prepared, i_instance, world)
            for world in worlds
        )) : nothing
    valuation = Aletheia.ValuationCallback(scalar; vectorized=batch)
    Aletheia.Model(converted_frame, Aletheia.BOOLEAN, valuation)
end

"""Construct a `SoleDataFamily` from an `AbstractModalLogiset`."""
function SoleDataFamily(dataset::SoleData.AbstractModalLogiset;
        vectorized::Bool=true, relation=nothing)
    # Keep one converted Frame for each equal world/relation signature.  This
    # preserves Aletheia's valuation-independent adjacency cache without
    # assuming that all SoleData instances have the same frame.
    converted_frames = Any[]
    models = Any[]
    for i_instance in 1:SoleData.ninstances(dataset)
        converted = _aletheia_frame(SoleData.frame(dataset, i_instance), relation)
        slot = findfirst(candidate ->
            AletheiaData._same_frame(candidate, converted), converted_frames)
        if slot === nothing
            push!(converted_frames, converted)
            slot = length(converted_frames)
        end
        push!(models, _aletheia_model(
            dataset, i_instance, vectorized, converted_frames[slot]))
    end
    SoleDataFamily(dataset, models, relation)
end

AletheiaData.instance_count(family::SoleDataFamily) =
    SoleData.ninstances(family.dataset)
AletheiaData.eachinstance(family::SoleDataFamily) =
    Base.OneTo(SoleData.ninstances(family.dataset))
AletheiaData.instance_model(family::SoleDataFamily, i_instance) =
    family.models[i_instance]


# SoleData's `featvalue(feature, dataset, instance, world)` is adapted to the
# core's source protocol.  The wrapper keeps SoleData out of Aletheia's core
# and lets preparation copy dimensional or explicit stores into one dense
# world × instance × feature layout.
struct _SoleDataSource{D}
    dataset::D
    _SoleDataSource{D}(dataset::D, ::Val{:snapshot}) where D = new{D}(dataset)
end
function _SoleDataSource(dataset::SoleData.AbstractModalLogiset)
    snapshot = try
        deepcopy(dataset)
    catch
        throw(AletheiaCore.OwnershipError(
            dataset, (), "SoleData sources must be snapshot-able before preparation"
        ))
    end
    return _SoleDataSource{typeof(snapshot)}(snapshot, Val(:snapshot))
end
# The source is kept only in the prepared-state registry. Prepared semantic
# records contain dense values and a deep-copied SoleData source snapshot, not
# the caller's mutable adapter.
AletheiaData.feature_value(source::_SoleDataSource, instance, world, feature) =
    SoleData.featvalue(feature, source.dataset, instance, world)

function _sole_features(dataset, requested)
    if requested !== nothing && !isempty(requested)
        return collect(requested)
    end
    available = try
        SoleData.features(dataset)
    catch error
        (error isa MethodError || error isa ErrorException) || rethrow()
        nothing
    end
    available !== nothing && return collect(available)
    hasfield(typeof(dataset), :d) || return nothing
    found = Set{Any}()
    for (channels, _) in getfield(dataset, :d), world_values in Base.values(channels), feature in keys(world_values)
        push!(found, feature)
    end
    collect(found)
end

"""Prepare a SoleData modal logiset through Aletheia's scalar protocol."""
function AletheiaData.prepare_scalar(dataset::SoleData.AbstractModalLogiset;
        features=nothing, frames=nothing, relations=(), relation=nothing,
        precompute_features=true, precompute_aggregates=(), instances=nothing,
        worlds=nothing, version=nothing)
    n = SoleData.ninstances(dataset)
    labels = instances === nothing ? collect(1:n) : collect(instances)
    source_frames = [SoleData.frame(dataset, i) for i in labels]
    function sole_accessibles(fr, w)
        isnothing(relation) || return SoleData.accessibles(fr, w, relation)
        try
            SoleData.accessibles(fr, w)
        catch error
            error isa MethodError || rethrow()
            ()
        end
    end
    converted = AletheiaData._share_frames([Aletheia.Frame(collect(SoleData.allworlds(fr)),
        Dict(:R => Dict(w => Tuple(sole_accessibles(fr, w)) for w in SoleData.allworlds(fr)));
            index=true) for fr in source_frames])
    feature_list = _sole_features(dataset, features)
    AletheiaData.prepare_scalar(_SoleDataSource(dataset); features=feature_list,
        frames=converted, relations=isempty(relations) ? (:R,) : relations,
        precompute_features=precompute_features,
        precompute_aggregates=precompute_aggregates, instances=labels,
        worlds=worlds, version=version)
end

# Existing SoleData condition payloads remain usable in pooled atoms.  Read
# through the prepared snapshot so callers use Aletheia's integer world order.
function AletheiaData.scalar_check(condition::SoleData.AbstractScalarCondition,
        data::AletheiaData.PreparedScalarData, instance, world)
    source = AletheiaData.source(data)
    source isa _SoleDataSource || throw(ArgumentError("prepared data was not built from SoleData"))
    frame = AletheiaData._frame(data, instance)
    world_key = world isa Integer ? Aletheia.worlds(frame)[world] : world
    SoleData.test_operator(condition)(
        AletheiaData.feature_value(data, instance, world_key, SoleData.feature(condition)),
        SoleData.threshold(condition),
    )
end

# Install convenient aliases after the extension is loaded.  Parent modules are
# closed during extension precompilation, so this belongs in `__init__` rather
# than at top level.
function __init__()
    Core.eval(Aletheia, :(const SoleDataFamily = $SoleDataFamily))
    Core.eval(Aletheia, :(export SoleDataFamily))
    Core.eval(AletheiaSole.SoleLogics, :(const SoleDataFamily = $SoleDataFamily))
    Core.eval(AletheiaSole.SoleLogics, :(export SoleDataFamily))
end

end
