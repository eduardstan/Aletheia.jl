# One engine, many readings

Aletheia is a Julia monorepo built around one semantic boundary: pooled
formula syntax is evaluated in a model, while each focused package supplies a
reading or an application boundary. This follows the separation between
similarity types, formulas, frames, models, and satisfaction in modal
semantics [blackburn2001; §§1.2–1.3, pp. 9–26](@cite). The implementation map
is visible in the [package workspace](https://github.com/eduardstan/Aletheia.jl/tree/main/lib) and the package pages
listed below.

## The shared engine: a pooled syntax DAG

`AletheiaCore` stores immutable `Atom` and `Branch` handles in an explicit
`FormulaPool`. Hash-consing gives repeated subterms one pool-local identity,
so the representation is a directed acyclic graph rather than a recursively
nested Julia value. Formula formation and the distinction between syntax and
its interpretation are the semantic starting point described by Blackburn,
de Rijke, and Venema [blackburn2001; §§1.2–1.3, pp. 9–26](@cite). See
[Syntax and design](design.md) for the representation contract.

The same reachable DAG is consumed by one bottom-up walk for `check` and
`extension`; Boolean, many-valued, and scalar callbacks enter that walk through
the model boundary. The modal clauses for frames and valuations are the
reference semantics for this shared evaluator [blackburn2001; §1.3, Definitions
1.19–1.20, pp. 16–20](@cite). See [Semantics and evaluation](semantics.md).

## Truth-algebra readings

`AletheiaCore` parameterizes model evaluation by a validated `TruthAlgebra`.
Boolean, Gödel, Łukasiewicz, and finite FLew algebras supply the carrier and
operations used by the same evaluator. Lattice operations, fusion,
implication, and negation belong to the algebra; they are not extra formula
kinds. The algebraic semantics of fuzzy chains follows Hájek and Cignoli,
D'Ottaviano, and Mundici [hajek1998; §2.1, pp. 27–29](@cite)
[cignoli2000; §1.1, pp. 7–8](@cite), while the finite FLew contract follows
Galatos et al. [galatos2007; §2.2, pp. 91–94](@cite). Read the implementation
details in [Semantics and evaluation](semantics.md) and [Finite FLew-algebras](algebras.md).

## Probability is a separate compiled path

`AletheiaCircuits` does not put probabilities in `TruthAlgebra`. A truth value
answers whether a formula holds at one selected world; distribution semantics
assigns mass to a set of two-valued program worlds. Riguzzi's account makes
that distinction explicit [riguzzi2023; chs. 2, 3, 8, and 12](@cite).

For its declared finite, function-free, ground, acyclic fragment,
`AletheiaCircuits` compiles query and evidence events to a certified reduced
ordered choice decision diagram. This is a knowledge-compilation boundary:
representation properties and transformations are treated separately from
logical meaning [darwiche2002; pp. 451–486](@cite). The circuit evaluator then
runs weighted model counting in a closed nonnegative semiring, including exact
rational evaluation; algebraic model counting provides the semiring abstraction
of Kimmig, Van den Broeck, and De Raedt [kimmig2017; pp. 49–69](@cite). See
[Distribution-semantics circuits](circuits.md)
for the supported fragment and its typed failure boundaries.

## Scalar data and model families

`AletheiaData` prepares scalar feature values over world × instance × feature
coordinates and keeps feature, aggregate, and formula caches separate. Its
model-family protocol lets one pooled formula be evaluated over materialized
models or an external dataset without making the core depend on a data-frame
package. See [Scalar data](scalar.md) and [Many models, one formula](families.md).

A scalar condition remains an atom payload, so real-data preparation uses the
same formula pool and evaluation walk rather than introducing a second scalar
syntax. Modal aggregation uses the frame's accessibility relation and the
selected algebra's existential or universal identity; the frame/model
semantics are the corresponding Kripke clauses [blackburn2001; §1.3, pp. 16–20](@cite).

## Typed graphs as Kripke frames

`AletheiaGraphs` represents typed entities, typed directed edges, and replayable
edge provenance. Its adapter maps entities to worlds and relation schemas to
named relations in an Aletheia `Frame`, after which `AletheiaCore` can evaluate
modal formulas on that structure. A relational frame is the standard semantic
object for modal accessibility [blackburn2001; §1.3, pp. 16–20](@cite). See
[Knowledge graphs](graphs.md).

The graph layer keeps path validity, provenance, and logical entailment as
different results; a path is not silently promoted to an ontology proof. That
boundary is an implementation contract. Description-logic entailment is not
provided by the current graph adapter; see its [package page](graphs.md).

## Learning, compatibility, and the two boundary packages

`AletheiaLearn` supplies ILP clauses, substitutions, refinement iterators, and
scoring over interpretation examples. A Kripke model can serve as an
interpretation without changing the shared syntax or evaluator. The learning
settings and θ-subsumption vocabulary follow Muggleton and De Raedt
[muggleton1994; §§3–5, pp. 635–649](@cite); the implementation is documented in
[Learning from interpretations](learning.md).

`AletheiaSole` is an opt-in edge adapter for a separate formula vocabulary.
Its mappings and measured consumer evidence belong in the [on-ramp for
selected
SoleLogics consumers](compatibility.md), not in the description of the shared
engine.

`AletheiaAudit` adds deterministic execution traces, provenance, replay, and
metrics whose applicability is explicit. Trace validity, fidelity, coverage,
and resource accounting are kept as separate report fields because symbolic
explanation evaluation needs more than a single accuracy number
[stan2026; pp. 1–60](@cite). See [Audit artifacts](audit.md).

`AletheiaNeSy` accepts a callable neural component at the valuation boundary,
validates its outputs against the declared carrier, and can extract an exact
symbolic artifact on a declared finite case set. Neural values and finite
choice labels follow separate paths: the former are truth-carrier values, while
the latter are normalized distribution labels. Neural-symbolic systems that
combine learned predicates with logic motivate this boundary
[manhaeve2021](@cite) [li2023](@cite) [serafini2021](@cite)
[yan2020](@cite); semantic-loss formulations are a related but distinct
probabilistic training path [xu2018](@cite). The exact extraction and audit
contracts are described in [Neural-symbolic interface](nesy.md).

## Package order

The focused packages can be read in dependency order:

1. [`AletheiaCore`](https://github.com/eduardstan/Aletheia.jl/tree/main/lib/AletheiaCore) — pooled syntax, models,
   algebras, relations, evaluation, and theory utilities.
2. [`AletheiaData`](https://github.com/eduardstan/Aletheia.jl/tree/main/lib/AletheiaData) — scalar preparation and
   model-family protocols.
3. [`AletheiaCircuits`](https://github.com/eduardstan/Aletheia.jl/tree/main/lib/AletheiaCircuits) — finite
   distribution-semantics circuits and semiring inference.
4. [`AletheiaGraphs`](https://github.com/eduardstan/Aletheia.jl/tree/main/lib/AletheiaGraphs) — typed graph and frame
   adapters.
5. [`AletheiaLearn`](https://github.com/eduardstan/Aletheia.jl/tree/main/lib/AletheiaLearn) — ILP foundations over
   the core evaluator.
6. [`AletheiaSole`](https://github.com/eduardstan/Aletheia.jl/tree/main/lib/AletheiaSole) — opt-in compatibility
   adapters.
7. [`AletheiaAudit`](audit.md) — traces, replay, and audit metrics.
8. [`AletheiaNeSy`](nesy.md) — validated neural leaves and exact symbolic extraction.

The root `Aletheia` package assembles these focused boundaries for applications
that prefer one import. The [API reference](api.md) lists the public exports;
the [Design decisions](design-decisions.md) page records why the boundaries
are kept separate.
