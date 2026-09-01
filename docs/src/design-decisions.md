# Design decisions

This page records the choices that shape Aletheia's public architecture. Each
entry gives the context, the choice, and the consequence for users and
contributors.

## 2026-09-01 — Layered focused packages

**Context.** Users need a small dependency surface when they use only syntax,
semantics, data preparation, learning, or compatibility features.

**Choice.** The repository is split into `AletheiaCore`, `AletheiaData`,
`AletheiaLearn`, `AletheiaSole`, and `AletheiaCircuits`. The core package has no runtime
dependencies, while the `Aletheia` umbrella preserves the historical API.

**Consequence.** Applications can depend on one focused layer, and existing
applications can keep using `Aletheia` without changing their imports.

## 2026-09-01 — SoleLogics as an edge adapter

**Context.** SoleLogics compatibility is useful for migration, but it would
make the syntax and semantic foundation depend on an external vocabulary.

**Choice.** `AletheiaSole` owns the opt-in `SoleLogics` module and its adapters.
The core packages do not import SoleLogics.

**Consequence.** Core users avoid compatibility dependencies, while migration
users can explicitly load `AletheiaSole.SoleLogics` (or
`Aletheia.SoleLogics`).

## 2026-09-01 — Three tiers for dependencies

**Context.** Runtime logic code should remain portable, but tests need strong
quality tools and higher-level packages need established ecosystem support.

**Choice.** Dependencies follow three tiers: zero-dependency runtime code in
`AletheiaCore`, test-only tooling in test environments, and canonical ecosystem
packages in non-core packages.

**Consequence.** The core stays easy to embed and audit, quality checks remain
strict, and optional capabilities do not enlarge every installation.

## 2026-09-01 — A certified circuit representation

**Context.** Aletheia needs a representation that can support certified,
repeatable circuit-level operations without making an external engine part of
its runtime contract.

**Choice.** `AletheiaCircuits` owns a certified reduced ordered choice diagram
for its finite distribution-semantics fragment. External circuit engines may
serve as test oracles, but they are not the source of Aletheia's runtime
semantics.

**Consequence.** Circuit evaluation remains auditable and independent of
engine availability and licensing. The certificate makes ordering, support,
determinism, smoothness, and source provenance explicit.

## 2026-09-01 — Graphs.jl as the graph backbone

**Context.** Frames, bisimulation, and contraction all need dependable graph
algorithms, but duplicating graph infrastructure would increase maintenance.

**Choice.** Graphs.jl is planned as the graph backbone. Until that integration
is complete, existing interfaces remain the stable boundary for graph work.

**Consequence.** Future graph algorithms can share a canonical ecosystem
abstraction without forcing a premature runtime dependency on the core.


## 2026-09-01 — Finite distribution semantics stays outside `TruthAlgebra`

**Context.** A probability is a measure over selected two-valued program
worlds, while `TruthAlgebra` evaluates a formula at one world. Conflating the
two would make normalization and circuit guarantees invisible.

**Choice.** `AletheiaCircuits` is a focused package with only a finite,
function-free, ground, acyclic fragment. It compiles events to an owned
reduced ordered choice decision diagram and evaluates only a certified circuit
through a closed nonnegative probability semiring. The umbrella re-exports
this package because it is a stable user-facing layer, while the focused
package remains directly usable.

**Consequence.** WMC and positive-denominator conditional probability are
exact claims for the declared fragment. Function symbols, cycles, unnormalized
choices, and zero-mass evidence fail with typed exceptions. Gradients, EM,
and general AMC remain deliberately outside this contract.
