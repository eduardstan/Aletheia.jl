using BenchmarkTools
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
    [SoleData.ScalarCondition(
        SoleData.VariableValue(1 + mod(i - 1, 2)),
        OPERATOR_CYCLE[1 + mod(i - 1, length(OPERATOR_CYCLE))],
        0.10 + 0.80 * rand(rng),
    ) for i in 1:12]
end

function consumer_atom(rng, conditions)
    SoleLogics.Atom(rand(rng, conditions))
end

function consumer_core(rng, depth, modal_probability, conditions)
    depth == 0 && return consumer_atom(rng, conditions)
    if rand(rng) < modal_probability
        connective = rand(rng, (SoleLogics.DiamondRelationalConnective(SoleLogics.IA_L),
                                SoleLogics.BoxRelationalConnective(SoleLogics.IA_L)))
        return SoleLogics.SyntaxBranch(connective,
            consumer_core(rng, depth - 1, modal_probability, conditions))
    end
    connective = rand(rng, (SoleLogics.:(∧), SoleLogics.:(∨), SoleLogics.:(→)))
    SoleLogics.SyntaxBranch(connective,
        consumer_core(rng, depth - 1, modal_probability, conditions),
        consumer_core(rng, depth - 1, modal_probability, conditions))
end

function consumer_rules(nrules, depth, modal_probability, shared, seed)
    rng = MersenneTwister(seed)
    conditions = consumer_conditions(rng)
    common = shared ? consumer_core(rng, max(depth - 1, 0), modal_probability, conditions) : nothing
    rules = SoleModels.Rule[]
    for i in 1:nrules
        core = if shared
            tail = consumer_core(rng, max(depth - 1, 0), modal_probability, conditions)
            SoleLogics.SyntaxBranch(SoleLogics.:(∧), common, tail)
        else
            consumer_core(rng, depth, modal_probability, conditions)
        end
        grounded = SoleLogics.SyntaxBranch(
            SoleLogics.DiamondRelationalConnective(SoleLogics.globalrel), core)
        push!(rules, SoleModels.Rule(grounded, i))
    end
    rules
end

function consumer_dataset(ninstances, npoints)
    make_supported_dataset(ninstances, npoints)
end

function evaluate_rules(rules, dataset)
    sum(sum(SoleModels.checkantecedent(rule, dataset)) for rule in rules)
end

struct Measurement
    time::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
end

function measure_warm(f; samples=5)
    f() # compile and warm the consumer path before sampling
    trial = run(@benchmarkable $f() seconds=0.01 samples=samples evals=1)
    median_trial = median(trial)
    Measurement(Float64(median_trial.time), median_trial.allocs, median_trial.memory)
end

function measure_cold(datasets, rules; samples=5)
    cursor = Ref(0)
    next = () -> begin
        cursor[] = 1 + mod(cursor[] , length(datasets))
        evaluate_rules(rules, datasets[cursor[]])
    end
    compile_dataset = datasets[1]
    evaluate_rules(rules, compile_dataset) # compile before timing fresh datasets
    cursor[] = 1
    trial = run(@benchmarkable $next() samples=samples evals=1)
    median_trial = median(trial)
    Measurement(Float64(median_trial.time), median_trial.allocs, median_trial.memory)
end

function measure_adapter(datasets; samples=5)
    cursor = Ref(0)
    next = () -> begin
        cursor[] = 1 + mod(cursor[] , length(datasets))
        SoleModels.stage2_state(datasets[cursor[]])
    end
    compile_dataset = datasets[1]
    SoleModels.stage2_state(compile_dataset) # compile before timing fresh adapter builds
    cursor[] = 0
    trial = run(@benchmarkable $next() seconds=0.01 samples=samples evals=1)
    median_trial = median(trial)
    Measurement(Float64(median_trial.time), median_trial.allocs, median_trial.memory)
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
    trial = run(@benchmarkable $f() seconds=0.01 samples=samples evals=1)
    median_trial = median(trial)
    Measurement(Float64(median_trial.time), median_trial.allocs, median_trial.memory)
