# Aletheia/SoleLogics measurement harness

This human-run benchmark measures syntax, evaluation, dimensional Allen
relations, finite-valued evaluation, learning from interpretations, package
loads, and bisimulation-contraction amortisation. It is not run in CI because
shared-runner timings are noisy.

## Reproduce

From a fresh checkout, set the SoleLogics checkout and run one command:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

The harness pins BLAS to one thread and records that setting. At the end it
compares the maximum recorded load (including `seed_loads`) and the load rise
against midpoints derived from the recorded quiet and contaminated runs. A
failed load gate or child case writes a prominent refusal marker, exits non-zero,
and must not be published. For a local inspection of load contention only, use
`--allow-contended`; it still stamps the artefact non-publishable and never
overrides a failed child case.

The default quick run sweeps five seeds (`0xA1E7_2024`, `0x5EED_2025`,
`0xC0FF_EE42`, `0x1234_5678`, and `0x9ABC_DEF0`) and keeps 200 paired
samples per seed;
`--deep` expands formula/model/ratio sweeps. Each section and side runs all its
cases in one warmed Julia child; GNU `timeout` kills the section at the printed
hard bound, and timeout/failed cells remain visible in the report. Every
sample pairs its allocation count with the sample nearest the median time.
The process writes raw values and provenance (Julia/CPU, load average, mode,
seed set, uptime at start and end, and per-cell sample counts) to `data/benchmark-run/run.txt`.

Published rows expose the observed per-seed spread. Per-row samples are not
reduced. The benchmark interleaves and rotates seeds within each warmed section.

`benchmark/differential.jl` is the deterministic correctness comparison:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/differential.jl
```

The contraction gate runs before timing and compares every tested formula and
world against its quotient. SoleLogics has no contraction API and is
reported unsupported rather than assigned a ratio. The extension row compares
Aletheia's BitVector extension with SoleLogics' equivalent all-world check loop,
which is the same semantic question even though SoleLogics has no named
`extension` method. The SoleLogics loop shares one subformula memo per timed
invocation and disables normalization; allocations are paired with median-time
samples.

## SoleData dataset protocol

The experiment is benchmark-only, but it exercises the production optional
SoleData extension: it creates a temporary Julia environment, develops the
local Aletheia checkout and the read-only SoleData checkout into that
environment, and loads `AletheiaSoleDataExt` only when SoleData is present.

```sh
SOLEDATA_PATH=/path/to/SoleData julia --startup-file=no benchmark/dataset_protocol.jl
```

The command runs the agreement gate before timing, then writes the fixed-seed
explicit sweep to `data/soledata-protocol/run.txt`.  To measure the real
consumer path (default full plus one-step memosets), run:

```sh
SOLEDATA_PATH=/path/to/SoleData julia --startup-file=no benchmark/dataset_protocol_supported.jl
```

That follow-up writes `data/soledata-protocol/run-supported.txt` and reports
both cold first-check and warm repeated-check medians.  The report is
`data/soledata-protocol/report.md`.  Both scripts' child-process sections use
GNU `timeout`, temporary files, medians, and allocation counts; no benchmark
output is piped.

## Deployed-model apply-path protocol

`benchmark/deployed_apply.jl` measures a trained `ModalDecisionTrees` model and
its translated `SoleModels.DecisionList` against the same supported dataset,
formula roots, and world order. It develops Aletheia, SoleLogics, SoleData,
SoleModels, and ModalDecisionTrees into a temporary environment; no dependency
checkout is modified. Set all package paths before running:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl \
SOLEDATA_PATH=/path/to/SoleData.jl \
SOLEMODELS_PATH=/path/to/SoleModels.jl \
MODALDECISIONTREES_PATH=/path/to/ModalDecisionTrees.jl \
julia --startup-file=no --project=benchmark benchmark/deployed_apply.jl
```

The deterministic gate in `benchmark/deployed_apply_differential.jl` runs before
any timing. It compares world extensions and per-instance antecedent masks for
scalar and vectorized `ValuationCallback`s, then compares predictions from the
deployed modal tree, native decision list, and both Aletheia callbacks. The
Sole formula row measures `SoleData.check` with full and one-step memoization;
the deployed modal-tree row measures `ModalDecisionTrees.apply`'s direct
`modalstep`/`checkcondition` path, which bypasses formula memos; the decision-list
row measures `SoleModels.apply` through `SoleLogics.check`.

Each section records uptime before and after timing. Children run at nice level
15 with `OPENBLAS_NUM_THREADS=1` and `JULIA_NUM_PRECOMPILE_TASKS=2`. Construction,
first use, warm reuse, and fresh-dataset churn are separate phases. Aletheia
frame/model-family conversion is measured separately and excluded from steady
apply. A failed quiet-machine or parity gate makes the artifact
non-publishable. Raw results and package paths/versions belong in
`data/benchmark-run/deployed-apply.txt`. The scale sweep uses 32, 64, 128, 256, and 512 instances with 8 points.
Each child has a 6 GB resident-memory cap and a 900-second section bound;
memory- and time-limited cases are recorded as skipped with their peak RSS.
The artifact also contains cold one-iteration allocation attribution profiles
for the callback, native decision list, and dense-store path.

## SoleModels consumer comparison

This experiment is a narrow consumer comparison: it compares the installed
`SoleModels.checkantecedent(rule, X)` path with a disposable copy whose
`checkantecedent` builds an Aletheia model family and evaluates the antecedent
through `extension`.  The source package and installed checkout are never
modified.  Set both checkout paths and run from the Aletheia root:

```sh
SOLEDATA_PATH=/path/to/SoleData \
SOLEMODELS_PATH=/path/to/SoleModels \
julia --startup-file=no --project=. benchmark/dataset_consumer.jl
```

The script creates baseline and Aletheia-backed SoleModels copies under a temporary
subdirectory of this checkout, runs a seeded mask gate first, then starts one
warmed child per side under GNU `timeout`.  Child output and timeout handling
use files, not pipes; the raw sweep is written to
`data/solemodels-consumer/run.txt`.  The timing worker reports three labelled
phases: first use on genuinely new datasets, steady state after cache
population, and repeated fresh-dataset churn.  Its allocation and byte fields
come from the sample nearest the median time, not BenchmarkTools' minimum over
an unspecified sample set; sample ranges and GC time are retained.  The temporary copies and
environments are removed on exit.  For run-order diagnostics, set
`DATASET_CONSUMER_CASE_ORDER` to a comma-separated permutation of `1:18`; the
case seeds and shapes remain unchanged while the timing order is recorded in
the result header.  No SoleData dependency is added to Aletheia itself.
