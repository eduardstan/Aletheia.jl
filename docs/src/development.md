# Development and validation

Run these commands from the repository root. `AletheiaCore` has no runtime
dependencies; the test, documentation, benchmark, formatting, and coverage
environments are separate Julia projects. The first invocation of each command
may spend extra time resolving and precompiling Julia packages.

On Julia 1.10, prepare the unregistered local package dependencies first (this
is harmless on newer Julia versions):

```sh
julia --project=. scripts/bootstrap.jl
```

## Package tests

Run the focused suites when working on one layer:

```sh
julia --project=lib/AletheiaCore -e 'using Pkg; Pkg.test()'
julia --project=lib/AletheiaData -e 'using Pkg; Pkg.test()'
julia --project=lib/AletheiaLearn -e 'using Pkg; Pkg.test()'
julia --project=lib/AletheiaSole -e 'using Pkg; Pkg.test()'
julia --project=lib/AletheiaCircuits -e 'using Pkg; Pkg.test()'
```

Then run the umbrella suite to verify the historical top-level API:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

A passing umbrella run ends with:

```text
Aletheia tests passed
```

It includes Aqua/JET checks and the runnable examples. `AletheiaSole` owns
`SoleLogics`, so compatibility code is imported as `using AletheiaSole.SoleLogics`
(or, through the umbrella, `using Aletheia.SoleLogics`).

## Coverage

Run coverage for each implementation package, then enforce the repository-wide
95% line floor:

```sh
for package in AletheiaCore AletheiaData AletheiaLearn AletheiaSole AletheiaCircuits; do
  julia --project=lib/$package -e 'using Pkg; Pkg.test(coverage=true)'
done
julia --project=coverage -e 'using Pkg; Pkg.instantiate(); include("coverage/check.jl")'
```

!!! tip
    Do not assume a quiet Julia process is hung.

## Formatting

Julia source uses [JuliaFormatter](https://github.com/domluna/JuliaFormatter)
with the repository settings in `.JuliaFormatter.toml`:

```sh
julia --project=format -e 'using JuliaFormatter; format(["src", "lib", "test", "benchmark", "examples", "docs"])'
```

Review the resulting diff before committing. The formatting environment is
kept separate from the runtime packages.

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
