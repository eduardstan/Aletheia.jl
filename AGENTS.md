# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Syntax layer

- The syntax implementation lives in `src/syntax.jl` and `src/parse.jl`; it is deliberately semantic-free.
- Validate both package tests and the citation-aware docs build with `julia --project=. -e 'using Pkg; Pkg.test()'` and `julia --project=docs docs/make.jl`.
- Every worked example under `docs/src/` is a script-style `jldoctest` block, so the docs build verifies its output. Regenerate expected output by running `makedocs` with `doctest = :fix` from a copy of `docs/make.jl` placed inside `docs/`; never hand-write it. A block whose expected output is empty is not fixed correctly and needs a manual pass.
- CI enforces source line coverage with `julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'` followed by `julia --project=coverage -e 'using Pkg; Pkg.instantiate(); include("coverage/check.jl")'`; do not commit generated `.cov` or manifests.

## Modal breadth

- Relation values and their generic `relation_holds` protocol live in `src/relations.jl`; generated interval/rectangle/point constructors live in `src/dimensional.jl`, and frame-condition traits/axiom schemas live in `src/frameclasses.jl`.
- Generated interval frames use a private canonical relation provider and direct adjacency construction for `BEFORE`; arbitrary relation families retain the lazy predicate fallback. IA3/IA7 and RCC5 memberships follow SoleLogics' definitions and are exhaustively checked in `test/relations.jl`.
- `_IntervalSuccessors` (`src/dimensional.jl`) enumerates boundary-index pairs `(k, l)`; modes 1 and 4 span a full `k x l` block and are only valid when `lfirst > klast`, otherwise they enter cells with `l <= k` and emit the preceding interval twice. Mode 0 (triangle from `k + 1`) is the safe choice when the target block overlaps the diagonal.
- `inverse` is contractually the converse; a relation whose converse this vocabulary does not name throws an `ArgumentError` naming the reason (`MINIMUM`, `MAXIMUM`, `tocenterrel`), while an unknown relation still hits the generic `MethodError` fallback. `test/relation_properties.jl` holds the generated-input relation laws (converse, involution, JEPD, fast path versus predicate, IA3/IA7 unions) and picks up newly exported relation values automatically.
- Dimensional constructors return the existing `Frame` with a callable accessibility provider; `src/evaluation.jl` recognizes the private interval provider for direct `BEFORE` adjacency while retaining generic fallback. RCC8 and RCC5 are available topological fragments.

## Presentation layer

- `src/display.jl` holds the shared rich-display conventions (bold header, dim section labels, `:color`/`:limit` handling, elision helpers); every `MIME"text/plain"` method in `src/` uses them.
- Finite algebra carriers are one-based `UInt8` indices, never shown as such: `Aletheia.truthlabel` maps them to `⊥`, `α`, `β`, …, `⊤`. `test/presentation.jl` pins the exact plain-text output.
- `Aletheia.SoleLogics.ManyValuedLogics`' algebra view deliberately keeps SoleLogics' payload (boxed domain, raw carrier tables) for migration parity; only its presentation follows the conventions above.

## Semantics layer

- `src/semantics.jl` is the authoritative layer for `TruthAlgebra`, `Frame`, `Model`, and atom-only `interpret`; `src/evaluation.jl` provides the shared DAG walk for `check` and `extension`.
- Semantics and evaluation tests live in `test/semantics.jl` and `test/evaluation.jl`; validate package tests, coverage, and docs with the commands above.
- Finite FLew tables and named non-chain algebras live in `src/algebras.jl`; their integer carrier is one-based `UInt8` and construction derives implication while validating all axioms. `test/algebras.jl` is the source-table and differential specification.

- Theory APIs live in `src/firstorder.jl`, `src/bisimulation.jl`, `src/normalforms.jl`, and `src/prover.jl`; `test/theory.jl` covers their Boolean/classical boundaries. The first-order bridge and normal forms deliberately do not implement a prover or many-valued classical equivalence.
- The human benchmark's theory row is in `benchmark/run.jl`; its output records whether quotient construction amortizes, rather than assuming contraction wins.
- The human benchmark's default is a five-seed sweep with 200 paired samples per seed; `data/benchmark-run/run.txt` is the provenance for the published `docs/src/results.md` rows.

## Migration layer

- `src/compatibility.jl` defines the nested opt-in `Aletheia.SoleLogics` vocabulary; the derived consumer inventory, mappings, deliberate gaps, and consumer-trial evidence live in `docs/src/compatibility.md`.
- `SoleLogics.ManyValuedLogics` finite tableau names are boundary adapters there: `FiniteTruth` retains the incumbent indexed object while `FiniteFLewAlgebra` delegates tables to Aletheia's unboxed `UInt8` algebras.
- Leftmost containers, `Literal`, alphabets and `randformula` live only in `src/compatibility.jl`: they subtype `Aletheia.Formula` (as `Truth` already did) but are never interned in a pool, and every semantic operation goes through `tree`. Random generation deliberately takes the caller's RNG, because adding `Random` would end the core's zero-dependency property.
- `docs/src/compatibility.md` classifies the remaining consumer gaps into SoleLogics surface, SoleData/SoleModels concerns, and maintainer decisions; check it before adding a name a learner appears to need.
- A truth constant inside a formula is an ordinary pool payload, but every compatibility accessor must hand it back as the `Truth` (`_wrap_id` in `src/compatibility.jl`). Consumers dispatch on the child object's type, so returning an `Atom` there silently changed SoleReasoners' SAT verdicts; `test/compatibility.jl` pins the invariant.

## ILP foundations

- Clauses, θ-subsumption, lazy refinement operators, and learning-setting example wrappers live in `src/ilp.jl`; the reference terminology and properties are documented in `docs/src/index.md` with `muggleton1994`. `test/ilp.jl` covers the recursive implication counterexample and quasi-order boundaries.

- The public documentation is written for an outside reader: no internal work-lane vocabulary (stage names, "incumbent", "scratch", "routed"), and SoleLogics is always named rather than alluded to.
- The optional SoleData model-family bridge lives in `ext/AletheiaSoleDataExt.jl`; `benchmark/dataset_protocol.jl` uses a temporary environment and read-only SoleData for its differential gate, with results and decision evidence in `data/soledata-protocol/report.md` and `run.txt`.
- Stage-2a SoleModels consumer routing remains benchmark-only: `benchmark/dataset_consumer.jl` builds disposable package copies; the corrected first-use/steady/churn method, paired allocations, load records, and mask gates live in `data/solemodels-consumer/report.md` and `corrected-repetitions/`.
- Relation adjacency is cached on `Frame` and shared by models that reuse that frame; the cache remains valuation-independent and non-uniform consumer frames are not coalesced (`src/semantics.jl`, `benchmark/dataset_consumer_route.jl`).
