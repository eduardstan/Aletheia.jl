using Statistics

"""Sample timing helper with time/allocation pairing."""
struct PairedTimedSample
    time::Float64
    gctime::Float64
    allocs::Int
    memory::Int
end

function paired_timed_sample(f)
    gc_start = Base.gc_num()
    start = time_ns()
    f()
    elapsed = time_ns() - start
    diff = Base.GC_Diff(Base.gc_num(), gc_start)
    allocations = Int(diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc)
    PairedTimedSample(Float64(elapsed), Float64(diff.total_time), allocations, Int(diff.allocd))
end

function paired_measure(f; samples=5, before=nothing)
    observations = PairedTimedSample[]
    for _ in 1:samples
        before === nothing || before()
        push!(observations, paired_timed_sample(f))
    end
    times = getfield.(observations, :time)
    target = median(times)
    observations[argmin(abs.(times .- target))]
end
