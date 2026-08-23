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

## SoleData dataset-protocol stage 1

The real-dataset experiment is deliberately benchmark-only: it creates a
temporary Julia environment, develops the local Aletheia checkout and the
read-only SoleData checkout into that environment, and leaves the core
`Project.toml` unchanged.

```sh
SOLEDATA_PATH=/path/to/SoleData julia --startup-file=no benchmark/dataset_protocol.jl
```

The command runs the agreement gate before timing, then writes the fixed-seed
explicit sweep to `data/al-dataset-protocol/run.txt`.  To measure the real
consumer path (default full plus one-step memosets), run:

```sh
SOLEDATA_PATH=/path/to/SoleData julia --startup-file=no benchmark/dataset_protocol_supported.jl
```

That follow-up writes `data/al-dataset-protocol/run-supported.txt` and reports
both cold first-check and warm repeated-check medians.  The report is
`data/al-dataset-protocol/report.md`.  Both scripts' child-process sections use
GNU `timeout`, temporary files, medians, and allocation counts; no benchmark
output is piped.

## SoleModels consumer stage 2a

This experiment is the narrow consumer trial: it compares the installed
`SoleModels.checkantecedent(rule, X)` path with a disposable copy whose
`checkantecedent` builds an Aletheia model family and evaluates the antecedent
through `extension`.  The source package and installed checkout are never
modified.  Set both checkout paths and run from the Aletheia root:

```sh
SOLEDATA_PATH=/path/to/SoleData \
SOLEMODELS_PATH=/path/to/SoleModels \
julia --startup-file=no --project=. benchmark/dataset_consumer.jl
```

The script creates baseline and routed SoleModels copies under a temporary
subdirectory of this checkout, runs a seeded mask gate first, then starts one
warmed child per side under GNU `timeout`.  Child output and timeout handling
use files, not pipes; the raw sweep is written to
`data/al-dataset-consumer/run.txt`.  The timing worker reports three labelled
phases: first use on genuinely new datasets, steady state after cache
population, and repeated fresh-dataset churn.  Its allocation and byte fields
come from the sample nearest the median time, not BenchmarkTools' minimum over
an unspecified sample set; sample ranges and GC time are retained.  The
corrected repeated artifacts are under
`data/al-dataset-consumer/corrected-repetitions/`.  The temporary copies and
environments are removed on exit.  For run-order diagnostics, set
`DATASET_CONSUMER_CASE_ORDER` to a comma-separated permutation of `1:18`; the
case seeds and shapes remain unchanged while the timing order is recorded in
the result header.  No SoleData dependency is added to Aletheia itself.
