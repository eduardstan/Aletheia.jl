# Semantics and evaluation

```@meta
CurrentModule = Aletheia
```

## Truth algebras

[`TruthAlgebra`](@ref) is the semantic protocol. The built-ins are
[`BooleanAlgebra`](@ref), [`GodelAlgebra`](@ref), and
[`LukasiewiczAlgebra`](@ref); `BOOLEAN` is the Boolean singleton. A chain's
carrier is `Float64`, while its algebra type records whether it is the unit
interval or a finite chain.

```jldoctest semantics
using Aletheia

for algebra in (BOOLEAN, GodelAlgebra(3), LukasiewiczAlgebra(4))
    show(stdout, MIME"text/plain"(), algebra)
    println()
end

# output

BooleanAlgebra (carrier Bool: {false, true})
GodelAlgebra{3} (chain of 3 levels: 0.0, 0.5, 1.0)
LukasiewiczAlgebra{4} (chain of 4 levels: 0.0, 0.333, 0.667, 1.0)
```

`meet`, `join`, `implication`, and `negation` are methods on the algebra, not
methods on formulas. This keeps the semantic carrier visible to Julia's type
inference and lets the same model/evaluation API support custom carriers. Atom
values for finite chains are validated at `interpret`, so lazy valuations and
compound formulas follow the same boundary. Finite chain levels are stored as
`Float64`, so a value computed as `1/3` may not be bit-identical to the stored
level. A value within `8eps(Float64)` of a level is therefore accepted and
snapped to it; anything further off-chain is rejected rather than silently
rounded.

## Frames, valuations, models

A [`Frame`](@ref) stores an ordered nonempty tuple of worlds and one or more
named accessibility relations. Accessibility is lazy: `accessible(frame, w,
r)` returns an iterator, and `collect` is an explicit request for storage.
Relations may be maps, edge lists, adjacency functions, or a callable frame.
A [`Valuation`](@ref) accepts the common atom-to-set form as well as callable
and dictionary forms. A [`Model`](@ref) combines a frame, valuation, and
algebra.

The model is the semantic object corresponding to a Kripke interpretation: a
frame plus contingent atom information. See Blackburn et al., §1.3 (pp. 16–20)
[blackburn2001; §1.3, pp. 16–20](@cite).

## One evaluation path

`check(φ, model, world)` and `extension(φ, model)` share one bottom-up walk over
the reachable interned DAG. A repeated subformula is evaluated once. Boolean
models use specialized bit operations; all other algebras use typed vectors,
but both paths apply the same connective and relation semantics.

```jldoctest semantics2
using Aletheia
sig = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(sig)
p, q = atom(pool, "p"), atom(pool, "q")
formula = branch(pool, ∧, branch(pool, Diamond(:R), p), branch(pool, Box(:R), q))
base_frame = Frame((:a, :b, :c), Dict(:R => Dict(:a => [:b, :c], :b => [:b], :c => [])); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([:b]), "q" => Set([:a, :b])))
describe(stdout, extension(formula, model), model)
println()
println(check(formula, model, :a))

# output

Extension (1 of 3 worlds satisfy)
  Satisfied at: :b
  Unsatisfied at: :a, :c
false
```

Diamond is the algebraic join of successor values, so a dead end gives
`bottom`. Box is the algebraic meet, so a dead end gives `top`. In Boolean
models this reproduces the familiar existential/universal clauses; in
many-valued models it is the corresponding algebra fold.

## API boundary

`interpret(atom, model, world)` is intentionally atom-only. Calling it on a
branch is a `MethodError`. Compound formulas go through `check` (one world) or
`extension` (every world), so there is exactly one evaluation path.
The result of `extension` is world-index ordered; `world_position` gives the
position used by `check`.
