"""Batch antecedent adapter for a SoleModels decision list.

This file is an adoption example, not a dependency of Aletheia.  A consumer
owns the conversion from its SoleLogics formulas to Aletheia's pooled syntax,
then hands the complete rule set to `Aletheia.extension` through
`batch_checkantecedents`.
"""
module DecisionListBatchAdapter

export batch_checkantecedents, batch_apply

using Aletheia
import SoleData
import SoleLogics
import SoleModels

struct _BatchTruth
    value::Bool
end

struct _BatchRelation{R}
    source::R
    label::Symbol
end
Aletheia.notation(relation::_BatchRelation) = String(relation.label)
Base.show(io::IO, relation::_BatchRelation) = print(io, relation.label)

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
    throw(ArgumentError("unsupported SoleLogics connective $(repr(token))"))
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
    (:branch, _native_connective(token, relation_map), [_shape(child, relation_map) for child in children])
end

function _collect_connectives!(out, shape)
    shape[1] === :branch || return out
    push!(out, shape[2])
    foreach(child -> _collect_connectives!(out, child), shape[3])
    out
end

function _intern(pool, shape)
    shape[1] === :atom && return Aletheia.atom(pool, shape[2])
    shape[1] === :truth && return Aletheia.atom(pool, _BatchTruth(shape[2]))
    children = Tuple(_intern(pool, child) for child in shape[3])
    Aletheia.branch(pool, shape[2], children)
end

function _source_dataset(dataset)
    dataset isa SoleData.MultiLogiset ? SoleData.modality(dataset, 1) : dataset
end

function _model_family(dataset, relation_names)
    models = Any[]
    for i_instance in 1:SoleData.ninstances(dataset)
        source_frame = SoleData.frame(dataset, i_instance)
        source_worlds = collect(SoleData.allworlds(source_frame))
        adjacency = Dict(
            relation_name => Dict(
                world => Tuple(SoleData.accessibles(source_frame, world, relation_name.source))
                for world in source_worlds
            ) for relation_name in relation_names
        )
        native_frame = Aletheia.Frame(source_worlds, adjacency; index=true)
        scalar = (condition, world) -> condition isa _BatchTruth ? condition.value :
            SoleData.checkcondition(condition, dataset, i_instance, world)
        vectorized = (condition, worlds) -> BitVector(scalar(condition, world) for world in worlds)
        valuation = Aletheia.ValuationCallback(scalar; vectorized=vectorized)
        push!(models, Aletheia.Model(native_frame, Aletheia.BOOLEAN, valuation))
    end
    Aletheia.ModelFamily(models)
end

"""Return one Boolean mask per rule, using one pooled batch per instance."""
function batch_checkantecedents(rules::AbstractVector, dataset)
    source = _source_dataset(dataset)
    relation_map = Dict{Any,Any}()
    shapes = [_shape(SoleModels.antecedent(rule), relation_map) for rule in rules]
    connectives = Any[]
    foreach(shape -> _collect_connectives!(connectives, shape), shapes)
    isempty(connectives) && push!(connectives, Aletheia.:¬)
    pool = Aletheia.FormulaPool(Aletheia.Signature(unique(connectives)))
    formulas = [_intern(pool, shape) for shape in shapes]
    relation_names = Any[]
    for connective in connectives
        connective isa Union{Aletheia.Diamond,Aletheia.Box} && push!(relation_names, Aletheia.relation(connective))
    end
    family = _model_family(source, unique(relation_names))
    extensions = Aletheia.extension(formulas, family)
    [BitVector(any(values) for values in per_instance) for per_instance in extensions]
end

batch_checkantecedents(model::SoleModels.DecisionList, dataset) =
    batch_checkantecedents(SoleModels.rulebase(model), dataset)

"""Apply a DecisionList after evaluating all of its antecedents in one batch."""
function batch_apply(model::SoleModels.DecisionList, dataset)
    masks = batch_checkantecedents(model, dataset)
    predictions = Vector{Any}(undef, SoleData.ninstances(_source_dataset(dataset)))
    rules = SoleModels.rulebase(model)
    for instance in eachindex(predictions)
        rule_position = findfirst(mask -> mask[instance], masks)
        chosen = rule_position === nothing ? SoleModels.defaultconsequent(model) :
            SoleModels.consequent(rules[rule_position])
        predictions[instance] = SoleModels.outcome(chosen)
    end
    predictions
end

end
