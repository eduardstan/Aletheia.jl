using Random
using Statistics
using Aletheia
using SoleData
using SoleLogics
using SoleModels
using DataFrames
using Graphs

include(joinpath(@__DIR__, "dataset_protocol_shared.jl"))

const CONSUMER_SEED = 0xDADA_2024
const OPERATOR_CYCLE = (>, <, >=, <=)

function consumer_conditions(rng)
    return [
        SoleData.ScalarCondition(
            SoleData.VariableValue(1 + mod(i - 1, 2)),
            OPERATOR_CYCLE[1 + mod(i - 1, length(OPERATOR_CYCLE))],
            0.10 + 0.80 * rand(rng),
        ) for i in 1:12
    ]
end

function consumer_atom(rng, conditions)
    return SoleLogics.Atom(rand(rng, conditions))
end

function consumer_core(rng, depth, modal_probability, conditions)
    depth == 0 && return consumer_atom(rng, conditions)
    if rand(rng) < modal_probability
        connective = rand(
            rng,
            (
                SoleLogics.DiamondRelationalConnective(SoleLogics.IA_L),
                SoleLogics.BoxRelationalConnective(SoleLogics.IA_L),
            ),
        )
        return SoleLogics.SyntaxBranch(
            connective, consumer_core(rng, depth - 1, modal_probability, conditions)
        )
    end
    connective = rand(rng, (SoleLogics.:(∧), SoleLogics.:(∨), SoleLogics.:(→)))
    return SoleLogics.SyntaxBranch(
        connective,
        consumer_core(rng, depth - 1, modal_probability, conditions),
        consumer_core(rng, depth - 1, modal_probability, conditions),
    )
end

function consumer_rules(nrules, depth, modal_probability, shared, seed)
    rng = MersenneTwister(seed)
    conditions = consumer_conditions(rng)
    common = if shared
        consumer_core(rng, max(depth - 1, 0), modal_probability, conditions)
    else
        nothing
    end
    rules = SoleModels.Rule[]
    for i in 1:nrules
        core = if shared
            tail = consumer_core(rng, max(depth - 1, 0), modal_probability, conditions)
            SoleLogics.SyntaxBranch(SoleLogics.:(∧), common, tail)
        else
            consumer_core(rng, depth, modal_probability, conditions)
        end
        grounded = SoleLogics.SyntaxBranch(
            SoleLogics.DiamondRelationalConnective(SoleLogics.globalrel), core
        )
        push!(rules, SoleModels.Rule(grounded, i))
    end
    return rules
end

function consumer_dataset(ninstances, npoints)
    return make_supported_dataset(ninstances, npoints)
end

function evaluate_rules(rules, dataset)
    return sum(sum(SoleModels.checkantecedent(rule, dataset)) for rule in rules)
end

struct TimedSample
    time::Float64
    gctime::Float64
    allocs::Int
    memory::Int
end

struct Measurement
    time::Union{Missing,Float64}
    gctime::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
    minimum::Union{Missing,Float64}
    maximum::Union{Missing,Float64}
    max_gctime::Union{Missing,Float64}
    samples::Int
end
function Measurement(::Missing, ::Missing, ::Missing)
    return Measurement(missing, missing, missing, missing, missing, missing, missing, 0)
end

function timed_sample(f)
    gc_start = Base.gc_num()
    start = time_ns()
    f()
    elapsed = time_ns() - start
    diff = Base.GC_Diff(Base.gc_num(), gc_start)
    allocations = Int(diff.malloc + diff.realloc + diff.poolalloc + diff.bigalloc)
    return TimedSample(
        Float64(elapsed), Float64(diff.total_time), allocations, Int(diff.allocd)
    )
end

# BenchmarkTools stores allocations as a minimum over its samples.  Select the
# sample nearest the median time instead, so the allocation and GC figures below
# describe the timing figure printed beside them.
function measure_samples(f; samples=5)
    measurements = [timed_sample(f) for _ in 1:samples]
    times = getfield.(measurements, :time)
    median_time = median(times)
    paired = measurements[argmin(abs.(times .- median_time))]
    return Measurement(
        paired.time,
        paired.gctime,
        paired.allocs,
        paired.memory,
        minimum(times),
        maximum(times),
        maximum(getfield.(measurements, :gctime)),
        samples,
    )
end

function measure_warm(f; samples=5)
    f() # compile and warm the consumer path before sampling
    return measure_samples(f; samples=samples)
end

function measure_first_use(datasets, rules; samples=5)
    length(datasets) >= samples + 1 ||
        error("first-use measurement needs one compile dataset and samples fresh datasets")
    evaluate_rules(rules, datasets[1]) # compile before timing fresh datasets
    cursor = Ref(0)
    first_index = length(datasets) - samples + 1
    return measure_samples(
        () -> begin
            cursor[] += 1
            evaluate_rules(rules, datasets[first_index + cursor[] - 1])
        end;
        samples=samples,
    )
end

function measure_churn(datasets, rules)
    length(datasets) >= 2 || error("churn measurement needs fresh datasets")
    evaluate_rules(rules, datasets[1]) # compile before timing fresh datasets
    cursor = Ref(0)
    return measure_samples(
        () -> begin
            cursor[] += 1
            evaluate_rules(rules, datasets[1 + cursor[]])
        end;
        samples=length(datasets) - 1,
    )
