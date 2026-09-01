"""Compatibility alias for the installed SoleData extension.

The implementation lives in `lib/AletheiaSole/ext/AletheiaSoleDataExt.jl`; keeping this file as
an alias means the benchmark exercises the package adapter rather than a local
copy.
"""
const SoleDataFamily = Aletheia.SoleDataFamily

function sole_check_all(formula, dataset, i_instance)
    source_worlds = SoleData.allworlds(SoleData.frame(dataset, i_instance))
    BitVector(
        SoleData.check(formula, dataset, i_instance, world; perform_normalization=false)
        for world in source_worlds
    )
end
