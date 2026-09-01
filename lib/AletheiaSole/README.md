# AletheiaSole

SoleLogics compatibility adapters

`AletheiaSole` is the opt-in migration layer for the SoleLogics ecosystem. It owns the nested `SoleLogics` vocabulary, compatibility formula wrappers, relation aliases, and many-valued adapters.

```julia
using AletheiaSole.SoleLogics

p = atom(:p)
println(p)
```

The umbrella exposes the same module as `Aletheia.SoleLogics`. See the [migration guide](https://eduardstan.github.io/Aletheia.jl/compatibility/).
