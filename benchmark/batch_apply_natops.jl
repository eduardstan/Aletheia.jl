# Exactness check for the DecisionList batch adapter on NATOPS.
#
# This is intentionally opt-in because it trains a real ModalDecisionTrees model.
# Run it in a throwaway environment containing Aletheia, SoleData, SoleLogics,
# SoleModels, and ModalDecisionTrees:
#
#     ALETHEIA_BATCH_E2E=1 NATOPS_ARFF_DIR=/path/to/NATOPS \
#       julia --project=/path/to/throwaway-env benchmark/batch_apply_natops.jl
#
# `NATOPS_MAX_INSTANCES` and `NATOPS_MAX_VARIABLES` may be set for a real
# NATOPS slice.  The script still compares every extracted rule with every
# instance in that slice.
if get(ENV, "ALETHEIA_BATCH_E2E", "0") != "1"
    println("SKIP: set ALETHEIA_BATCH_E2E=1 to run the NATOPS batch exactness check")
    exit()
end

using Random
using SoleData
using SoleData.Artifacts: load_arff_dataset
using ModalDecisionTrees
using SoleLogics
using SoleModels

include(joinpath(@__DIR__, "decisionlist_batch_adapter.jl"))
using .DecisionListBatchAdapter

# Reproducibility: the data are fixed, and both the global and learner RNGs
# are explicit.  Keep these values in the PR report with the resulting output.
const GLOBAL_SEED = 0xA1BA7C
const LEARNER_SEED = 1
Random.seed!(GLOBAL_SEED)

natops_dir = get(ENV, "NATOPS_ARFF_DIR", "")
isempty(natops_dir) && error("NATOPS_ARFF_DIR must point to extracted NATOPS ARFF files")
X_train, y_train = load_arff_dataset("NATOPS", :train; path=natops_dir)
max_instances = parse(Int, get(ENV, "NATOPS_MAX_INSTANCES", "0"))
max_variables = parse(Int, get(ENV, "NATOPS_MAX_VARIABLES", "0"))
if max_instances > 0
    selected = unique(
        round.(Int, range(1, size(X_train, 1); length=min(max_instances, size(X_train, 1))))
    )
    X_train = X_train[selected, :]
    y_train = y_train[selected]
end
max_variables > 0 && (X_train = X_train[:, 1:min(max_variables, size(X_train, 2))])
println(
    "NATOPS_INSTANCES=",
    size(X_train, 1),
    " VARIABLES=",
    size(X_train, 2),
    " REDUCED=",
    max_instances > 0 || max_variables > 0,
)

Xs = SoleData.autologiset(
    X_train;
    downsize=SoleData.make_downsizing_function(Val(1)),
    conditions=nothing,
    featvaltype=Float64,
    relations=nothing,
    fixcallablenans=false,
    force_i_variables=false,
    passive_mode=false,
)
Xs = Xs isa Tuple ? first(Xs) : Xs
Xs = Xs isa SoleData.MultiLogiset ? Xs : SoleData.MultiLogiset(Xs)

# ModalDecisionTrees' published NATOPS training shape: min_samples_leaf=4.
tree = ModalDecisionTrees.build_tree(
    Xs,
    String.(y_train);
    min_samples_leaf=4,
    rng=MersenneTwister(LEARNER_SEED),
    print_progress=false,
)
sole_model = ModalDecisionTrees.translate(tree)
rules = SoleModels.listrules(sole_model)
decision_list = SoleModels.DecisionList(
    rules[1:(end - 1)], SoleModels.consequent(rules[end])
)

batch_masks = batch_checkantecedents(rules, Xs)
incumbent_masks = [BitVector(SoleModels.checkantecedent(rule, Xs)) for rule in rules]
comparisons = length(rules) * SoleData.ninstances(Xs)
mismatches = sum(
    batch_masks[rule][instance] != incumbent_masks[rule][instance] for
    rule in eachindex(rules), instance in 1:SoleData.ninstances(Xs)
)
apply_expected = SoleModels.apply(decision_list, Xs)
apply_batch = batch_apply(decision_list, Xs)
apply_mismatches = sum(
    apply_batch[i] != apply_expected[i] for i in eachindex(apply_expected)
)

println("GLOBAL_SEED=", GLOBAL_SEED, " LEARNER_SEED=", LEARNER_SEED)
println("RULES=", length(rules), " RULE_INSTANCE_COMPARISONS=", comparisons)
println("RULE_INSTANCE_MISMATCHES=", mismatches)
println("APPLY_MISMATCHES=", apply_mismatches)
println("ALL_RULES_ALL_INSTANCES_EXACT=", mismatches == 0 && apply_mismatches == 0)
(mismatches == 0 && apply_mismatches == 0) || error("batch verdict mismatch")
