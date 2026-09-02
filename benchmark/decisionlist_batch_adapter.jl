"""Batch antecedent adapter for a SoleModels decision list.

This file is an adoption example, not a dependency of Aletheia.  A consumer
owns the conversion from its SoleLogics formulas to Aletheia's pooled syntax,
then hands the complete rule set to `Aletheia.extension` through
`batch_checkantecedents`.
"""
module DecisionListBatchAdapter

export batch_checkantecedents, batch_apply, prepare, apply_prepared

using Aletheia
using SoleData: SoleData
using SoleLogics: SoleLogics
using SoleModels: SoleModels

struct _BatchTruth
    value::Bool
end

struct _BatchRelation{R}
    source::R
    label::Symbol
end
Aletheia.notation(relation::_BatchRelation) = String(relation.label)
Base.show(io::IO, relation::_BatchRelation) = print(io, relation.label)

struct PreparedDecisionList
    rules::Vector{Any}
    family::Any
    formulas::Vector{Any}
    ninstances::Int
end

function _native_connective(token, relation_map)
    token == SoleLogics.:¬ && return Aletheia.:¬
    token == SoleLogics.:∧ && return Aletheia.:∧
    token == SoleLogics.:∨ && return Aletheia.:∨
    token == SoleLogics.:→ && return Aletheia.:→
    if SoleLogics.isdiamond(token) || SoleLogics.isbox(token)
        source_relation = SoleLogics.relation(token)
        relation = get!(relation_map, source_relation) do
            _BatchRelation(source_relation, Symbol("R", length(relation_map) + 1))
        end
        SoleLogics.isdiamond(token) && return Aletheia.Diamond(relation)
        return Aletheia.Box(relation)
    end
    return throw(ArgumentError("unsupported SoleLogics connective $(repr(token))"))
end

# Keep a small syntax description until the complete connective signature is
# known.  This also lets MultiFormula antecedents combine their modalities.
function _shape(formula, relation_map)
    if formula isa SoleData.MultiFormula
        parts = [_shape(part, relation_map) for part in values(SoleData.modforms(formula))]
        isempty(parts) && throw(ArgumentError("a MultiFormula has no modality formulas"))
        return length(parts) == 1 ? first(parts) : (:branch, Aletheia.:∧, parts)
    end
    tree = SoleLogics.tree(formula)
    token = SoleLogics.token(tree)
    children = SoleLogics.children(tree)
    isempty(children) && begin
        token isa SoleLogics.Truth && return (:truth, SoleLogics.istop(token))
        token isa SoleLogics.AbstractAtom && return (:atom, SoleLogics.value(token))
        throw(ArgumentError("unsupported SoleLogics leaf $(repr(token))"))
    end
    return (
        :branch,
        _native_connective(token, relation_map),
        [_shape(child, relation_map) for child in children],
    )
end

function _collect_connectives!(out, shape)
    shape[1] === :branch || return out
    push!(out, shape[2])
    foreach(child -> _collect_connectives!(out, child), shape[3])
    return out
end

function _intern(pool, shape)
    shape[1] === :atom && return Aletheia.atom(pool, shape[2])
    shape[1] === :truth && return Aletheia.atom(pool, _BatchTruth(shape[2]))
    children = Tuple(_intern(pool, child) for child in shape[3])
    return Aletheia.branch(pool, shape[2], children)
end

function _source_dataset(dataset)
    return dataset isa SoleData.MultiLogiset ? SoleData.modality(dataset, 1) : dataset
end

function _model_family(dataset, relation_names; vectorized=true)
    models = Any[]
    for i_instance in 1:SoleData.ninstances(dataset)
        source_frame = SoleData.frame(dataset, i_instance)
        source_worlds = collect(SoleData.allworlds(source_frame))
        adjacency = Dict(
            relation_name => Dict(
                world => Tuple(
                    SoleData.accessibles(source_frame, world, relation_name.source)
                ) for world in source_worlds
            ) for relation_name in relation_names
        )
        native_frame = Aletheia.Frame(source_worlds, adjacency; index=true)
        scalar =
            (condition, world) -> if condition isa _BatchTruth
                condition.value
            else
                SoleData.checkcondition(condition, dataset, i_instance, world)
            end
        batch = if vectorized
            ((condition, worlds) -> BitVector(scalar(condition, world) for world in worlds))
        else
            nothing
        end
        valuation = Aletheia.ValuationCallback(scalar; vectorized=batch)
        push!(models, Aletheia.Model(native_frame, Aletheia.BOOLEAN, valuation))
    end
    return Aletheia.ModelFamily(models)
end

"""Prepare conversion and the model family outside a timed apply call."""
function _prepare_rules(rules::AbstractVector, dataset; vectorized=true)
    source = _source_dataset(dataset)
    rules = Any[rules...]
    relation_map = Dict{Any,Any}()
    shapes = [_shape(SoleModels.antecedent(rule), relation_map) for rule in rules]
    connectives = Any[]
    foreach(shape -> _collect_connectives!(connectives, shape), shapes)
    isempty(connectives) && push!(connectives, Aletheia.:¬)
    pool = Aletheia.FormulaPool(Aletheia.Signature(unique(connectives)))
    formulas = Any[_intern(pool, shape) for shape in shapes]
    relation_names = Any[]
    for connective in connectives
        connective isa Union{Aletheia.Diamond,Aletheia.Box} &&
            push!(relation_names, Aletheia.relation(connective))
    end
    family = _model_family(source, unique(relation_names); vectorized=vectorized)
    return PreparedDecisionList(rules, family, formulas, SoleData.ninstances(source))
end

function prepare(model::SoleModels.DecisionList, dataset; vectorized=true)
    return _prepare_rules(SoleModels.rulebase(model), dataset; vectorized=vectorized)
end

"""Return one Boolean mask per rule from a prepared decision list."""
function batch_checkantecedents(state::PreparedDecisionList)
    extensions = Aletheia.extension(state.formulas, state.family)
    return [
        BitVector(any(values) for values in per_instance) for per_instance in extensions
    ]
end

function batch_checkantecedents(rules::AbstractVector, dataset; vectorized=true)
    return batch_checkantecedents(_prepare_rules(rules, dataset; vectorized=vectorized))
end

function batch_checkantecedents(model::SoleModels.DecisionList, dataset; vectorized=true)
    return batch_checkantecedents(prepare(model, dataset; vectorized=vectorized))
end

"""Apply a prepared decision list after evaluating its antecedents in one batch."""
function apply_prepared(state::PreparedDecisionList, model::SoleModels.DecisionList)
    masks = batch_checkantecedents(state)
    predictions = Vector{Any}(undef, state.ninstances)
    for instance in eachindex(predictions)
        rule_position = findfirst(mask -> mask[instance], masks)
        chosen = if rule_position === nothing
            SoleModels.defaultconsequent(model)
        else
            SoleModels.consequent(state.rules[rule_position])
        end
        predictions[instance] = SoleModels.outcome(chosen)
    end
    return predictions
end

"""Apply a DecisionList, including conversion and family construction."""
function batch_apply(model::SoleModels.DecisionList, dataset; vectorized=true)
    state = prepare(model, dataset; vectorized=vectorized)
    return apply_prepared(state, model)
end

end
