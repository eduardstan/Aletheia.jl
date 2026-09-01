# AletheiaCore

Syntax and semantic foundations

`AletheiaCore` is the dependency-free foundation of Aletheia. It provides pooled immutable formulas, parsing and printing, truth algebras, relational frames, model evaluation, first-order translation, bisimulation utilities, normal forms, and prover interfaces.

```julia
using AletheiaCore

p = atom("p")
println(syntaxstring(p))
```

The umbrella `Aletheia` package re-exports this API. See the [main documentation](https://eduardstan.github.io/Aletheia.jl/).
