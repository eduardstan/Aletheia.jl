# Design decisions

This page records the choices that shape Aletheia's public architecture. Each
entry gives the context, the choice, and the consequence for users and
contributors.

## 2026-09-05 — One recursive ownership rule

**Context.** Shallow checks allowed immutable wrappers to retain mutable values,
and fieldless runtime containers could hide mutable elements.

**Choice.** Every value a user supplies to a semantic constructor is structurally owned to any depth. The constructor recursively snapshots standard arrays, dictionaries, and sets; accepts only recursively owned immutable wrappers; and refuses a mutable opaque value, mutable closure capture, or an immutable wrapper whose required snapshot cannot preserve `isequal` and `hash`, with a path-aware `OwnershipError`. The formula intern arena and the evaluator caches are implementation state: the formula arena is named separately from the frame-adjacency cache and scalar aggregate-memo cache, and none is part of any semantic value's identity, hash, or equality. Interned node records are immutable and append-only under the pool lock, so an existing node cannot be overwritten. The frame-adjacency registry uses weak frame references and a `release!` operation; its entry lasts only while its frame is live. The scalar registry uses a per-prepared-record token, releases its source and memo entries at token finalization or through `release!`/`clear!`, and never silently replaces stale data: a source-version mismatch throws `ArgumentError` instructing the caller to re-run `prepare_scalar`.

## 2026-09-04 — Immutable collection storage for public semantic values

**Context.** Defensive copies at accessors did not protect direct public fields or
nested standard collections retained by semantic objects.

**Choice.** Constructors recursively snapshot arrays, dictionaries, and sets into
immutable tuples and `AletheiaCore` frozen collection values. Certified circuit
nodes, finite algebra tables, frame relations, valuations, scalar stores, audit
payloads, and graph paths therefore retain standard collections in immutable
language-level storage. Accessors still return ordinary mutable snapshots
where the API historically returned arrays or maps.

