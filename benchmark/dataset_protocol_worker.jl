using BenchmarkTools
using Random
using Statistics
using Aletheia
using SoleData
using SoleLogics
using Graphs

include(joinpath(@__DIR__, "dataset_protocol_shared.jl"))

function measure_supported_cold(base, conditions, relations, formula_s, ninstances)
    supported = Ref{Any}()
    setup =
        () -> (
            supported[] = SoleData.SupportedLogiset(
                base;
                conditions=conditions,
                relations=relations,
                onestep_precompute_globmemoset=true,
                onestep_precompute_relmemoset=false,
            )
        )
    f = () -> sum(length(sole_check_all(formula_s, supported[], i)) for i in 1:ninstances)
    setup()
    m = paired_measure(f; samples=5, before=setup)
    return println(m.time, " ", m.allocs, " ", m.memory)
end

side = ARGS[1]
for argument in split(ARGS[2], ";")
    ninstances, nworlds, depth, modal_probability, uniform = parse_case(argument)
    supported = startswith(side, "supported-")
    dataset = if supported
        make_supported_dataset(ninstances, nworlds)
    else
        make_dataset(ninstances, nworlds; uniform=uniform)
    end
    formula_a, formula_s = make_pair(
        depth,
        modal_probability,
        DATASET_SEED + ninstances * 101 + nworlds * 1009 + depth * 10007;
        supported=supported,
    )

    if side == "sole"
        f = () -> sum(length(sole_check_all(formula_s, dataset, i)) for i in 1:ninstances)
    elseif side == "aletheia-batch"
        family = SoleDataFamily(dataset; vectorized=true)
        f = () -> sum(length.(Aletheia.extension(formula_a, family)))
    elseif side == "aletheia-scalar"
        family = SoleDataFamily(dataset; vectorized=false)
        f = () -> sum(length.(Aletheia.extension(formula_a, family)))
    elseif side == "supported-cold"
        support = SoleData.supports(dataset)[1]
        measure_supported_cold(
            SoleData.base(dataset),
            support.metaconditions,
            support.relations,
            formula_s,
            ninstances,
        )
        continue
    elseif side == "supported-warm"
        f = () -> sum(length(sole_check_all(formula_s, dataset, i)) for i in 1:ninstances)
        f()
    elseif side == "supported-aletheia-batch"
        family = SoleDataFamily(dataset; vectorized=true, relation=SoleLogics.IA_L)
        f = () -> sum(length.(Aletheia.extension(formula_a, family)))
    elseif side == "supported-aletheia-scalar"
        family = SoleDataFamily(dataset; vectorized=false, relation=SoleLogics.IA_L)
        f = () -> sum(length.(Aletheia.extension(formula_a, family)))
    else
        error("unknown side $side")
    end
    f()
    measure(f)
end