end

function measure_extensions(dataset, rules; samples=5)
    state = SoleModels.stage2_state(dataset)
    for rule in rules
        SoleModels._stage2_formula(SoleModels.antecedent(rule), state)
    end
    f = () -> sum(begin
        formula = SoleModels._stage2_formula(SoleModels.antecedent(rule), state)
        sum(BitVector(any(values) for values in Aletheia.extension(formula, state.family)))
    end for rule in rules)
    f()
    trial = run(@benchmarkable $f() seconds=0.01 samples=samples evals=1)
    median_trial = median(trial)
    Measurement(Float64(median_trial.time), median_trial.allocs, median_trial.memory)
end

function parse_gate_shape(s)
    fields = split(s, ':')
    length(fields) == 5 || error("gate shape must be instances:points:depth:modal:shared")
    (parse(Int, fields[1]), parse(Int, fields[2]), parse(Int, fields[3]),
     parse(Float64, fields[4]), parse(Int, fields[5]) == 1)
end

function run_gate(shapes)
    for (case_index, shape) in enumerate(shapes)
        ninstances, npoints, depth, modal_probability, shared = shape
        dataset = consumer_dataset(ninstances, npoints)
        rules = consumer_rules(8, depth, modal_probability, shared,
            CONSUMER_SEED + case_index * 1009)
        for (rule_index, rule) in enumerate(rules)
            mask = SoleModels.checkantecedent(rule, dataset)
            println(case_index, '\t', rule_index, '\t', join(Int.(mask), ','))
        end
    end
end

function parse_case(s)
    fields = split(s, ':')
    length(fields) == 6 || error("case must be instances:points:depth:modal:shared:rules")
    (parse(Int, fields[1]), parse(Int, fields[2]), parse(Int, fields[3]),
     parse(Float64, fields[4]), parse(Int, fields[5]) == 1, parse(Int, fields[6]))
end

# The shared/unshared pair uses one seed; only the construction of the common
# subtree changes.  Other dimensions are part of the seed so each case remains
# independent while the paired comparison is controlled.
function timing_seed(case)
    ninstances, npoints, depth, modal_probability, shared, nrules = case
    CONSUMER_SEED + ninstances * 1009 + npoints * 9176 + depth * 7919 +
        round(Int, 1000 * modal_probability) * 104729 + nrules * 37
end

function emit(m::Measurement)
    m.time === missing ? "NA,NA,NA" : "$(m.time),$(m.allocs),$(m.memory)"
end

function run_timing(cases, side)
    for (case_index, case) in enumerate(cases)
        ninstances, npoints, depth, modal_probability, shared, nrules = case
        dataset = consumer_dataset(ninstances, npoints)
        rules = consumer_rules(nrules, depth, modal_probability, shared,
            timing_seed(case))
        if side == "baseline"
            fresh_datasets = [consumer_dataset(ninstances, npoints) for _ in 1:6]
            cold = measure_cold(fresh_datasets, rules)
            warm = measure_warm(() -> evaluate_rules(rules, dataset))
            println(case_index, '\t', emit(cold), '\t', emit(warm), "\tNA,NA,NA\tNA,NA,NA")
        elseif side == "aletheia"
            fresh_datasets = [consumer_dataset(ninstances, npoints) for _ in 1:6]
            cold = measure_cold(fresh_datasets, rules)
            warm = measure_warm(() -> evaluate_rules(rules, dataset))
            adapter = measure_adapter(fresh_datasets)
            conversion = measure_conversion(dataset, rules)
            extension = measure_extensions(dataset, rules)
            println(case_index, '\t', emit(cold), '\t', emit(warm), '\t',
                emit(adapter), '\t', emit(conversion), '\t', emit(extension))
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
