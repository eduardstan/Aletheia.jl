# Changelog

All notable changes to Aletheia are documented here. The umbrella and focused packages are currently
pre-release (`0.2.0-DEV`), so there is no released version yet.

## Unreleased

- Unified the shared graph, circuit, and audit accessor generics in `AletheiaCore`, so focused packages extend one umbrella binding and single-import workflows remain unambiguous.
- Stored the owned frame hash at construction and reused it for evaluator cache lookup, avoiding repeated structural hashing during evaluation.

- Moved formula arena storage into its owning append-only arena, made formula-pool indexing read-only outside locked interning, and added formula-pool and audit-trace serialization round trips.
- Added value equality and hashing for owned frames and models, shared adjacency caches across equal frames, exported `clear!` from `AletheiaData`, and documented the Julia ownership contract.
- Sealed interned formula arenas against node replacement, released prepared scalar and frame cache state with its owning records, synchronized aggregate memo reads, and corrected the SoleData scalar bridge and cache documentation.

- Closed recursive ownership escapes for `Core.SimpleVector`, dimensional interval providers, and prepared scalar data. Interval inputs and scalar relation indexes are frozen, aggregate memos and frame adjacency live only in evaluator-side caches, and fieldless mutable values are refused.
- Enforced one recursive ownership predicate and snapshot across semantic constructors, including nested immutable wrappers and typed field paths; scalar callback results are copied, audit fidelity covers the selected population, and benchmark measurement aggregation and provenance links are checked.
- Removed string and function ownership exemptions. The recursive walk now inspects concrete string wrappers and captured callback fields, and refuses snapshot replacements that would change an immutable wrapper's lookup identity.

- Rejected mutable opaque values at owned semantic boundaries with `OwnershipError`, added inner constructors for frame, model, provenance, graph, and distribution-program records, and made dictionary Model routes and provenance snapshots use immutable storage. Timed-out benchmark cells now make the run non-publishable and record the incomplete status.

- Replaced retained semantic collections with immutable storage and kept mutable frame caches explicitly internal. Frame relations, valuations, scalar values, audit payloads, graph paths, circuit nodes, algebra tables, and choice alternatives now snapshot inputs at construction; family callback reuse preserves world identity.

- Applied one defensive-copy rule at public boundaries, including certified circuit nodes, finite algebra tables, extracted outputs, nested audit material, graph records, and scalar stores. Mutable numeric cycles are rejected, data-only traces replay after serialization, and callable artifacts are rejected at serialization with a documented portability limit.

- Closed the finite-value, numeric-normalization, ownership, replay-authentication,
  and representation-symmetry boundaries with cycle-safe checks, immutable audit
  sequences, finite label scaling, and typed mixed-family rejection.

- Exact rational WMC now uses an unbounded carrier and tuple normalization for Float64 weights; neural extraction canonicalizes leaves through the validated algebra path; mutable callback values and graph metadata are owned at their boundaries.
- Trace replay now requires artifact and graph context (including a graph hash), and `ModelFamily` rejects mixed truth algebras with a typed error.
- Fixed interval-subset benchmark relation bindings and kept deployed scale cases aligned through 128 instances.


- Closed adversarial contract gaps: finite-carrier validation now rejects invalid and Boolean indices; neural extraction shares encoder dispatch with verification; uncovered outputs fail verification; circuit programs reject non-ground, cyclic, and non-closing values; Float64 weights convert through the exact rational profile with typed closure checks; the declared neural algebra validates round trips; metric scopes and permutation-invariant perturbation stability are explicit; graph traces replay against their recorded graph; audit input/state hashes are named separately; scalar world domains are checked during preparation; graph endpoints require full identity; benchmark scales, seeds, and relational-precompute settings match their provenance; and trace omission is honored.
- Updated audit, circuit, neural, showcase, benchmark, and provenance documentation to describe these boundaries; source links track `main` by design as stated in the development guide.

- Corrected documentation paths, profiler line references, compatibility
  normalization claims, and the description of Documenter page-size thresholds
  to match the current package layout and implementation.
- Added a one-dataset showcase bundle with a committed synthetic dataset, pinned seed, scalar and crisp decision-list checks, a validated finite many-valued reading, certified distribution-semantics circuits with a total-choice oracle, typed graph paths with provenance replay, and exact neural-symbolic extraction with audit metrics and hashes.

