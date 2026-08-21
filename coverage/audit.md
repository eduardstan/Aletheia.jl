# Coverage audit

The audit was regenerated from the clean package test run with
`julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'` and
`julia --project=coverage -e 'using Pkg; Pkg.instantiate(); include("coverage/check.jl")'`.
The result is **1631/1682 (96.97%)**. The prior genuine misses in
`src/dimensional.jl:39-40` (rectangle-relation display/equality) and
`src/relations.jl:249` (identity display) are covered behaviorally by
`test/relations.jl`. The remaining zero-count lines are exercised
behaviourally but are not credited by Julia's line counter.

## Julia coverage blind spots (all remaining zero-count lines)

The one-line methods below are inlined before CoverageTools can attach a
counter; the fallback methods are exceptional paths whose throw sites are not
credited by the counter.

### `src/relations.jl`

- **20-21** — Generic `relation_holds` fallback and its `MethodError` throw are
  exercised by the fallback tests.
- **35-36** — Generic `inverse` fallback and its `MethodError` throw are
  exercised by the fallback tests.
- **44** — Identity `relation_holds` is exercised by identity relation tests;
  the one-line method is inlined.
- **127-140** — Allen and identity relation names are exercised through display
  and parser tests; these one-line methods are inlined.
- **243-256** — Point and RCC relation names are exercised through display
  tests; these one-line methods are inlined.

### `src/semantics.jl`

- **79-80, 170-171, 182-183** — Boolean, Gödel, and Łukasiewicz top/bottom
  methods are exercised directly and through evaluator tests; one-line methods
  are inlined.
### `src/syntax.jl`

- **311, 356-357, 360-361** — Atom/branch child and kind predicates are
  exercised by syntax API tests; one-line methods are inlined.
- **536-537, 540-541** — Cross-kind equality methods are exercised by syntax
  tests; one-line methods are inlined.

### `src/normalforms.jl`

- **10** — The normal-form connective helper is exercised through CNF/DNF
  tests; the one-line method is inlined.

### `src/prover.jl`

- **31-32** — The abstract prover boundary's default methods are exercised by
  proof-search edge tests; exceptional fallback lines are not credited.
