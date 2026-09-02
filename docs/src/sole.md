# Compatibility adapter

`AletheiaSole` is the opt-in package for applications that need the
`SoleLogics` vocabulary at Aletheia's boundary. It provides formula wrappers,
leftmost containers, relation aliases, alphabets, random formula helpers, and
many-valued adapters without adding those names to `AletheiaCore`.

The adapter routes semantic work through ordinary pooled Aletheia formulas and
models. Its wrappers are not a second evaluator, and the compatibility package
does not change the pool-local identity contract. Use the [Coming from
SoleLogics](compatibility.md) guide for mappings, deliberate gaps, and consumer
checks.

The focused package can be loaded with:

```julia
using AletheiaSole.SoleLogics
```

Applications using the umbrella can access the same nested module as
`Aletheia.SoleLogics`. The [API reference](api.md) lists the exported adapter
surface.
