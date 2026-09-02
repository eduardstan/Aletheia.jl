# Aletheia.jl

Aletheia is a Julia monorepo of focused packages with one shared architecture:
one pooled syntax DAG, one model/evaluation boundary, and several deliberately
separate readings. `AletheiaCore` provides the pooled formulas, validated truth
algebras, relational frames, and evaluator; `AletheiaData`, `AletheiaCircuits`,
`AletheiaGraphs`, `AletheiaLearn`, `AletheiaSole`, `AletheiaAudit`, and
`AletheiaNeSy` add data, probability, graph, learning, compatibility, audit,
and neural-symbolic boundaries. The syntax/model/evaluation separation follows
the modal semantics vocabulary of Blackburn, de Rijke, and Venema
[blackburn2001; §§1.2–1.3, pp. 9–26](@cite).

The root `Aletheia` package re-exports the focused interfaces for a single-import
workflow. Applications can instead depend on only the package that implements
their boundary. [One engine, many readings](engine.md) shows how those
packages share an engine without collapsing distinct semantic objects.

Here is the whole shape of the package: a signature, a pool, a formula, a
frame, a model, and a check.

```jldoctest index
using Aletheia

signature = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
formula = parse(pool, "⟨R⟩p ∧ [R]q")

base_frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(base_frame, BOOLEAN,
    Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))

println(syntaxstring(formula))
println(check(formula, model, :w₁))

# output

⟨R⟩p ∧ [R]q
true
```

The vocabulary follows the modal-logic distinction between a similarity type,
its formulas, frames, models, and satisfaction. See Blackburn, de Rijke, and
Venema, §§1.2–1.3 (pp. 9–26) [blackburn2001; §§1.2–1.3, pp. 9–26](@cite).

## Package layout

Aletheia is maintained as focused Julia packages in one repository. The
umbrella `Aletheia` package re-exports the public interfaces, while focused
users can depend on the layer they need:

- [`AletheiaCore`](design.md) — pooled syntax, semantics, relations, and theory utilities;
- [`AletheiaData`](families.md) — model-family and scalar-data protocols;
- [`AletheiaCircuits`](circuits.md) — finite distribution-semantics programs, certified event
  diagrams, and Float64 or exact Rational weighted model counting;
- [`AletheiaGraphs`](graphs.md) — typed knowledge graphs, provenance-preserving paths, and
  relational frame adapters;
- [`AletheiaLearn`](learning.md) — ILP clauses, refinements, and learning-setting wrappers;
- [`AletheiaSole`](sole.md) — opt-in compatibility adapters;
- [`AletheiaAudit`](audit.md) — deterministic artifact traces, replay, and metrics;
- [`AletheiaNeSy`](nesy.md) — validated neural leaves and exact symbolic extraction.

The compatibility package is documented separately so that the shared-engine
narrative stays focused on Aletheia's own boundaries.

## Choose a path

- **[Quick start](quickstart.md)** — how do I install this and build my first
  formula, frame, model, and check? Every code example in the guide is a
  Documenter doctest.
- **[Syntax and design](design.md)** — why are truth values not formulas, why is
  formula identity pool-local, and why is `Box` a primitive rather than a
  negation/`Diamond` trick?
- **[Semantics and evaluation](semantics.md)** — how does a formula get a truth
  value, in Boolean, Gödel, and Łukasiewicz models?
- **[Many models, one formula](families.md)** — how do I evaluate one formula
  across a whole dataset of models?
- **[Scalar data](scalar.md)** — how do I prepare dense feature values and
  evaluate threshold/modal formulas over data?
- **[Finite FLew-algebras](algebras.md)** — what if my truth values are not a
  chain?
- **[Distribution-semantics circuits](circuits.md)** — how do I compile a
  finite probabilistic program and compute a query probability?
- **[Relations, frames, and frame classes](relations.md)** — how do I use Allen,
  RCC, or my own relation as modal accessibility, and check frame conditions?
- **[Theory utilities](theory.md)** — how do I translate to first-order logic,
  contract a model by bisimulation, or normalise a classical formula?
- **[Learning from interpretations](learning.md)** — why is a Kripke model
  already an ILP interpretation example?
- **[Audit artifacts](audit.md)** — how are traces, replay, and metric
  applicability recorded?
- **[Neural-symbolic interface](nesy.md)** — how are neural leaves validated
  and extracted exactly on finite cases?
- **[API reference](api.md)** — which symbols belong to each package?
- **[Measured results](results.md)** — what has been measured, with scope,
  provenance, and workload limits.
- **[Development and validation](development.md)** — how do I run the tests,
  docs, benchmarks, and differential checks?
- **[Coming from SoleLogics?](compatibility.md)** — an on-ramp for selected
SoleLogics consumers and their mappings.

## Scope and limits

Aletheia supplies pooled syntax, semantic structures, finite evaluation,
validated many-valued algebras, scalar/data preparation, finite
distribution-semantics circuits, typed graph adapters, audit artifacts, a
neural-symbolic boundary, theory utilities, and ILP foundations. It does **not**
ship a modal theorem prover, a first-order prover, a learner, an RCC composition
table, description-logic entailment, general probabilistic inference, or a
proven gradient-based semantic-loss path. The package pages describe each
boundary and its limits.

The benchmark is run by hand rather than in CI, because shared-runner timings
are too noisy to publish. Its differential correctness suite is separate from
package tests, and the [measured results](results.md) chapter reports the full
protocol, scope, and workload limits.
