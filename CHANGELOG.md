# Changelog

All notable changes to Aletheia are documented here. The umbrella and focused packages are currently
pre-release (`0.2.0-DEV`), so there is no released version yet.

## Unreleased

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
