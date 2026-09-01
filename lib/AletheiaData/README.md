# AletheiaData

Data and model-family protocols

`AletheiaData` adds model-family and scalar-data protocols on top of `AletheiaCore`. It prepares feature values, caches aggregates, and evaluates scalar conditions without coupling the core to a data-frame package.

```julia
using AletheiaData

# Prepare scalar data with a dataset implementing the documented protocol.
# prepared = prepare_scalar(dataset; frames=[frame])
```

For optional SoleData integration, use `AletheiaSole` and its extension. See the [main documentation](https://eduardstan.github.io/Aletheia.jl/).
