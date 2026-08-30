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
worlds, accessibility structure, and atom valuation. So a modal decision tree
or decision list is already a learner over interpretations, with no conversion
to a first-order representation. Aletheia supplies the example wrapper and the
evaluator; the hypothesis search and scoring belong to the learner.

## A worked interpretation example

The example below is intentionally concrete. The two worlds and their edge
are the interpretation; `p` is true at `:w₁`. The wrapper records that this is a
positive example, and preserves object identity so a learner can retain the
model's relation and valuation rather than flattening them into a feature bag.

```jldoctest learning
using Aletheia
base_frame = Frame((:w₁, :w₂), Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [])); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([:w₁])))
example = interpretation_example(model; positive=true)
show(stdout, MIME"text/plain"(), example)
println()

println(example.interpretation === model)
println(example.positive)
println(collect(accessible(example.interpretation, :w₁, :R)))
println(interpret(atom(FormulaPool(Signature((¬,))), "p"), model, :w₁))

# output

InterpretationExample (+): Model(2 worlds, BooleanAlgebra())
true
true
[:w₂]
true
```

`learning_from_interpretations(model)` is the concise constructor for the same
wrapper and, like `interpretation_example`, expects a modal [`Model`](@ref).
`first_order_interpretation` is a separate adapter for users who want a
first-order presentation; it does not turn the model into a learner. A caller
who owns a different interpretation type can construct [`InterpretationExample`](@ref)
directly.

## Clauses and θ-subsumption

The ILP vocabulary is syntax-only. A [`Clause`](@ref) is a canonical set-like
disjunction of signed literals; [`HornClause`](@ref) restricts it to at most
one positive literal. [`subsumes`](@ref) implements Plotkin's
θ-subsumption: one substitution makes every literal of the first clause a
member of the second. See Muggleton and De Raedt, §5.2, Definition 5.3 (pp.
642–645) [muggleton1994; §5.2, Definition 5.3, pp. 642–645](@cite).

```jldoctest learning_clauses
using Aletheia
X = Variable(:X)
a = Constant(:a)
general = HornClause(Predicate(:father, X), Predicate(:parent, X))
specific = Clause(Predicate(:father, a), Literal(Predicate(:parent, a), false))
show(stdout, MIME"text/plain"(), general)
println()
show(stdout, MIME"text/plain"(), ClauseSet([general, specific]))
println()
show(stdout, MIME"text/plain"(), Substitution(X => a))
println()
println(subsumes(general, specific))

# output

father(X) :- parent(X)
ClauseSet (2 clauses)
  father(X) :- parent(X)
  father(a) :- parent(a)
Substitution: {X ↦ a}
true
```

The other learning-setting wrappers have the same compact display:

```jldoctest learning_wrappers
using Aletheia
X = Variable(:X)
general = HornClause(Predicate(:father, X), Predicate(:parent, X))
show(stdout, MIME"text/plain"(), learning_from_entailment(general))
println()
show(stdout, MIME"text/plain"(), learning_from_proofs(:proof))
println()

# output

EntailmentExample (+): father(X) :- parent(X)
ProofExample (+): proof
```

θ-subsumption is a generality **quasi-order**, not logical implication. Mutual
subsumption can hold for distinct clauses after variables are identified. The
recursive implication counterexample first appears in §5.2.1 (p. 643) and is
revisited in §5.5 (p. 648), which is why this layer exposes no implication test
[muggleton1994; §5.2.1, p. 643; §5.5, p. 648](@cite).

## Refinement is lazy and bounded by the bias

`downward_refinements` and `upward_refinements` return iterators. A supplied
finite vocabulary and finite term/substitution bounds make candidate
production locally finite; they do not make the operators complete or
optimal. The unrestricted upward case has infinite chains, and a general
complete operator cannot be claimed. See Muggleton and De Raedt, §5.2.2,
Definition 5.4 (pp. 644–645) [muggleton1994; §5.2.2, Definition 5.4, pp. 644–645](@cite)
and the bounded refinement-operator definitions in Tamaddoni-Nezhad and
Muggleton, “A Note on Refinement Operators for IE-Based ILP Systems”, pp.
297–314 [tamaddoni2008; pp. 297–314](@cite).

```jldoctest learning_refinement
using Aletheia
X = Variable(:X)
base = Clause(Predicate(:p, X))
candidates = downward_refinements(base; literals=[Predicate(:q, X)])
println(Base.IteratorSize(typeof(candidates)))
show(stdout, MIME"text/plain"(), ClauseSet(collect(candidates)))
println()

# output

Base.SizeUnknown()
ClauseSet (1 clause)
  p(X) ∨ q(X)
```

Horn-clause refinements preserve the `HornClause` type and reject an added
positive literal when it would create a second head. Supplied substitutions are
applied to both the base clause and each appended literal template. `max_literals`
bounds every emitted candidate, including substitution-only candidates; it must
be `nothing` or a non-negative integer. The implementation is therefore a
foundation for a learner, not a learner, prover, or least-Herbrand-model
evaluator.
