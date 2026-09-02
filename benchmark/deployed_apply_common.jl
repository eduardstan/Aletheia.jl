# Shared fixture and parity oracle for the deployed apply benchmark.
using Aletheia
using SoleData
using SoleLogics
using SoleModels
using ModalDecisionTrees
using DataFrames
using Graphs
using Random

include(joinpath(@__DIR__, "dataset_protocol_shared.jl"))
include(joinpath(@__DIR__, "decisionlist_batch_adapter.jl"))
using .DecisionListBatchAdapter

const APPLY_SEED = 0xA11A_2024
const APPLY_DATA_SEED = DATASET_SEED + 0xA11A
const APPLY_TRAIN_SEED = 0x5EED_2025
const APPLY_SEEDS = (0xA1E7_2024, 0x5EED_2025, 0xC0FF_EE42, 0x1234_5678, 0x9ABC_DEF0)
const APPLY_NINSTANCES = 16
const APPLY_NPOINTS = 8
const APPLY_DEPTH = 5

struct ScalarLayerState
    data::Any
    formulas::Vector{Any}
    family::Any
end

struct ApplyFixture
    dataset::Any
    modalities::Any
    tree::Any
    model::Any
    rules::Any
    decision_list::Any
    scalar_state::Any
    vector_state::Any
    bridge_scalar::Any
    bridge_vectorized::Any
    dense_scalar::Any
    dense_vectorized::Any
end

function build_apply_fixture(; ninstances=APPLY_NINSTANCES, npoints=APPLY_NPOINTS,
        train_seed=APPLY_TRAIN_SEED, scalar_layer=false)
    dataset = make_supported_dataset(ninstances, npoints)
    modalities = SoleData.MultiLogiset(dataset)
    labels = [isodd(i) ? "class-a" : "class-b" for i in 1:ninstances]
    tree = ModalDecisionTrees.build_tree(modalities, labels;
        min_samples_leaf=2, max_depth=APPLY_DEPTH,
        rng=MersenneTwister(train_seed), print_progress=false)
    model = ModalDecisionTrees.translate(tree)
    all_rules = SoleModels.listrules(model)
    length(all_rules) >= 2 || error("deployed tree did not produce a default rule")
    decision_list = SoleModels.DecisionList(all_rules[1:end-1],
        SoleModels.consequent(all_rules[end]))
    scalar_state = DecisionListBatchAdapter.prepare(decision_list, modalities; vectorized=false)
    vector_state = DecisionListBatchAdapter.prepare(decision_list, modalities; vectorized=true)
    bridge_scalar = scalar_layer ? build_bridge_scalar_layer_state(
        dataset, vector_state; vectorized=false) : nothing
    bridge_vectorized = scalar_layer ? build_bridge_scalar_layer_state(
        dataset, vector_state; vectorized=true) : nothing
    dense_scalar = scalar_layer ? build_dense_scalar_layer_state(
        dataset, vector_state; vectorized=false) : nothing
    dense_vectorized = scalar_layer ? build_dense_scalar_layer_state(
        dataset, vector_state; vectorized=true) : nothing
    ApplyFixture(dataset, modalities, tree, model, all_rules, decision_list,
        scalar_state, vector_state, bridge_scalar, bridge_vectorized,
        dense_scalar, dense_vectorized)
end

function _scalar_formula(pool, formula)
    if Aletheia.isatom(formula)
        condition = Aletheia.value(formula)
        if condition isa SoleData.ScalarCondition
            condition = Aletheia.ThresholdCondition(
                SoleData.feature(condition), SoleData.test_operator(condition),
                SoleData.threshold(condition))
        end
        return Aletheia.atom(pool, condition)
    end
    Aletheia.branch(pool, Aletheia.operator(formula),
        (_scalar_formula(pool, child) for child in Aletheia.children(formula))...)
end

function _relation_frames(dataset, formulas)
    signature_connectives = collect(Aletheia.connectives(
        Aletheia.signature(formulas[1])))
    relations = unique([Aletheia.relation(connective)
        for connective in signature_connectives
        if connective isa Union{Aletheia.Diamond,Aletheia.Box}])
    frames = [begin
        source_frame = SoleData.frame(dataset, instance)
        adjacency = Dict(relation => Dict(world => Tuple(SoleData.accessibles(
            source_frame, world, getfield(relation, :source)))
            for world in SoleData.allworlds(source_frame)) for relation in relations)
        Aletheia.Frame(collect(SoleData.allworlds(source_frame)), adjacency; index=true)
    end for instance in 1:SoleData.ninstances(dataset)]
    relations, frames
end

