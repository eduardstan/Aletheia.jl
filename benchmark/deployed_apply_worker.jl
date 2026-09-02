# Timed child for deployed apply rows.  All output is redirected by the parent.
include(joinpath(@__DIR__, "deployed_apply_common.jl"))

const SINK = Ref{Any}(nothing)
struct TimedSample
    time::Float64
    allocs::Int
    bytes::Int
end

function timed_sample(f)
    gc_before = Base.gc_num()
    t0 = time_ns()
    SINK[] = f()
    elapsed = time_ns() - t0
    diff = Base.GC_Diff(Base.gc_num(), gc_before)
    TimedSample(Float64(elapsed), Int(diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc),
        Int(diff.allocd))
end

function measure(f; warm=true, samples=5)
    warm && (SINK[] = f())
    sampleset = [timed_sample(f) for _ in 1:samples]
    times = getfield.(sampleset, :time)
    sample = sampleset[argmin(abs.(times .- median(times)))]
    (sample=sample, minimum=minimum(times), maximum=maximum(times), samples=samples)
end

function emit(mode, phase, measured; seed=missing)
    s = measured.sample
    println("result seed=$(seed) mode=$(mode) phase=$(phase) time_ns=$(s.time) allocs=$(s.allocs) bytes=$(s.bytes) " *
        "minimum_ns=$(measured.minimum) maximum_ns=$(measured.maximum) samples=$(measured.samples)")
end

mode = ARGS[1]
for seed in APPLY_SEEDS
    base = build_apply_fixture(train_seed=seed)
    gate = run_parity_gate(base)
    println("parity=PASS seed=$(seed) rules=$(gate.rules) instances=$(gate.instances) " *
        "extension_cases=$(gate.extension_cases) predictions=$(gate.predictions)")
    # Rebuild after the gate so cache state is explicit for the timed fixture.
    fixture = build_apply_fixture(train_seed=seed)

    if mode === "supported-construction"
        support = SoleData.supports(fixture.dataset)[1]
        relations = unique(vcat(collect(support.relations), [SoleLogics.globalrel]))
        m = measure(; warm=false) do
            SoleData.SupportedLogiset(SoleData.base(fixture.dataset);
                conditions=support.metaconditions, relations=relations,
                onestep_precompute_globmemoset=true,
                onestep_precompute_relmemoset=false)
        end
        emit(mode, "construction", m; seed=seed)
    elseif mode === "aletheia-scalar-construction" || mode === "aletheia-vectorized-construction"
        vectorized = mode === "aletheia-vectorized-construction"
        m = measure(; warm=false) do
            DecisionListBatchAdapter.prepare(fixture.decision_list, fixture.modalities;
                vectorized=vectorized)
        end
        emit(mode, "construction", m; seed=seed)
    else
        # Compile on the benchmark fixture, then exercise an unseen data identity.
        apply_mode(fixture, mode)
        unseen = fresh_fixture(fixture, make_supported_dataset(APPLY_NINSTANCES, APPLY_NPOINTS))
        first_measurement = measure(() -> apply_mode(unseen, mode); warm=false)
        emit(mode, mode === "supported-cold" ? "cold-construction-first-use" : "first-use",
            first_measurement; seed=seed)
        if mode !== "supported-cold"
            warm = measure(() -> apply_mode(fixture, mode))
            emit(mode, "warm-reuse", warm; seed=seed)
        end
        # Dataset identities are new, but family/model conversion is outside this
        # apply closure. This is the fresh-dataset churn quantity.
        churn = churn_fixtures(fixture)
        cursor = Ref(0)
        churn_measurement = measure(; warm=false, samples=length(churn)) do
            cursor[] += 1
            apply_mode(churn[cursor[]], mode)
        end
        emit(mode, "fresh-dataset-churn", churn_measurement; seed=seed)
    end
end
