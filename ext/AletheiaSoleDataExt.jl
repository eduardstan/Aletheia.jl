"""SoleData bridge for Aletheia model families.

This extension is loaded only when SoleData is present.  SoleData remains the
owner of feature and condition evaluation; Aletheia owns the frame/model
semantics and formula evaluation.
"""
module AletheiaSoleDataExt

import Aletheia
import SoleData

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
struct SoleDataFamily{D,M,R} <: Aletheia.AbstractModelFamily
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
    scalar = (condition, world) ->
        SoleData.checkcondition(condition, dataset, i_instance, world)
    batch = vectorized ?
        ((condition, worlds) -> BitVector(
            SoleData.checkcondition(condition, dataset, i_instance, world)
            for world in worlds
        )) : nothing
    valuation = Aletheia.ValuationCallback(scalar; vectorized=batch)
    Aletheia.Model(converted_frame, Aletheia.BOOLEAN, valuation)
end

"""Construct a `SoleDataFamily` from an `AbstractModalLogiset`."""
function SoleDataFamily(dataset::SoleData.AbstractModalLogiset;
        vectorized::Bool=true, relation=nothing)
    # Keep one converted Frame for equal source frames.  This preserves
    # Aletheia's valuation-independent adjacency cache without assuming that
    # all SoleData instances have the same frame.
    source_frames = Any[]
    converted_frames = Any[]
    models = Any[]
    for i_instance in 1:SoleData.ninstances(dataset)
        source_frame = SoleData.frame(dataset, i_instance)
        slot = findfirst(candidate -> isequal(candidate, source_frame), source_frames)
        if slot === nothing
            push!(source_frames, source_frame)
            push!(converted_frames, _aletheia_frame(source_frame, relation))
            slot = length(converted_frames)
        end
        push!(models, _aletheia_model(
            dataset, i_instance, vectorized, converted_frames[slot]))
    end
    SoleDataFamily(dataset, models, relation)
end

Aletheia.instance_count(family::SoleDataFamily) =
    SoleData.ninstances(family.dataset)
Aletheia.eachinstance(family::SoleDataFamily) =
    Base.OneTo(SoleData.ninstances(family.dataset))
Aletheia.instance_model(family::SoleDataFamily, i_instance) =
    family.models[i_instance]

# Install convenient aliases after the extension is loaded.  Parent modules are
# closed during extension precompilation, so this belongs in `__init__` rather
# than at top level.
function __init__()
    Core.eval(Aletheia, :(const SoleDataFamily = $SoleDataFamily))
    Core.eval(Aletheia, :(export SoleDataFamily))
    Core.eval(Aletheia.SoleLogics, :(const SoleDataFamily = $SoleDataFamily))
    Core.eval(Aletheia.SoleLogics, :(export SoleDataFamily))
end

end
