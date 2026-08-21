"""Adapter used only by the SoleData dataset-protocol experiment."""

struct SoleDataFamily <: Aletheia.AbstractModelFamily
    dataset::Any
    models::Vector{Any}
    vectorized::Bool
end

function _aletheia_frame(source_frame, relation=nothing)
    source_worlds = collect(SoleLogics.allworlds(source_frame))
    source_accessibles(world) = isnothing(relation) ?
        SoleLogics.accessibles(source_frame, world) :
        SoleLogics.accessibles(source_frame, world, relation)
    adjacency = Dict(
        world => Tuple(source_accessibles(world)) for world in source_worlds
    )
    Aletheia.Frame(source_worlds, Dict(:R => adjacency); index=true)
end

function _aletheia_model(dataset, i_instance, vectorized, relation=nothing)
    source_frame = SoleLogics.frame(dataset, i_instance)
    frame = _aletheia_frame(source_frame, relation)
    scalar = (condition, world) ->
        SoleData.checkcondition(condition, dataset, i_instance, world)
    batch = vectorized ?
        ((condition, worlds) -> BitVector(
            SoleData.checkcondition(condition, dataset, i_instance, world)
            for world in worlds
        )) : nothing
    valuation = Aletheia.ValuationCallback(scalar; vectorized=batch)
    Aletheia.Model(frame, Aletheia.BOOLEAN, valuation)
end

function SoleDataFamily(dataset; vectorized=true, relation=nothing)
    models = Any[
        _aletheia_model(dataset, i_instance, vectorized, relation)
        for i_instance in 1:SoleData.ninstances(dataset)
    ]
    SoleDataFamily(dataset, models, vectorized)
end

Aletheia.instance_count(family::SoleDataFamily) = SoleData.ninstances(family.dataset)
Aletheia.eachinstance(family::SoleDataFamily) = Base.OneTo(SoleData.ninstances(family.dataset))
Aletheia.instance_model(family::SoleDataFamily, i_instance) = family.models[i_instance]

function sole_check_all(formula, dataset, i_instance)
    source_worlds = SoleLogics.allworlds(SoleLogics.frame(dataset, i_instance))
    BitVector(
        SoleData.check(formula, dataset, i_instance, world; perform_normalization=false)
        for world in source_worlds
    )
end