- Standardized documentation notation and formatting: unified transition arrows to `→` throughout prose and tables, normalized table unit conventions (plain integers with thousands separators for allocations, exact byte conversions with thousands separators for memory, and three-decimal milliseconds for times), added a Notation specification in development docs, ensured benchmark tables reference artifact files and gate lines, aligned canonical terminology (`fresh-dataset churn`, `warm reuse`, `first use`, `scalar-data layer`, `callback path`, `knowledge graph`, `distribution semantics`), sentence-cased headings, and added section-scoped package cross-references.
- Documented every public export with a runnable `jldoctest` example.
- Added focused `AletheiaAudit` and `AletheiaNeSy` packages. Audit artifacts emit
  deterministic replayable traces and applicability-aware metrics; the neural
  interface validates callable network leaves and supports exact finite
  symbolic round trips. Semantic loss remains disabled until a sound gradient
  profile exists.
- Reframed the documentation around the shared pooled syntax DAG and
  evaluation walk, with package-specific readings for truth algebras,
  distribution-semantics circuits, scalar data, typed graphs, audit traces,
  and the neural-symbolic boundary. Reorganized navigation by package
  dependency order and added the one-engine overview.

- Reduced fresh-dataset batch evaluation churn by reusing the pooled union-DAG
  plan, preserving relation-cache visibility, and reusing vectorized callback
  buffers for prepared decision-list apply.
- Scalar data preparation now shares equal world/relation frame objects across
  instances, so family evaluation can reuse the pooled evaluation plan.

- Added the focused `AletheiaCircuits` package for finite distribution
  semantics: normalized independent choices, ground acyclic rules, certified
  reduced ordered event diagrams, and separate Float64/Rational WMC and
  conditional-probability evaluation. Unsupported features and zero-mass
  evidence are rejected with typed errors.

- Reshaped the repository into the umbrella `Aletheia` package and the focused
  `AletheiaCore`, `AletheiaData`, `AletheiaLearn`, `AletheiaSole`,
  `AletheiaCircuits`, and `AletheiaGraphs` packages.
  The umbrella keeps the historical public API; `SoleLogics` is owned by
  `AletheiaSole` and remains available as `Aletheia.SoleLogics`.
- Added an implicit default-pool path. `atom(value)`,
  `branch(connective, children...)`, and `parse(Formula, source)` use
  `DEFAULT_POOL`, a single pool over `DEFAULT_SIGNATURE` (`¬`, `∧`, `⊗`, `∨`,
  `→`), and connective values are callable on pooled formulas so `p ∧ q` and
  `¬p` form branches directly. Both are opt-in per call site; the explicit
  `Signature`/`FormulaPool` path is unchanged, and connectives outside the
  default signature or children from another pool raise an `ArgumentError`.
- Added syntax-first pooled formulas, parsing, printing, and connective traits.
- Added truth algebras and finite FLew algebras, including non-chain families.
- Added relational frames, models, compound evaluation, Compass and RCC
  relation families, generated dimensional frames, and frame-condition traits.
- Added theory utilities including standard translation, bisimulation and
  contraction, plus ILP foundations and a dataset protocol.
- Added an opt-in SoleLogics compatibility layer, including many-valued
  compatibility adapters.
- Added runnable examples, structured documentation, and reproducible
  differential and performance benchmark harnesses.
- Fixed the canonical interval fast path for `Topo_DR`, which enumerated some
  targets twice.
- `inverse(MINIMUM)`, `inverse(MAXIMUM)`, and `inverse(tocenterrel)` now throw
  an `ArgumentError` explaining why instead of returning a relation that is not
  their converse. `MINIMUM` and `MAXIMUM` relate every source to one fixed
  boundary world, so their converse is not a value this vocabulary names, and
  `tocenterrel` has no source/target predicate at all.
- Added generated-input relation properties covering the converse law,
  involution, Allen/RCC8 JEPD, fast-path/predicate agreement, and the IA3/IA7
  coarsening unions.
- Added `AletheiaGraphs`, a provenance-preserving typed knowledge-graph adapter
  for Aletheia frames, models, paths, subgraphs, and crisp/fuzzy concept
  extensions.
