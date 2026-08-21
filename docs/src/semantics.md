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

```@example semantics
using Aletheia

for algebra in (BOOLEAN, GodelAlgebra(3), LukasiewiczAlgebra(4))
    println((typeof(algebra), domain(algebra), truth_type(algebra)))
end
```

```text
(BooleanAlgebra, (false, true), Bool)
(GodelAlgebra{3}, (0.0, 0.5, 1.0), Float64)
(LukasiewiczAlgebra{4}, (0.0, 0.3333333333333333, 0.6666666666666666, 1.0), Float64)
```

`meet`, `join`, `implication`, and `negation` are methods on the algebra, not
methods on formulas. This keeps the semantic carrier visible to Julia's type
inference and lets the same model/evaluation API support custom carriers. Atom
values for finite chains are validated at `interpret`, so lazy valuations and
compound formulas follow the same boundary. A value within `8eps(Float64)` of a
finite-chain level is accepted and canonicalized to that level; off-chain values
are rejected.

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

```@example semantics
using Aletheia
sig = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(sig)
p, q = atom(pool, "p"), atom(pool, "q")
formula = branch(pool, ∧, branch(pool, Diamond(:R), p), branch(pool, Box(:R), q))
frame = Frame((:a, :b, :c), Dict(:R => Dict(:a => [:b, :c], :b => [:b], :c => [])); index=true)
model = Model(frame, BOOLEAN, Dict("p" => Set([:b]), "q" => Set([:a, :b])))
println(extension(formula, model))
println(check(formula, model, :a))
```

```text
Extension(Bool[0, 1, 0])
false
```

Diamond is the algebraic join of successor values, so a dead end gives
`bottom`. Box is the algebraic meet, so a dead end gives `top`. In Boolean
models this reproduces the familiar existential/universal clauses; in
many-valued models it is the corresponding algebra fold.

## API boundary

`interpret(atom, model, world)` is intentionally atom-only. Calling it on a
branch is a `MethodError`, which prevents a second, subtly different evaluator
from appearing. Use `check` for a point and `extension` for the whole model.
The result of `extension` is world-index ordered; `world_position` gives the
position used by `check`.

```@docs
TruthAlgebra
BooleanAlgebra
GodelAlgebra
LukasiewiczAlgebra
Frame
Valuation
Model
interpret
check
extension
```
