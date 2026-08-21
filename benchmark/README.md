# Aletheia/SoleLogics measurement harness

This human-run benchmark measures syntax, evaluation, dimensional Allen
relations, finite-valued evaluation, learning from interpretations, package
loads, and bisimulation-contraction amortisation. It is not run in CI because
shared-runner timings are noisy.

## Reproduce

From a fresh checkout, set the incumbent checkout and run one command:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

The default quick run uses fixed seed `0xA1E7_2024`, five median samples, and
bounded sweeps. `--deep` expands formula/model/ratio sweeps. Each section and
side runs all its cases in one warmed Julia child; GNU `timeout` kills the
section at the printed hard bound, and timeout/unavailable cells remain visible
in the report. The process writes no benchmark result files: copy the terminal
table to `docs/src/results.md` when publishing a run.

`benchmark/differential.jl` is the deterministic correctness comparison:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/differential.jl
```

The contraction gate runs before timing and compares every tested formula and
world against its quotient. The incumbent has no contraction API and is
reported unsupported rather than assigned a ratio. The extension row compares
Aletheia's BitVector extension with SoleLogics' equivalent all-world check loop,
which is the same semantic question even though the incumbent has no named
`extension` method.
