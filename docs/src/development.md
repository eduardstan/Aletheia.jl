# Development and validation

Run these from the repository root. The package has no runtime dependencies,
but the test, documentation, benchmark, and coverage environments are separate
Julia projects. The first invocation of each command may spend extra time
resolving and precompiling Julia packages.

## Package tests

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

A passing run ends with:

```text
Aletheia tests passed
```

It includes Aqua/JET checks and the runnable examples.

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

It may create a local `docs/Manifest.toml`; that machine-specific file is not
committed.

## Benchmarks

The benchmark is a human-run comparison against a local SoleLogics checkout. Run
its quick suite with:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

Use `--deep` for the expanded, slower sweeps. The run writes raw values and
provenance (including load average and per-cell sample counts) to
`data/benchmark-run/run.txt`; measured, timed-out, and failed cells remain visible in the
terminal report. Failed child cases make the run non-publishable. The complete
measurement harness can take tens of minutes.

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

It is deterministic for that seed and is separate from `Pkg.test()` so Aletheia
does not acquire SoleLogics as a package dependency.
