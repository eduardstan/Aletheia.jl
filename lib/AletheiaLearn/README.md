# AletheiaLearn

Inductive logic programming foundations

`AletheiaLearn` provides clauses, substitutions, θ-subsumption, lazy refinement operators, learning-setting examples, and hypothesis scoring. It depends only on `AletheiaCore`.

```julia
using AletheiaCore
using AletheiaLearn

clause = Clause((literal(Predicate(:p, (Variable(:x),))),))
println(ishorn(clause))
```

`Aletheia` re-exports the learning API. See the [main documentation](https://eduardstan.github.io/Aletheia.jl/).
