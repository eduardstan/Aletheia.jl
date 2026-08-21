# Aletheia.jl

Aletheia is a syntax-first foundation for propositional, modal,
many-valued, and first-order logic. Its first layer defines Blackburn-style
similarity types, immutable hash-consed formulas, extensible connective
traits, precedence-aware parsing and printing, truth algebras, relational
frames, models, and atom interpretation. Compound formulas are evaluated
bottom-up over their interned syntax DAG.

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
surface.  [`check`](@ref) and [`extension`](@ref) consume the syntax DAG
with one bottom-up evaluation path.

```julia
pool = FormulaPool(Signature((¬, ∧)))
p = atom(pool, "p")
frame = Frame((:only,); index=true)
boolean = Model(frame, BooleanAlgebra(), Dict("p" => Set([:only])))
gödel = Model(frame, GodelAlgebra(), Dict("p" => Dict(:only => 0.5)))
interpret(p, boolean, :only) # true
interpret(p, gödel, :only)   # 0.5
check(p, boolean, :only)      # true
extension(p, boolean)          # BitVector([1])
```

## Relation families and generated frames

Relations are immutable values carried by `Diamond` and `Box`; a relation family
never requires a new frame type. `BEFORE`, `MEETS`, `OVERLAPS`, `STARTS`,
`DURING`, `FINISHES`, `EQUALS` and their six converses implement Allen's
thirteen basic interval relations. `relation_holds(r, source, target)` uses the
usual subject/object orientation: for example, `STARTS` means that `source`
has the same left endpoint as `target` and a smaller right endpoint, while
`BEFORE` means `source.y < target.x`. The `IA_*` spellings are compatibility
aliases for Sole's accessibility orientation (`IA_B` is `STARTED_BY`, for
example). `RCC8_RELATIONS` includes the formal eighth `RCC_EQ`; the
seven-relation incumbent list is available as `RCC8_BASICS`. RCC8 is the selected
fragment because it is the incumbent's complete topological implementation; RCC5
composition is intentionally left for a later stage.

`interval_frame(n)` generates all intervals over `n` cells and
`rectangle_frame(nx, ny)` generates all axis-aligned rectangles. Their worlds
are immutable values, and both are ordinary [`Frame`](@ref) instances, so the
existing adjacency cache and evaluator are used unchanged. Generated frames use
the optional `relation_successors(relation, source, worlds)` protocol when a
family can enumerate successors arithmetically; it returns `nothing` by default,
so an external family only needs `relation_holds` and automatically uses the
generic filtering fallback:

```julia
sig = Signature((Diamond(BEFORE), Box(BEFORE)))
pool = FormulaPool(sig)
p = atom(pool, "p")
frame = interval_frame(4)
model = Model(frame, BOOLEAN, Dict("p" => Set([Interval(2, 3)])))
check(branch(pool, Diamond(BEFORE), p), model, Interval(1, 2))
```

A new family can be defined outside Aletheia by extending the single protocol
method, without adding a frame×family file:

```julia
struct SameParity end
Aletheia.relation_holds(::SameParity, a::Int, b::Int) = iseven(a) == iseven(b)
frame = point_frame(1:4)
```

## Frame classes and correspondence

`isreflexive`, `istransitive`, `issymmetric`, and `isserial` are finite-frame
traits. `satisfies(frame, T, relation)` and the corresponding `S4`/`S5` checks
compose these traits; `K` imposes no frame condition. The correspondence
schemas are `T`: `□p → p`, `4`: `□p → □□p`, `B`: `p → □◇p`, and `D`:
`□p → ◇p`. These correspondences and the named systems follow Blackburn,
de Rijke, and Venema, Chapter 3 [blackburn2001](@cite), and Schwarz's modal
logic notes [schwarz2024](@cite). `axioms(pool, S4)` and
`axioms(pool, S5)` expose the individual schemas; `axiom` conjoins them when
the signature contains `∧`.

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
