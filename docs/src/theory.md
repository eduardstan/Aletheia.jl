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

The atom and relation namespaces must agree between the two calls. For example,
if a translation uses `atom_predicate = p -> Symbol("atom_", p)` and
`relation_predicate = r -> Symbol("edge_", r)`, pass the same functions to
`first_order_interpretation`; otherwise `evaluate` will report a missing
predicate even though the modal model is valid. Dictionary-backed valuations
and named frame relations are inferred, but callable valuations require
`atoms=[...]` and callable accessibility requires `relations=[...]`. An atom
handle may be supplied in `atoms` when the valuation is keyed by `Atom`; a
string or other atom value is also accepted. First-order assignments are
looked up by `Symbol` (for example `Dict(:x => world)`), and each assigned
world must belong to the interpretation domain.

The translation only has clauses for the built-in Boolean connectives and
`Diamond`/`Box`; a custom connective raises `ArgumentError`. Likewise,
`first_order_interpretation` does not translate many-valued models: use the
native evaluator for Gödel or Łukasiewicz models instead.

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

Here is a complete finite example: the one-world and two-world roots are
bisimilar while unlabelled, and `◇p` becomes a separating formula after `t` is
labelled. The same model can then be contracted; checks on original worlds are
forwarded through their quotient classes.

```@example theory_bisimulation
using Aletheia

signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
separator = branch(pool, Diamond(:R), p)

one = Frame((:r,), Dict(:R => Dict(:r => [:r])); index=true)
two = Frame((:s, :t), Dict(:R => Dict(:s => [:t], :t => [:t])); index=true)
m₁ = Model(one, BOOLEAN, Dict("p" => Set{Symbol}()))
m₂ = Model(two, BOOLEAN, Dict("p" => Set{Symbol}()))
m₂_bad = Model(two, BOOLEAN, Dict("p" => Set([:t])))
println("bisimilar before relabelling: ", bisimilar(m₁, :r, m₂, :s))
println("separator values after relabelling: ",
    check(separator, m₁, :r), "/", check(separator, m₂_bad, :s))

base = Frame((1, 2, 3), Dict(:R => Dict(1 => [1], 2 => [2], 3 => [3])); index=true)
model = Model(base, BOOLEAN, Dict("p" => Set([3])))
quotient = bisimulation_contraction(model)
formula = branch(pool, Diamond(:R), p)
original = [check(formula, model, w) for w in worlds(base)]
reduced = [check(formula, quotient, w) for w in worlds(base)]
println("contraction world count: ", length(worlds(base)), " -> ",
    length(worlds(frame(quotient))))
println("values preserved: ", original == reduced)
```

```text
bisimilar before relabelling: true
separator values after relabelling: false/true
contraction world count: 3 -> 2
values preserved: true
```

`atoms` and `relations` are semantic vocabularies, not formula-pool metadata.
They are inferred from dictionary-backed models and frames, but must be passed
explicitly for callable valuation or accessibility data. `contraction_world(q,
w)` maps an original world to its `BisimulationClass`; `check` accepts either an
original world or a class. `extension(formula, q)` deliberately preserves the
underlying model's world order and length, so use `check` on quotient classes
(or inspect `classes(q)`) when a quotient-indexed vector is needed.

## Classical normal forms

`to_cnf` and `to_dnf` reuse the original pool. They normalize the classical
Boolean connectives and treat modal/custom subformulas as propositional
letters. The predicates `iscnf` and `isdnf` are shape checks; the conversions
are not advertised as Gödel or Łukasiewicz equivalences. A formula's signature
must contain `¬`, `∧`, and `∨` even when the input happens not to use all three;
otherwise conversion raises `ArgumentError`. Since modal and custom branches
are opaque literals, negating one leaves it as a signed literal rather than
applying a modal duality. For classical CNF/DNF and clausal form, see Goranko,
§2.5.1 (pp. 77–80) [goranko2016; §2.5.1, pp. 77–80](@cite).

## Prover boundary

[`AbstractProver`](@ref) defines the interface. `PropositionalProver` is an
exhaustive truth-table fallback for Boolean propositional formulas; modal or
custom branches return `nothing`/`:unknown`. It is deliberately not a modal
or first-order prover. The optional `atoms` override must contain every atom
payload in the formula (and may include extras); an incomplete or duplicate
override is rejected with `ArgumentError`. A downstream backend can implement `prove`,
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

`prove` asks for satisfiability; use `prove_valid` for validity. The shipped
`PropositionalProver` returns statuses such as `:sat`, `:unsat`, `:valid`, and
`:invalid`; modal or custom branches return `ProverResult(:unknown)` rather
than being treated as false. Consequently, inspect `result.status` when
unknown and false must be distinguished—`Bool(result)` is only a convenience
for a known true answer. The convenience forms use
`issatisfiable(formula)`/`isvalid(formula)` with a fresh propositional prover;
applications with a modal backend should pass their own `AbstractProver`
explicitly.
