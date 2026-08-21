using BenchmarkTools
using Random
using Statistics
using Aletheia
using SoleData
using SoleLogics
using Graphs

include(joinpath(@__DIR__, "dataset_protocol_shared.jl"))

side = ARGS[1]
for argument in split(ARGS[2], ";")
    ninstances, nworlds, depth, modal_probability, uniform = parse_case(argument)
    dataset = make_dataset(ninstances, nworlds; uniform=uniform)
    formula_a, formula_s = make_pair(depth, modal_probability,
        DATASET_SEED + ninstances * 101 + nworlds * 1009 + depth * 10007)

    if side == "sole"
        f = () -> sum(length(sole_check_all(formula_s, dataset, i)) for i in 1:ninstances)
    elseif side == "aletheia-batch"
        family = SoleDataFamily(dataset; vectorized=true)
        f = () -> sum(length.(Aletheia.extension(formula_a, family)))
    elseif side == "aletheia-scalar"
        family = SoleDataFamily(dataset; vectorized=false)
        f = () -> sum(length.(Aletheia.extension(formula_a, family)))
    else
        error("unknown side $side")
    end
    f()
    measure(f)
end
