# Design decisions

This page records the choices that shape Aletheia's public architecture. Each
entry gives the context, the choice, and the consequence for users and
contributors.

## 2026-09-02 — API reference sizing

**Context.** The exported-symbol documentation sweep outgrew Documenter’s
single-page API reference default.

**Choice.** The generated API page uses a 500 KiB `size_threshold` and a
400 KiB warning threshold.

**Consequence.** The current reference builds without an error while the
warning signals when the reference should be split per package again.

## 2026-09-01 — Layered focused packages

**Context.** Users need a small dependency surface when they use only syntax,
semantics, data preparation, learning, or compatibility features.

**Choice.** The repository is split into `AletheiaCore`, `AletheiaData`,
`AletheiaLearn`, `AletheiaSole`, `AletheiaCircuits`, `AletheiaGraphs`,
`AletheiaAudit`, and `AletheiaNeSy`. The core package has no runtime
dependencies, while the `Aletheia` umbrella preserves the top-level API.

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

## Typed graph bridge

The graph layer uses typed entities and relations, keeps edge provenance in
replayable path records, and maps the graph to Aletheia's existing
`Frame`/`Model` and `ValuationCallback` boundaries. Path validity, source
provenance, and logical entailment remain separate contracts. A
description-logic profile is explicitly deferred rather than inferred from
graph paths.

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

## 2026-09-02 — Traces by default

**Context.** Audited symbolic decisions need checkable execution evidence, not only a final answer.

**Choice.** Every audited artifact evaluation emits a minimal deterministic trace. Sampling or redaction is explicit and records its scope.

**Consequence.** Consumers can serialize and replay an evaluation, while privacy-sensitive consumers can account for deliberate omissions.

## 2026-09-02 — Metric applicability is explicit

**Context.** Uncovered and out-of-vocabulary cases are not negative predictions.

**Choice.** Every audit metric carries its population, numerator, denominator, scope, and applicability. An inapplicable metric is missing rather than zero.

**Consequence.** Coverage and fidelity cannot hide undefined cases through denominator choices. This follows the metric requirements of symbolic XAI [stan2026](@cite).

## 2026-09-02 — Semantic loss requires a soundness profile

**Context.** Forward symbolic evaluation does not establish a reverse-mode gradient contract.

**Choice.** The neural-symbolic package exposes exact extraction and verification first. Semantic loss remains a typed, disabled placeholder until carrier and gradient soundness are proven.

**Consequence.** Hard symbolic claims are not confused with an unverified differentiable relaxation [stan2026; riguzzi2023](@cite).
