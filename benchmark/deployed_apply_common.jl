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

struct ApplyFixture
    dataset::Any
    modalities::Any
    tree::Any
    model::Any
    rules::Any
    decision_list::Any
    scalar_state::Any
    vector_state::Any
end

function build_apply_fixture(; ninstances=APPLY_NINSTANCES, npoints=APPLY_NPOINTS,
        train_seed=APPLY_TRAIN_SEED)
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
    ApplyFixture(dataset, modalities, tree, model, all_rules, decision_list,
        scalar_state, vector_state)
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