function build_bridge_scalar_layer_state(dataset, callback_state; vectorized)
    # This is the bridge control: it intentionally retains SoleData.checkcondition.
    prepared_source = Aletheia.prepare_scalar(dataset; relation=SoleLogics.globalrel,
        features=collect(SoleData.features(dataset)), precompute_features=true,
        precompute_aggregates=())
    relations, frames = _relation_frames(dataset, callback_state.formulas)
    prepared = Aletheia.prepare_scalar(prepared_source; frames=frames,
        relations=relations, instances=collect(1:SoleData.ninstances(dataset)))
    ScalarLayerState(prepared, callback_state.formulas,
        Aletheia.scalar_family(prepared; vectorized=vectorized))
end

function build_dense_scalar_layer_state(dataset, callback_state; vectorized)
    relations, frames = _relation_frames(dataset, callback_state.formulas)
    source_frame = SoleData.frame(dataset, 1)
    worlds = collect(SoleData.allworlds(source_frame))
    features = collect(SoleData.features(dataset))
    values = Array{Float64}(undef, length(worlds), SoleData.ninstances(dataset), length(features))
    for (iw, world) in enumerate(worlds), instance in 1:SoleData.ninstances(dataset),
        (feature_index, feature) in enumerate(features)
        values[iw, instance, feature_index] = SoleData.featvalue(
            feature, dataset, instance, world)
    end
    store = Aletheia.DenseFeatureStore(values, worlds, features;
        instances=collect(1:SoleData.ninstances(dataset)))
    prepared = Aletheia.prepare_scalar(store; frames=frames, relations=relations,
        precompute_features=true, precompute_aggregates=:all)
    pool = Aletheia.FormulaPool(Aletheia.signature(callback_state.formulas[1]))
    formulas = Any[_scalar_formula(pool, formula) for formula in callback_state.formulas]
    ScalarLayerState(prepared, formulas,
        Aletheia.scalar_family(prepared; vectorized=vectorized))
end

function scalar_layer_apply(state::ScalarLayerState, model)
    extensions = Aletheia.extension(state.formulas, state.family)
    masks = [BitVector(any(values) for values in per_instance) for per_instance in extensions]
    predictions = Vector{Any}(undef, length(masks[1]))
    for instance in eachindex(predictions)
        position = findfirst(mask -> mask[instance], masks)
        chosen = position === nothing ? SoleModels.defaultconsequent(model) :
            SoleModels.consequent(SoleModels.rulebase(model)[position])
        predictions[instance] = SoleModels.outcome(chosen)
    end
    predictions
end

function formula_extensions(fixture, state)
    result = Vector{BitVector}[]
    for (formula, _) in zip(state.formulas, fixture.rules)
        per_instance = BitVector[]
        for instance in 1:SoleData.ninstances(fixture.dataset)
            worlds = collect(SoleData.allworlds(SoleData.frame(fixture.dataset, instance)))
            push!(per_instance, BitVector(Aletheia.check(formula, state.family, instance, world)
                for world in worlds))
        end
        push!(result, per_instance)
    end
    result
end

function native_antecedent_masks(fixture)
    [BitVector(SoleModels.checkantecedent(rule, fixture.modalities))
        for rule in fixture.rules[1:end-1]]
end

function extension_masks(extensions)
    [BitVector(any(values) for values in per_instance) for per_instance in extensions]
end

function run_parity_gate(fixture=build_apply_fixture())
    scalar_extensions = formula_extensions(fixture, fixture.scalar_state)
    vector_extensions = formula_extensions(fixture, fixture.vector_state)
    scalar_masks_from_extensions = extension_masks(scalar_extensions)
    vector_masks_from_extensions = extension_masks(vector_extensions)
    native_masks = native_antecedent_masks(fixture)
    scalar_masks_from_extensions == native_masks || error("scalar formula extension mismatch")
    vector_masks_from_extensions == native_masks || error("vectorized formula extension mismatch")

    scalar_masks = DecisionListBatchAdapter.batch_checkantecedents(fixture.scalar_state)
    vector_masks = DecisionListBatchAdapter.batch_checkantecedents(fixture.vector_state)
    scalar_masks == native_masks || error("scalar antecedent mask mismatch")
    vector_masks == native_masks || error("vectorized antecedent mask mismatch")
    if fixture.bridge_scalar !== nothing
        for state in (fixture.bridge_scalar, fixture.bridge_vectorized)
            extension_masks(formula_extensions(fixture, state)) == native_masks ||
                error("bridge scalar formula extension mismatch")
            scalar_layer_apply(state, fixture.decision_list) ==
                SoleModels.apply(fixture.decision_list, fixture.modalities) ||
                error("bridge scalar prediction mismatch")
        end
        for state in (fixture.dense_scalar, fixture.dense_vectorized)
            extension_masks(formula_extensions(fixture, state)) == native_masks ||
                error("dense scalar formula extension mismatch")
            scalar_layer_apply(state, fixture.decision_list) ==
                SoleModels.apply(fixture.decision_list, fixture.modalities) ||
                error("dense scalar prediction mismatch")
        end
    end

    tree_predictions = ModalDecisionTrees.apply(fixture.tree, fixture.modalities;
        print_progress=false)
    list_predictions = SoleModels.apply(fixture.decision_list, fixture.modalities)
    scalar_predictions = DecisionListBatchAdapter.apply_prepared(
        fixture.scalar_state, fixture.decision_list)
    vector_predictions = DecisionListBatchAdapter.apply_prepared(
        fixture.vector_state, fixture.decision_list)
    tree_predictions == list_predictions || error("tree/list prediction mismatch")
    list_predictions == scalar_predictions || error("scalar prediction mismatch")
    list_predictions == vector_predictions || error("vectorized prediction mismatch")
    (rules=length(fixture.rules), instances=SoleData.ninstances(fixture.dataset),
        extension_cases=sum(length.(scalar_extensions)),
        predictions=length(tree_predictions), world_order=:dataset_frame)
