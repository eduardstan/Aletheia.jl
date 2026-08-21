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

## Theory layer

Aletheia's theory layer keeps the interned modal formula as the only source
representation. [`standard_translation`](@ref) produces a deliberately small
first-order syntax (`Variable`, `Predicate`, equality, Boolean connectives, and
`Exists`/`Forall`) using the standard translation of Blackburn, de Rijke, and
Venema §2.4 [blackburn2001](@cite).  `evaluate` is a reference evaluator for
that target syntax; it is not a first-order prover.

[`bisimilar`](@ref) implements the finite labelled bisimulation game from BDV
§2.2 [blackburn2001](@cite), and [`bisimulation_contraction`](@ref) computes
the largest auto-bisimulation quotient.  The direct game check uses
O(n₁n₂r d₁d₂) time per refinement pass, O(n₁n₂) space, and at most n₁n₂
passes; contraction uses O(n²rd log d) worst-case time and O(nrd+n) working
space.  `contraction_world` maps an original world to its quotient class, so
modal evaluation can be compared directly.
`iscnf`/`isdnf` and [`to_cnf`](@ref)/[`to_dnf`](@ref) perform classical Boolean
normalization in the original formula pool; modal subformulas are treated as
propositional letters.  As expected, these conversions are not advertised as
many-valued equivalences.

Proof search is intentionally only a boundary. [`AbstractProver`](@ref)
defines the question, while a backend supplies the answer (and may provide a
countermodel or certificate in [`ProverResult`](@ref)).  The shipped
[`PropositionalProver`](@ref) is an exhaustive truth-table fallback and returns
`nothing` for modal or custom connectives.  A concrete adapter can therefore
implement `prove`, `prove_valid`, and entailment without changing Aletheia.


## Inductive logic programming foundations

The ILP layer is syntax-only foundations, not a learner.  It extends the
existing first-order terms with [`FunctionTerm`](@ref), then represents a
signed atomic formula as a [`Literal`](@ref).  A [`Clause`](@ref) is an
immutable canonical tuple with set semantics: it is read as a disjunction of
literals, and [`HornClause`](@ref) checks that at most one literal is positive.
[`ClauseSet`](@ref) is the compact representation of background knowledge.
This is the clause vocabulary of Muggleton and De Raedt, §5.2
[muggleton1994](@cite); substitutions intentionally cover terms, atoms, and
clauses rather than pretending to be a capture-avoiding substitution for every
quantified formula in the small first-order core.

[`subsumes`](@ref) implements Plotkin's θ-subsumption: `c₁` θ-subsumes `c₂`
when one substitution makes every literal of `c₁` a member of `c₂`
(Muggleton and De Raedt, Definition 5.3, p. 643 [muggleton1994](@cite)).  The
search is direct backtracking and therefore has the expected NP-complete worst
case.  It induces the generality **quasi-order**, not a partial order:
different clauses can subsume one another after variables are identified.
`equivalent_under_subsumption` tests this mutual-subsumption relation.  This
is not logical implication.  The survey's recursive example
`p(f(X)) :- p(X)` and `p(f(f(Y))) :- p(Y)` is an implication without
θ-subsumption (pp. 643, 648 [muggleton1994](@cite)); Aletheia deliberately exposes
no implication test here.

[`downward_refinements`](@ref) and [`upward_refinements`](@ref) return lazy
iterators.  Downward refinement applies supplied substitutions and adds one
literal from the supplied language bias; upward refinement deletes a literal
or abstracts a term.  Both are sound and proper for θ-subsumption.  With a finite supplied vocabulary and finite substitution/term bound they are
locally finite; neither claims local or global completeness or optimality.  In particular, upward generalization is
incomplete for unrestricted clausal logic, where the survey notes infinite
chains (Muggleton and De Raedt, Definition 5.4 and §5.2.2, pp. 644–645
[muggleton1994](@cite)).  A `literals` or non-collection `predicates` vocabulary may itself be an
unbounded iterator: refinement candidates are not materialized.

The survey names three settings exactly as **learning from entailment**,
**learning from interpretations**, and **learning from proofs**.  Their
examples are respectively queries/formulas whose entailment is observed,
interpretations, and proof objects; the constructors
[`learning_from_entailment`](@ref), [`learning_from_interpretations`](@ref),
and [`learning_from_proofs`](@ref) make those labels explicit (Muggleton and
De Raedt, §§3–5 [muggleton1994](@cite)).  A Kripke [`Model`](@ref) in this
package is an interpretation: [`interpretation_example`](@ref) presents it
directly as an example in the second setting.  Thus Sole's existing modal
decision trees and decision lists are, informally, learning from
interpretations over modal models (Muggleton and De Raedt, §3
[muggleton1994](@cite)):

```julia
frame = Frame((:w₁, :w₂), Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [])))
model = Model(frame, BOOLEAN, Dict("p" => Set([:w₁])))
example = interpretation_example(model; positive=true)
example.interpretation === model  # true
```

The separate [`first_order_interpretation`](@ref) adapter remains available
for Boolean modal models when a first-order predicate presentation is wanted;
it is not a learner or a theorem prover.

### SoleReasoners adapter sketch

`SoleReasoners.jl` is deliberately not a dependency of Aletheia and its
modal/many-valued engines remain there.  Its actual propositional entry points
are `SoleReasoners.sat` (exported; satisfiability) and the module-qualified
`SoleReasoners.prove` in `src/propositional-tableau/propositional-tableau.jl`
(validity; not exported).  A downstream adapter can use the following shape:

```julia
struct SoleReasonersProver <: Aletheia.AbstractProver
    choose::Function
    metrics::Tuple
end
function Aletheia.prove(p::SoleReasonersProver, f)
    sf = to_sole(f) # recursively maps Atom/¬/∧/∨/→; rejects unsupported modalities
    answer = SoleReasoners.sat(sf, p.choose, p.metrics...)
    Aletheia.ProverResult(answer === nothing ? :unknown : (answer ? :sat : :unsat);
                          answer=answer, certificate=:tableau)
end
function Aletheia.prove_valid(p::SoleReasonersProver, f)
    sf = to_sole(f)
    # The safe public alternative to the module-private `prove`:
    answer = SoleReasoners.sat(SoleLogics.¬(sf), p.choose, p.metrics...)
    Aletheia.ProverResult(answer === nothing ? :unknown : (!answer ? :valid : :invalid);
                          answer=answer === nothing ? nothing : !answer,
                          certificate=:tableau)
end
```

The real converter constructs `SoleLogics.Atom(value(f))` and recursively
constructs the four propositional connectives.  Relational modalities require
an explicit bridge to SoleLogics relation objects; arbitrary Aletheia relation
payloads are rejected rather than silently reinterpreted.  The many-valued
`alphasat`/`alphaval` entry points in SoleReasoners additionally require a
finite algebra and a tableau type, so they belong in that downstream adapter,
not in this package.

## Compatibility migration

The opt-in [`Aletheia.SoleLogics`](@ref) vocabulary and its consumer-derived mapping/gaps are documented on the [migration page](compatibility.md).

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
