# Scale-sweep child for the deployed decision-list apply comparison.
include(joinpath(@__DIR__, "deployed_apply_common.jl"))

const SINK = Ref{Any}(nothing)
struct TimedSample
    time::Float64
    allocs::Int
    bytes::Int
end
function timed_sample(f)
    gc_before = Base.gc_num(); t0 = time_ns(); SINK[] = f()
    elapsed = time_ns() - t0
    diff = Base.GC_Diff(Base.gc_num(), gc_before)
    TimedSample(Float64(elapsed), Int(diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc), Int(diff.allocd))
end
function measure(f; warm=true, samples=3)
    warm && (SINK[] = f())
    observations = [timed_sample(f) for _ in 1:samples]
    times = getfield.(observations, :time)
    sample = observations[argmin(abs.(times .- median(times)))]
    (sample=sample, minimum=minimum(times), maximum=maximum(times), samples=samples)
end
function emit(mode, phase, seed, ninstances, npoints, m)
    s = m.sample
    println("scale-result seed=$(seed) instances=$(ninstances) points=$(npoints) mode=$(mode) phase=$(phase) " *
        "time_ns=$(s.time) allocs=$(s.allocs) bytes=$(s.bytes) minimum_ns=$(m.minimum) " *
        "maximum_ns=$(m.maximum) samples=$(m.samples)")
end

length(ARGS) == 2 || error("usage: deployed_apply_scale_worker.jl INSTANCES POINTS")
ninstances, npoints = parse.(Int, ARGS)
for seed in APPLY_SEEDS
    base = build_apply_fixture(train_seed=seed)
    scale_fixture = fresh_fixture(base, make_supported_dataset(ninstances, npoints; seed=APPLY_DATA_SEED))
    gate = run_parity_gate(scale_fixture)
    println("scale-parity=PASS seed=$(seed) instances=$(ninstances) points=$(npoints) " *
        "rules=$(gate.rules) extension_cases=$(gate.extension_cases)")
    for mode in ("decision-list-apply", "aletheia-scalar", "aletheia-vectorized")
        apply_mode(scale_fixture, mode)
        first_fixture = fresh_fixture(base, make_supported_dataset(ninstances, npoints; seed=APPLY_DATA_SEED))
        first = measure(() -> apply_mode(first_fixture, mode); warm=false)
        emit(mode, "first-use", seed, ninstances, npoints, first)
        warm = measure(() -> apply_mode(scale_fixture, mode))
        emit(mode, "warm-reuse", seed, ninstances, npoints, warm)
        churn = [fresh_fixture(base, make_supported_dataset(ninstances, npoints; seed=APPLY_DATA_SEED)) for _ in 1:6]
        cursor = Ref(0)
        churn_measurement = measure(; warm=false, samples=length(churn)) do
            cursor[] += 1
            apply_mode(churn[cursor[]], mode)
        end
        emit(mode, "fresh-dataset-churn", seed, ninstances, npoints, churn_measurement)
    end
end
