# Development and validation

Run these from the repository root. The first invocation of each spends extra
time resolving and precompiling Julia packages.

Timings below were measured on a 12-thread Alder Lake laptop running Julia
1.12.7; treat them as an order of magnitude, not a target. The package has no
runtime dependencies, but the test, documentation, benchmark, and coverage
environments are separate Julia projects.

## Package tests

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

A passing run ends with:

```text
Aletheia tests passed
```

This took **8m29s** wall clock. It includes Aqua/JET checks and the runnable
examples.

!!! tip
    Do not assume a quiet Julia process is hung.

## Documentation and doctests

```sh
julia --project=docs docs/make.jl
```

Look for both of these markers:

```text
Info: Doctest: running doctests.
Info: ... RenderDocument: rendering document.
```

The citation-aware build took **3m20s**. It may create a
local `docs/Manifest.toml`; that machine-specific file is not committed.

## Benchmarks

Start with the smoke run. It exercises the harness and prints a table in about
a minute, skipping the slowest SoleLogics comparisons:

```sh
julia --project=benchmark benchmark/run.jl --smoke
```

The final lines include:

```text
benchmark smoke: PASS
suite | SoleLogics median | Aletheia median
```

The first smoke run took **1m13s** (including a cold benchmark environment
setup); the next run took 45s on the same checkout. These timings depend
heavily on Julia precompile state. The smoke run deliberately skips interval,
theory, and cold-subprocess rows, which remain in the full run. For the
complete measurement harness, use:

```sh
julia --project=benchmark benchmark/run.jl
```

The full run prints `[case] …` before each case and always prints its table,
even when a SoleLogics case times out and is recorded as `>10s (not sampled)`.
Expect tens of minutes; the per-case progress lines let you tell a slow case
from a hang. Use `--deep` only for a deliberately slower diagnostic run.

## Differential correctness

This command requires a SoleLogics checkout. Set `SOLELOGICS_PATH` if it is not
at the default path:

```sh
julia --project=benchmark benchmark/differential.jl
```

A passing run ends with:

```text
differential: PASS (64 formulas; seed 2716278820)
```

The measured differential run took **1m46s**. It is deterministic for that
seed and is separate from `Pkg.test()` so Aletheia does not acquire SoleLogics
as a package dependency.
