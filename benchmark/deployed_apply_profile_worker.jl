# One-iteration allocation attribution for the fresh-dataset churn phase.
include(joinpath(@__DIR__, "deployed_apply_common.jl"))
using Profile
const SINK = Ref{Any}(nothing)
function allocation_sample(f)
    GC.gc(); before = Base.gc_num(); SINK[] = f()
    diff = Base.GC_Diff(Base.gc_num(), before)
    (allocs=Int(diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc), bytes=Int(diff.allocd))
end
function emit(mode, step, m)
    println("profile mode=$(mode) step=$(step) allocs=$(m.allocs) bytes=$(m.bytes)")
end
base = build_apply_fixture(train_seed=first(APPLY_SEEDS), scalar_layer=true)
fresh = fresh_fixture(base, make_supported_dataset(APPLY_NINSTANCES, APPLY_NPOINTS; seed=APPLY_DATA_SEED))
run_parity_gate(fresh)
function profile_fresh_apply(mode, base)
    # Compile the profiled call shape first; the recorded run is still a
    # never-used fixture with cold evaluator caches.
    warm_profile_fixture = fresh_fixture(base, make_supported_dataset(
        APPLY_NINSTANCES, APPLY_NPOINTS; seed=APPLY_DATA_SEED))
    Profile.Allocs.@profile sample_rate=1 apply_mode(warm_profile_fixture, mode)
    Profile.Allocs.clear()
    fresh_fixture_value = fresh_fixture(base, make_supported_dataset(
        APPLY_NINSTANCES, APPLY_NPOINTS; seed=APPLY_DATA_SEED))
    Profile.Allocs.@profile sample_rate=1 apply_mode(fresh_fixture_value, mode)
    result = Profile.Allocs.fetch()
    buffer = IOBuffer()
    Profile.Allocs.print(buffer, result; format=:flat, sortedby=:bytes, maxdepth=100, groupby=:line, mincount=1)
    text = String(take!(buffer))
    println("profile-cold mode=$(mode) note=one apply on never-used fresh fixture")
    for line in Iterators.take(split(text, '\n'), 12)
        isempty(strip(line)) || println("profile-site mode=$(mode) $(strip(line))")
    end
    println("profile-top-source mode=$(mode)")
    for line in split(text, '\n')
        source = strip(line)
        (occursin("deployed_apply", source) || occursin("decisionlist", source) ||
            occursin("AletheiaData", source) || occursin("Sole", source) || occursin("scalar.jl", source) ||
            occursin("evaluation.jl", source)) &&
            println("profile-site-source mode=$(mode) $(source)")
    end
end
profile_fresh_apply("aletheia-vectorized", base)
profile_fresh_apply("decision-list-apply", base)
profile_fresh_apply("aletheia-data-vectorized", base)
