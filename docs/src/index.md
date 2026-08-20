# Aletheia.jl

Aletheia is a syntax-first foundation for propositional, modal,
many-valued, and first-order logic. Its first layer defines Blackburn-style
similarity types, immutable hash-consed formulas, extensible connective
traits, precedence-aware parsing and printing, truth algebras, relational
frames, models, and atom interpretation. Compound-formula evaluation is
left to a later stage.

Its design is grounded in five references:

- Blackburn, de Rijke, and Venema, *Modal Logic* [blackburn2001](@cite).
- Goranko, *Logic as a Tool: A Guide to Formal Logical Reasoning* [goranko2016](@cite).
- Schwarz, *Logic 2: Modal Logic* [schwarz2024](@cite).
- Muggleton and De Raedt, “Inductive Logic Programming: Theory and Methods” [muggleton1994](@cite).
- Železný and Lavrač (eds), *Inductive Logic Programming: 18th International Conference, ILP 2008* [zelezny2008](@cite).

The references are provided for scholarly grounding; their source PDFs are not
redistributed with this package.

## Semantic API

Truth values are carried by [`TruthAlgebra`](@ref) rather than by syntax.  The
built-in [`BooleanAlgebra`](@ref), [`GodelAlgebra`](@ref), and
[`LukasiewiczAlgebra`](@ref) implement the same `top`, `bottom`, `meet`,
`join`, `implication`, and `negation` interface.  A [`Frame`](@ref) stores
stable worlds and named accessibility relations; [`Model`](@ref) adds a
valuation and an algebra.  [`interpret`](@ref) intentionally has an atom-only
surface.  Compound formulas will consume the syntax DAG in the next stage.

```julia
pool = FormulaPool(Signature((¬, ∧)))
p = atom(pool, "p")
frame = Frame((:only,); index=true)
boolean = Model(frame, BooleanAlgebra(), Dict("p" => Set([:only])))
gödel = Model(frame, GodelAlgebra(), Dict("p" => Dict(:only => 0.5)))
interpret(p, boolean, :only) # true
interpret(p, gödel, :only)   # 0.5
```

## Module

```@docs
Aletheia
```

## Syntax API

```@autodocs
Modules = [Aletheia]
Order = [:type, :function, :constant]
```

## References

```@bibliography
```
