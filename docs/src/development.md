# Development and validation

These commands are intentionally explicit. Run them from the repository root; the
first invocation may spend extra time resolving and precompiling Julia packages.

## Package tests

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

A passing run ends with:

```text
Aletheia tests passed
```

On the launch machine (Julia 1.12.7, 12 threads), this took **8m29s** wall
clock. It includes Aqua/JET checks and the runnable examples; do not assume a
quiet Julia process is hung.

## Documentation and doctests

```sh
julia --project=docs docs/make.jl
```

Look for both of these markers:

```text
Info: Doctest: running doctests.
Info: ... RenderDocument: rendering document.
```

The citation-aware build took **3m20s** on the launch machine. It may create a
local `docs/Manifest.toml`; that machine-specific file is not committed.

## Benchmarks

Start with the bounded smoke path. It prints progress and a table without
waiting on the incumbent comparison:

```sh
julia --project=benchmark benchmark/run.jl --smoke
```

The final lines include:

```text
benchmark smoke: PASS
suite | SoleLogics median | Aletheia median
```

On the launch machine, the first smoke run took **1m13s** (including a cold
benchmark environment setup); the next run took 45s on the same checkout. These
timings depend heavily on Julia precompile state. It deliberately
skips interval, theory, and cold-subprocess rows, which remain in the full run. For the complete measurement harness, use:

```sh
julia --project=benchmark benchmark/run.jl
```

It prints `[case] ...` before every guarded case and always prints its table,
even when an incumbent case is recorded as `>10s (not sampled)`. The full run is
measured in minutes, not seconds: the previous launch-machine attempt reached
10m without a table because an incumbent case was still inside its guard. The
per-case progress and final report now make that wait visible; use `--deep` only
for a deliberately slower diagnostic run.

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

The measured differential run took **1m46s** on the launch machine. It is
deterministic for that seed and is separate from `Pkg.test()` so Aletheia does
not acquire SoleLogics as a package dependency.