end

function measure_adapter(datasets; samples=5)
    length(datasets) >= samples + 1 || error("adapter measurement needs fresh datasets")
    SoleModels.stage2_state(datasets[1]) # compile before timing fresh adapter builds
    cursor = Ref(0)
    return measure_samples(
        () -> begin
            cursor[] += 1
            SoleModels.stage2_state(datasets[cursor[] + 1])
        end; samples=samples
    )
end

function measure_conversion(dataset, rules; samples=5)
    state = SoleModels.stage2_state(dataset)
    f = () -> begin
        empty!(state.formulas)
        for rule in rules
            SoleModels._stage2_formula(SoleModels.antecedent(rule), state)
        end
        length(state.formulas)
    end
    f()
    return measure_samples(f; samples=samples)
end

function measure_extensions(dataset, rules; samples=5)
    state = SoleModels.stage2_state(dataset)
    for rule in rules
        SoleModels._stage2_formula(SoleModels.antecedent(rule), state)
    end
    f =
        () -> sum(
            begin
                formula = SoleModels._stage2_formula(SoleModels.antecedent(rule), state)
                sum(
                    BitVector(
                        any(values) for values in Aletheia.extension(formula, state.family)
                    ),
                )
            end for rule in rules
        )
    f()
    return measure_samples(f; samples=samples)
end

function parse_gate_shape(s)
    fields = split(s, ':')
    length(fields) == 5 || error("gate shape must be instances:points:depth:modal:shared")
    return (
        parse(Int, fields[1]),
        parse(Int, fields[2]),
        parse(Int, fields[3]),
        parse(Float64, fields[4]),
        parse(Int, fields[5]) == 1,
    )
end

function run_gate(shapes)
    for (case_index, shape) in enumerate(shapes)
        ninstances, npoints, depth, modal_probability, shared = shape
        dataset = consumer_dataset(ninstances, npoints)
        rules = consumer_rules(
            8, depth, modal_probability, shared, CONSUMER_SEED + case_index * 1009
        )
        for (rule_index, rule) in enumerate(rules)
            mask = SoleModels.checkantecedent(rule, dataset)
            println(case_index, '\t', rule_index, '\t', join(Int.(mask), ','))
        end
    end
end

function parse_case(s)
    fields = split(s, ':')
    length(fields) == 6 || error("case must be instances:points:depth:modal:shared:rules")
    return (
        parse(Int, fields[1]),
        parse(Int, fields[2]),
        parse(Int, fields[3]),
        parse(Float64, fields[4]),
        parse(Int, fields[5]) == 1,
        parse(Int, fields[6]),
    )
end

# The shared/unshared pair uses one seed; only the construction of the common
# subtree changes.  Other dimensions are part of the seed so each case remains
# independent while the paired comparison is controlled.
function timing_seed(case)
    ninstances, npoints, depth, modal_probability, shared, nrules = case
    return CONSUMER_SEED +
           ninstances * 1009 +
           npoints * 9176 +
           depth * 7919 +
           round(Int, 1000 * modal_probability) * 104729 +
           nrules * 37
end

function emit(m::Measurement)
    return if m.time === missing
        "NA,NA,NA,NA,NA,NA,NA,0"
    else
        "$(m.time),$(m.gctime),$(m.allocs),$(m.memory),$(m.minimum),$(m.maximum),$(m.max_gctime),$(m.samples)"
    end
end

function run_timing(cases, side)
    for (case_index, case) in enumerate(cases)
        ninstances, npoints, depth, modal_probability, shared, nrules = case
        dataset = consumer_dataset(ninstances, npoints)
        rules = consumer_rules(nrules, depth, modal_probability, shared, timing_seed(case))
        fresh_datasets = [consumer_dataset(ninstances, npoints) for _ in 1:6]
        # Six fresh identities reproduce the workload that exposed collection
        # pressure without letting one row consume the worker timeout.
        churn_datasets = [consumer_dataset(ninstances, npoints) for _ in 1:7]
        first_use = measure_first_use(fresh_datasets, rules)
        steady = measure_warm(() -> evaluate_rules(rules, dataset))
        churn = measure_churn(churn_datasets, rules)
        if side == "baseline"
            println(
                case_index,
                '\t',
                emit(first_use),
                '\t',
                emit(steady),
                '\t',
                emit(churn),
                "\tNA,NA,NA,NA,NA,NA,NA,0\tNA,NA,NA,NA,NA,NA,NA,0",
            )
        elseif side == "aletheia"
            adapter = measure_adapter(fresh_datasets)
            conversion = measure_conversion(dataset, rules)
            extension = measure_extensions(dataset, rules)
            println(
                case_index,
                '\t',
                emit(first_use),
                '\t',
                emit(steady),
                '\t',
                emit(churn),
                '\t',
                emit(adapter),
                '\t',
                emit(conversion),
                '\t',
                emit(extension),
            )
        else
            error("unknown side $side")
        end
    end
end

mode = ARGS[1]
if mode == "gate"
    run_gate(parse_gate_shape.(split(ARGS[2], ';')))
elseif mode == "timing"
    side = ARGS[2]
    run_timing(parse_case.(split(ARGS[3], ';')), side)
else
    error("mode must be gate or timing")
end
