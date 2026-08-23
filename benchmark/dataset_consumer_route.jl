# Scratch-only SoleModels route copied into a disposable package tree by dataset_consumer.jl.
# This is deliberately not a production SoleModels integration.
using Aletheia

struct Stage2ConsumerFamily <: Aletheia.AbstractModelFamily
    dataset::Any
    models::Vector{Any}
end

Aletheia.instance_count(family::Stage2ConsumerFamily) = SoleData.ninstances(family.dataset)
Aletheia.eachinstance(family::Stage2ConsumerFamily) = Base.OneTo(SoleData.ninstances(family.dataset))
Aletheia.instance_model(family::Stage2ConsumerFamily, instance) = family.models[instance]

function _stage2_frame(source_frame)
    source_worlds = Tuple(SoleLogics.allworlds(source_frame))
    adjacency = Dict{Any,Any}()
    for (rel, name) in ((SoleLogics.globalrel, :G), (SoleLogics.IA_L, :L))
        adjacency[name] = Dict(world => Tuple(SoleLogics.accessibles(source_frame, world, rel))
                               for world in source_worlds)
    end
    Aletheia.Frame(source_worlds, adjacency; index=true),
    (source_worlds, Tuple((name, adjacency[name]) for name in (:G, :L)))
end

function _stage2_model(dataset, instance, frame)
    scalar = (condition, world) -> SoleData.checkcondition(condition, dataset, instance, world)
    batch = (condition, worlds) -> BitVector(
        SoleData.checkcondition(condition, dataset, instance, world) for world in worlds)
    Aletheia.Model(frame, Aletheia.BOOLEAN,
        Aletheia.ValuationCallback(scalar; vectorized=batch))
end

function stage2_family(dataset)
    frames = Any[]
    signatures = Any[]
    model_frames = Any[]
    for instance in 1:SoleData.ninstances(dataset)
        frame, signature = _stage2_frame(SoleLogics.frame(dataset, instance))
        position = findfirst(existing -> isequal(existing, signature), signatures)
        if position === nothing
            push!(signatures, signature)
            push!(frames, frame)
            position = length(frames)
        end
        push!(model_frames, frames[position])
    end
    models = Any[_stage2_model(dataset, instance, model_frames[instance])
                 for instance in 1:SoleData.ninstances(dataset)]
    Stage2ConsumerFamily(dataset, models)
end

mutable struct Stage2ConsumerState
    family::Stage2ConsumerFamily
    pool::Aletheia.FormulaPool
    formulas::Dict{Any,Aletheia.Formula}
end

function stage2_state(dataset)
    Stage2ConsumerState(stage2_family(dataset), Aletheia.FormulaPool(Aletheia.Signature((
        Aletheia.NEGATION, Aletheia.CONJUNCTION, Aletheia.DISJUNCTION,
        Aletheia.IMPLICATION, Aletheia.Diamond(:G),
        Aletheia.Box(:G), Aletheia.Diamond(:L),
        Aletheia.Box(:L)))), Dict{Any,Aletheia.Formula}())
end

const STAGE2_STATES = IdDict{Any,Stage2ConsumerState}()

function stage2_state_for(dataset)
    get!(STAGE2_STATES, dataset) do
        stage2_state(dataset)
    end
end

function _stage2_relation(relation)
    relation == SoleLogics.globalrel && return :G
    relation == SoleLogics.IA_L && return :L
    throw(ArgumentError("unsupported SoleLogics relation $(repr(relation))"))
end

function _stage2_connective(token)
    token === SoleLogics.:(¬) && return Aletheia.NEGATION
    token === SoleLogics.:(∧) && return Aletheia.CONJUNCTION
    token === SoleLogics.:(∨) && return Aletheia.DISJUNCTION
    token === SoleLogics.:(→) && return Aletheia.IMPLICATION
    SoleLogics.isdiamond(token) && return Aletheia.Diamond(_stage2_relation(SoleLogics.relation(token)))
    SoleLogics.isbox(token) && return Aletheia.Box(_stage2_relation(SoleLogics.relation(token)))
    throw(ArgumentError("unsupported SoleLogics connective $(repr(token))"))
end

function _stage2_formula(formula, state::Stage2ConsumerState)
    key = SoleLogics.tree(formula)
    get!(state.formulas, key) do
        if formula isa SoleLogics.Atom
            Aletheia.atom(state.pool, SoleLogics.value(formula))
        elseif formula isa SoleLogics.SyntaxBranch
            token = SoleLogics.token(formula)
            children = (_stage2_formula(child, state) for child in SoleLogics.children(formula))
            Aletheia.branch(state.pool, _stage2_connective(token), children...)
        else
            throw(ArgumentError("unsupported SoleLogics formula $(typeof(formula))"))
        end
    end
end

function _stage2_checkantecedent(m::Union{SoleModels.Rule,SoleModels.Branch},
                                 dataset::SoleData.AbstractLogiset; kwargs...)
    state = stage2_state_for(dataset)
    formula = _stage2_formula(SoleModels.antecedent(m), state)
    BitVector(any(values) for values in Aletheia.extension(formula, state.family))
end

SoleModels.checkantecedent(m::Union{SoleModels.Rule,SoleModels.Branch},
                           dataset::SoleData.AbstractLogiset; kwargs...) =
    _stage2_checkantecedent(m, dataset; kwargs...)