end

function formula_check(fixture, dataset=fixture.dataset)
    total = 0
    for rule in fixture.rules
        formula = first(values(SoleData.modforms(SoleModels.antecedent(rule))))
        for instance in 1:SoleData.ninstances(dataset)
            for world in SoleData.allworlds(SoleData.frame(dataset, instance))
                total += SoleData.check(formula, dataset, instance, world;
                    perform_normalization=false)
            end
        end
    end
    total
end

function supported_cold(fixture)
    support = SoleData.supports(fixture.dataset)[1]
    relations = unique(vcat(collect(support.relations), [SoleLogics.globalrel]))
    cold = SoleData.SupportedLogiset(SoleData.base(fixture.dataset);
        conditions=support.metaconditions, relations=relations,
        onestep_precompute_globmemoset=true,
        onestep_precompute_relmemoset=false)
    formula_check(fixture, cold)
end

function fresh_fixture(base, dataset; scalar_layer=base.bridge_scalar !== nothing)
    modalities = SoleData.MultiLogiset(dataset)
    scalar_state = DecisionListBatchAdapter.prepare(base.decision_list, modalities; vectorized=false)
    vector_state = DecisionListBatchAdapter.prepare(base.decision_list, modalities; vectorized=true)
    bridge_scalar = scalar_layer ? build_bridge_scalar_layer_state(
        dataset, vector_state; vectorized=false) : nothing
    bridge_vectorized = scalar_layer ? build_bridge_scalar_layer_state(
        dataset, vector_state; vectorized=true) : nothing
    dense_scalar = scalar_layer ? build_dense_scalar_layer_state(
        dataset, vector_state; vectorized=false) : nothing
    dense_vectorized = scalar_layer ? build_dense_scalar_layer_state(
        dataset, vector_state; vectorized=true) : nothing
    ApplyFixture(dataset, modalities, base.tree, base.model, base.rules, base.decision_list,
        scalar_state, vector_state, bridge_scalar, bridge_vectorized,
        dense_scalar, dense_vectorized)
end

function churn_fixtures(base; count=6)
    [fresh_fixture(base, make_supported_dataset(APPLY_NINSTANCES, APPLY_NPOINTS))
        for _ in 1:count]
end

function apply_mode(fixture, mode)
    mode === "sole-formula-check" && return formula_check(fixture)
    mode === "supported-cold" && return supported_cold(fixture)
    mode === "supported-warm" && return formula_check(fixture)
    mode === "deployed-modal-tree" && return ModalDecisionTrees.apply(fixture.tree,
        fixture.modalities; print_progress=false)
    mode === "decision-list-apply" && return SoleModels.apply(fixture.decision_list,
        fixture.modalities)
    mode === "aletheia-scalar" && return DecisionListBatchAdapter.apply_prepared(
        fixture.scalar_state, fixture.decision_list)
    mode === "aletheia-vectorized" && return DecisionListBatchAdapter.apply_prepared(
        fixture.vector_state, fixture.decision_list)
    mode === "aletheia-data-bridge-scalar" && return scalar_layer_apply(
        fixture.bridge_scalar, fixture.decision_list)
    mode === "aletheia-data-bridge-vectorized" && return scalar_layer_apply(
        fixture.bridge_vectorized, fixture.decision_list)
    mode === "aletheia-data-scalar" && return scalar_layer_apply(
        fixture.dense_scalar, fixture.decision_list)
    mode === "aletheia-data-vectorized" && return scalar_layer_apply(
        fixture.dense_vectorized, fixture.decision_list)
    error("unknown apply mode $mode")
end

function prepare_mode(fixture, mode)
    mode === "supported-cold" && return SoleData.supports(fixture.dataset)
    mode === "aletheia-scalar" && return DecisionListBatchAdapter.prepare(
        fixture.decision_list, fixture.modalities; vectorized=false)
    mode === "aletheia-vectorized" && return DecisionListBatchAdapter.prepare(
        fixture.decision_list, fixture.modalities; vectorized=true)
    nothing
end
