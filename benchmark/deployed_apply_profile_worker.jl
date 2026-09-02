# One-iteration allocation attribution for the fresh-dataset churn phase.
include(joinpath(@__DIR__, "deployed_apply_common.jl"))
const SINK = Ref{Any}(nothing)
function allocation_sample(f)
    GC.gc(); before = Base.gc_num(); SINK[] = f()
    diff = Base.GC_Diff(Base.gc_num(), before)
    (allocs=Int(diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc), bytes=Int(diff.allocd))
end
function emit(mode, step, m)
    println("profile mode=$(mode) step=$(step) allocs=$(m.allocs) bytes=$(m.bytes)")
end
base = build_apply_fixture(train_seed=first(APPLY_SEEDS))
fresh = fresh_fixture(base, make_supported_dataset(APPLY_NINSTANCES, APPLY_NPOINTS))
run_parity_gate(fresh)
scalar_state = fresh.scalar_state
vector_state = fresh.vector_state
# Warm compilation, then profile the same prepared fresh-dataset operation.
DecisionListBatchAdapter.apply_prepared(vector_state, fresh.decision_list)
DecisionListBatchAdapter.apply_prepared(scalar_state, fresh.decision_list)
vector_extensions = Aletheia.extension(vector_state.formulas, vector_state.family)
vector_masks = [BitVector(any(values) for values in per_instance) for per_instance in vector_extensions]
for (step, f) in (("extension-only", () -> Aletheia.extension(vector_state.formulas, vector_state.family)),
                  ("mask-fold-only", () -> [BitVector(any(values) for values in per_instance)
                      for per_instance in vector_extensions]),
                  ("prediction-fold-only", () -> [findfirst(mask -> mask[i], vector_masks)
                      for i in 1:vector_state.ninstances]),
                  ("full-apply", () -> DecisionListBatchAdapter.apply_prepared(
                      vector_state, fresh.decision_list)))
    emit("aletheia-vectorized", step, allocation_sample(f))
end
rules = fresh.rules[1:end-1]
for (index, rule) in enumerate(rules)
    emit("sole-decision-list", "checkantecedent-$index",
        allocation_sample(() -> SoleModels.checkantecedent(rule, fresh.modalities)))
end
emit("sole-decision-list", "full-apply",
    allocation_sample(() -> SoleModels.apply(fresh.decision_list, fresh.modalities)))
println("profile-note=eager dense feature materialization is outside this prepared apply iteration; callback uses SoleData.checkcondition")