**Consequence and cost.** A caller cannot alter collection-backed semantic state
through a field, accessor result, or original collection input, and mutable
opaque values fail at construction rather than becoming live fields. The
frame adjacency remains a deliberately mutable evaluator-side cache because
lock-protected lazy adjacency indexing is the measured hot-path optimization;
it is not a field of a semantic value and is excluded from the immutable
collection contract. Frame-sharing callback behavior is specified in [Many
models, one formula](families.md#When-instances-share-a-frame).

A local 32-world microbenchmark (Julia 1.12.7, 20 batches of 100 calls) measured
`Frame` construction at 63.3 → 67.2 μs and dictionary-`Model` construction at
0.29 → 2.63 μs. The associated direct dictionary `check` apply path measured
4.17 → 1.32 μs per call after atom checks were made scalar and frozen-set
membership was indexed at construction. This is not a deployed consumer
result; the documented callback/data apply benchmarks remain the workload
evidence.

## 2026-09-04 — One defensive-copy rule at every public boundary

**Context.** Values crossing a public constructor, accessor, retained record, or
callback boundary must not remain aliases of caller-owned mutable material.

**Choice.** Aletheia uses one repository-wide rule: **defensive copying at the
boundary**. `_boundary_copy` returns mutable snapshots for compatibility;
`_immutable_copy` is used for retained semantic fields. Callable artifacts are
explicitly rejected by `serialize_trace`, because Julia closures cannot be
copied into a portable serialized representation.

**Consequence and cost.** Boundary copies isolate accepted and returned standard
collections from caller-owned mutable material. Retained field storage follows
the immutable collection decision above; opaque mutable values and callbacks
with mutable captured fields are rejected. Copying costs time
and memory proportional to mutable material at each boundary; hot evaluation loops
retain owned internal data.

## 2026-09-03 — Exact and owned boundary values

**Context.** Numeric, callback, graph, and family boundaries must not silently
change semantic values or accept ambiguous ownership.

**Choice.** `RationalProfile` uses an unbounded exact carrier and normalizes
converted finite weight tuples. Vectorized valuation results copy mutable
carriers. Graph entity and relation constructors copy metadata. `ModelFamily`
rejects models with unequal truth algebras using `MixedAlgebraError`.

**Consequence.** Accepted probability choices close exactly, scalar and batch
evaluation agree for reusable mutable callback values, graph metadata remains
owned by its record, and family batch results have one carrier contract.

## 2026-09-03 — Context-authenticated trace replay

**Context.** A replayed graph path or artifact verdict needs the context that
produced it, not only self-consistent fields.

**Choice.** Artifact-verdict traces require an attached artifact. Graph-path
traces require an attached graph, a recorded graph hash, and `path_valid`.

**Consequence.** Mutated or context-free traces are rejected rather than
reported as valid.

## 2026-09-02 — API reference sizing

**Context.** The exported-symbol documentation sweep outgrew Documenter’s
single-page API reference default.

**Choice.** The `Documenter.HTML` format in `docs/make.jl` sets
`size_threshold = 500 * 1024` and `size_threshold_warn = 400 * 1024`.
These thresholds size the generated API page; they do not size an evaluation
cache.

**Consequence.** The current reference builds without an error while the
warning signals when the reference should be split per package again.

## 2026-09-01 — Layered focused packages

**Context.** Users need a small dependency surface when they use only syntax,
semantics, data preparation, learning, or compatibility features.

**Choice.** The repository is split into `[`AletheiaCore`](api.md)`, `[`AletheiaData`](families.md)`,
`[`AletheiaLearn`](learning.md)`, `[`AletheiaSole`](compatibility.md)`, `[`AletheiaCircuits`](circuits.md)`, `[`AletheiaGraphs`](graphs.md)`,
`[`AletheiaAudit`](audit.md)`, and `[`AletheiaNeSy`](nesy.md)`. The core package has no runtime
dependencies, while the `Aletheia` umbrella preserves the top-level API.

**Consequence.** Applications can depend on one focused layer, and existing
applications can keep using `Aletheia` without changing their imports.

## 2026-09-01 — SoleLogics as an edge adapter

**Context.** SoleLogics compatibility is useful for migration, but it would
make the syntax and semantic foundation depend on an external vocabulary.

**Choice.** `[`AletheiaSole`](compatibility.md)` owns the opt-in `SoleLogics` module and its adapters.
The core packages do not import SoleLogics.

**Consequence.** Core users avoid compatibility dependencies, while migration
users can explicitly load `AletheiaSole.SoleLogics` (or
`Aletheia.SoleLogics`).

## 2026-09-01 — Three tiers for dependencies

**Context.** Runtime logic code should remain portable, but tests need strong
quality tools and higher-level packages need established ecosystem support.

**Choice.** Dependencies follow three tiers: zero-dependency runtime code in
`[`AletheiaCore`](api.md)`, test-only tooling in test environments, and canonical ecosystem
packages in non-core packages.

**Consequence.** The core stays easy to embed and audit, quality checks remain
strict, and optional capabilities do not enlarge every installation.

## 2026-09-01 — A certified circuit representation

**Context.** Aletheia needs a representation that can support certified,
repeatable circuit-level operations without making an external engine part of
its runtime contract.

**Choice.** `[`AletheiaCircuits`](circuits.md)` owns a certified reduced ordered choice diagram
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

**Choice.** `[`AletheiaCircuits`](circuits.md)` is a focused package with only a finite,
function-free, ground, acyclic fragment. It compiles events to an owned
reduced ordered choice decision diagram and evaluates only a certified circuit
through a closed nonnegative probability semiring. The umbrella re-exports
this package because it is a stable user-facing layer, while the focused
package remains directly usable.

**Consequence.** WMC and positive-denominator conditional probability are
exact claims for the declared fragment. Function symbols, cycles, unnormalized
choices, and zero-mass evidence fail with typed exceptions. Gradients, EM,
and general AMC remain deliberately outside this contract.

## 2026-09-03 — Audit boundary edge cases are explicit

**Context.** Adversarial cases exposed ambiguity at three public boundaries: exact
probability conversion, Boolean choice outcomes, and optional trace emission.

**Choice.** `RationalProfile()` converts Float64 weights with `rationalize` using an
eight-ulp tolerance. `Bool` is reserved for two-valued event constants and is
rejected as a choice alternative; callers should use named atoms. `eval_artifact`
honors `trace=false` by returning `nothing` for the trace.

**Consequence.** Exact WMC remains available for common Float64 inputs, Boolean
events cannot collide with choice atoms, and callers can deliberately omit trace
material rather than receiving an ignored option.

## 2026-09-03 — Adversarial boundary contracts

**Context.** Boundary validation must terminate and preserve the distinctions that callers use for exact computation, replay, metrics, scalar domains, and benchmark provenance.

**Choice.** Cyclic mutable circuit values fail closed with a typed validation error. Rational evaluation rejects Float64 conversions that do not preserve normalized closure or that overflow the exact carrier. `ske_roundtrip` validates leaves with its declared algebra. Graph-path traces retain graph context and replay checks endpoints, edges, and provenance. Audit records distinguish declared input hashes from evaluated-state hashes, and stability chooses its baseline by canonical state hash. Scalar preparation rejects explicit world lists that do not match every frame domain. Uniform model-family status is canonicalized to shared frame identity. Benchmark source uses the documented scale cap and logs the seed passed to its generator.

**Consequence.** Invalid or ambiguous inputs fail at the boundary, metrics are permutation-invariant, graph traces are verifiable, and published benchmark protocols can be reproduced from their recorded settings.

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
