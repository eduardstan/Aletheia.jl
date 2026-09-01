# Design decisions

This page records the choices that shape Aletheia's public architecture. Each
entry gives the context, the choice, and the consequence for users and
contributors.

## 2026-09-01 — Layered focused packages

**Context.** Users need a small dependency surface when they use only syntax,
semantics, data preparation, learning, or compatibility features.

**Choice.** The repository is split into `AletheiaCore`, `AletheiaData`,
`AletheiaLearn`, and `AletheiaSole`. The core package has no runtime
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

**Choice.** An owned certified circuit representation is planned. External
circuit engines will be used as test oracles, not as the source of Aletheia's
runtime semantics.

**Consequence.** The public design can evolve toward certified circuits while
keeping the current packages independent of engine availability and licensing.

## 2026-09-01 — Graphs.jl as the graph backbone

**Context.** Frames, bisimulation, and contraction all need dependable graph
algorithms, but duplicating graph infrastructure would increase maintenance.

**Choice.** Graphs.jl is planned as the graph backbone. Until that integration
is complete, existing interfaces remain the stable boundary for graph work.

**Consequence.** Future graph algorithms can share a canonical ecosystem
abstraction without forcing a premature runtime dependency on the core.


## Typed graph bridge

The graph layer uses typed entities and relations, keeps edge provenance in replayable path records, and maps the graph to Aletheia's existing `Frame`/`Model` and `ValuationCallback` boundaries. Path validity, source provenance, and logical entailment remain separate contracts. A description-logic profile is explicitly deferred rather than inferred from graph paths.
