# Learning from interpretations

```@meta
CurrentModule = Aletheia
```


## The connection

Inductive logic programming distinguishes learning from entailment, learning
from interpretations, and learning from proofs. Aletheia names those settings
with `learning_from_entailment`, `learning_from_interpretations`, and
`learning_from_proofs`. The semantic setting and the generic search/proof
vocabulary are developed in Muggleton and De Raedt, §§3–5 (pp. 635–649)
[muggleton1994; §§3–5, pp. 635–649](@cite).

A Kripke [`Model`](@ref) is an interpretation in this sense: it is a domain of
worlds, accessibility structure, and atom valuation. Therefore an existing
modal decision tree or decision list can already be viewed as learning from
interpretations over modal models. No conversion to a first-order tree is
required, and no learner is smuggled into Aletheia by making this observation.
The package supplies the example wrapper; a downstream learner supplies the
hypothesis search and scoring.

## A worked interpretation example

The example below is intentionally concrete. The two worlds and their edge
are the interpretation; `p` is true at `:w₁`. The wrapper records that this is a
positive example, and preserves object identity so a learner can retain the
model's relation and valuation rather than flattening them into a feature bag.

```@example learning
using Aletheia
frame = Frame((:w₁, :w₂), Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [])); index=true)
model = Model(frame, BOOLEAN, Dict("p" => Set([:w₁])))
example = interpretation_example(model; positive=true)

println(example.interpretation === model)
println(example.positive)
println(collect(accessible(example.interpretation, :w₁, :R)))
println(interpret(atom(FormulaPool(Signature((¬,))), "p"), model, :w₁))
```

```text
true
true
[:w₂]
true
```

`learning_from_interpretations(model)` is the concise constructor for the same
wrapper. `first_order_interpretation` is a separate adapter for users who want
a first-order presentation; it does not turn the model into a learner.

## Clauses and θ-subsumption

The ILP vocabulary is syntax-only. A [`Clause`](@ref) is a canonical set-like
disjunction of signed literals; [`HornClause`](@ref) restricts it to at most
one positive literal. [`subsumes`](@ref) implements Plotkin's
θ-subsumption: one substitution makes every literal of the first clause a
member of the second. See Muggleton and De Raedt, §5.2, Definition 5.3 (pp.
642–645) [muggleton1994; §5.2, Definition 5.3, pp. 642–645](@cite).

```@example learning
using Aletheia
X = Variable(:X)
a = Constant(:a)
general = HornClause(Predicate(:father, X), Predicate(:parent, X))
specific = Clause(Predicate(:father, a), Literal(Predicate(:parent, a), false))
println(subsumes(general, specific))
```

```text
true
```

θ-subsumption is a generality **quasi-order**, not logical implication. Mutual
subsumption can hold for distinct clauses after variables are identified, and
the recursive implication counterexample in §5.5.2 (pp. 648–649) is why this
layer exposes no implication test [muggleton1994; §5.5.2, pp. 648–649](@cite).

## Refinement is lazy and bounded by the bias

`downward_refinements` and `upward_refinements` return iterators. A supplied
finite vocabulary and finite term/substitution bounds make candidate
production locally finite; they do not make the operators complete or
optimal. The unrestricted upward case has infinite chains, and a general
complete operator cannot be claimed. See Muggleton and De Raedt, §5.2.2,
Definition 5.4 (pp. 644–645) [muggleton1994; §5.2.2, Definition 5.4, pp. 644–645](@cite)
and the bounded refinement-operator definitions in Tamaddoni-Nezhad and
Muggleton, “A Note on Refinement Operators for IE-Based ILP Systems,” pp.
297–314 of the ILP 2008 proceedings [zelezny2008; Tamaddoni-Nezhad and Muggleton, “A Note on Refinement Operators for IE-Based ILP Systems,” pp. 297–314](@cite).

```@example learning
using Aletheia
X = Variable(:X)
base = Clause(Predicate(:p, X))
candidates = downward_refinements(base; literals=[Predicate(:q, X)])
println(Base.IteratorSize(typeof(candidates)))
println(collect(candidates))
```

```text
Base.SizeUnknown()
Any[p(X) ∨ q(X)]
```

The implementation is therefore a foundation for a learner, not a learner,
prover, or least-Herbrand-model evaluator.

```@docs
Literal
Clause
HornClause
ClauseSet
Substitution
substitute
subsumes
downward_refinements
upward_refinements
InterpretationExample
interpretation_example
learning_from_interpretations
```
