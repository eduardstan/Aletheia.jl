# Theory utilities

```@meta
CurrentModule = Aletheia
```


Aletheia's theory layer keeps the interned modal formula as the source object
and exposes small, testable boundaries rather than claiming a general prover.

## Standard translation

[`standard_translation`](@ref) maps built-in modal syntax to a compact
first-order syntax with variables, predicates, equality, Boolean connectives,
and quantifiers. `first_order_interpretation` turns a Boolean Aletheia model
into the corresponding first-order interpretation. The bridge is the standard
translation in Blackburn et al., §2.4 (Definitions 2.44–2.45 and Proposition
2.47, pp. 83–86) [blackburn2001; §2.4, Definitions 2.44–2.45 and Proposition 2.47, pp. 83–86](@cite).
The first-order syntax and evaluator are a reference semantics, not a prover;
Goranko, §§3.1–3.4 (pp. 97–145), gives the corresponding syntax, assignment,
and validity vocabulary [goranko2016; §§3.1–3.4, pp. 97–145](@cite).

```@example theory
using Aletheia
sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(sig)
p, q = atom(pool, "p"), atom(pool, "q")
formula = branch(pool, ∧, branch(pool, Diamond(:R), p), branch(pool, Box(:R), branch(pool, →, p, q)))
frame = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [2])); index=true)
model = Model(frame, BOOLEAN, Dict("p" => Set([1]), "q" => Set([2])))
translation = standard_translation(formula)
first_order = first_order_interpretation(model)
println(all(evaluate(translation, first_order, Dict(:x => w)) == check(formula, model, w)
    for w in worlds(frame)))
```

```text
true
```

The adapter needs explicit atom and relation names when a model uses callable
valuation/frame data. It accepts Boolean models because this translation is a
classical reference bridge; it is not a many-valued first-order semantics.

## Bisimulation and contraction

[`bisimilar`](@ref) implements the finite labelled back-and-forth game: atomic
labels agree, and every successor has a matching successor in both directions.
Modal formulas are invariant under this relation (Blackburn et al., §2.2,
Definition 2.16 and Theorem 2.20, pp. 64–67)
[blackburn2001; §2.2, Definition 2.16 and Theorem 2.20, pp. 64–67](@cite).
`bisimulation_contraction` computes the largest auto-bisimulation quotient.
`contraction_world` maps an original world to its quotient class before a
caller evaluates on the quotient.

The direct game check costs `O(n₁ n₂ r d₁ d₂)` per refinement pass and may make
`n₁ n₂` passes; the implementation's straightforward worst-case bound is
`O((n₁ n₂)² r d₁ d₂)` time and `O(n₁ n₂)` space. Auto-contraction is
`O(n² r d log d)` worst-case with `O(n r d + n)` working space, followed by
quotient construction. The quotient is a reusable object, not an automatic
optimization: the [results](results.md) chapter reports a workload where one check
does not amortize its construction.

## Classical normal forms

`to_cnf` and `to_dnf` reuse the original pool. They normalize the classical
Boolean connectives and treat modal/custom subformulas as propositional
letters. The predicates `iscnf` and `isdnf` are shape checks; the conversions
are not advertised as Gödel or Łukasiewicz equivalences. For classical CNF/DNF
and clausal form, see Goranko, §2.5.1 (pp. 77–80)
[goranko2016; §2.5.1, pp. 77–80](@cite).

## Prover boundary

[`AbstractProver`](@ref) defines the interface. `PropositionalProver` is an
exhaustive truth-table fallback for Boolean propositional formulas; modal or
custom branches return `nothing`/`:unknown`. It is deliberately not a modal
or first-order prover. A downstream backend can implement `prove`,
`prove_valid`, and entailment without changing syntax or semantics.

```@example theory
using Aletheia
sig = Signature((¬, ∧, →))
pool = FormulaPool(sig)
p = atom(pool, "p")
tautology = branch(pool, →, p, p)
contradiction = branch(pool, ∧, p, branch(pool, ¬, p))
println(isvalid(tautology), " ", issatisfiable(contradiction))
println(prove_valid(tautology, PropositionalProver()).status)
```

```text
true false
valid
```

```@docs
standard_translation
FirstOrderInterpretation
evaluate
first_order_interpretation
bisimilar
bisimulation_contraction
iscnf
isdnf
to_cnf
to_dnf
AbstractProver
ProverResult
PropositionalProver
prove
prove_valid
```
