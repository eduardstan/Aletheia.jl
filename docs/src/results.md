# Measured results

The tables in this page are historical measurements, not claims about the
current checkout. The primary synthetic tables were measured at commit
`6ebaa998d00e8d4b172c7142fc0c9fbc81298f5e` on 2026-08-31 on the `alderlake`
host. The cold package-load row from that artifact is retracted: it does not
match the current eight-package umbrella. Current paired measurements are
listed below with their exact provenance.

Reproducing these measurements needs a local checkout of SoleLogics, because
Aletheia deliberately does not depend on it:

```sh
git clone https://github.com/aclai-lab/SoleLogics.jl /tmp/SoleLogics.jl
SOLELOGICS_PATH=/tmp/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

The quick run uses Julia 1.12.7 with SoleLogics 0.13.7 and five
seeds (`0xA1E7_2024`, `0x5EED_2025`, `0xC0FF_EE42`, `0x1234_5678`,
`0x9ABC_DEF0`). It retains **200 paired samples per seed** (2000 for
contraction), and prints the seed set, paired medians, allocation counts, and
correctness gate. Sampling is paired and interleaved, with seed order rotated
between rows. Per-seed load readings are retained in the raw run artefact.

Each section runs in a warmed child Julia process; GNU `timeout` kills a section
at the printed hard bound (120 s quick, 180 s deep). `--deep` expands the size
and ratio sweeps. A timeout is reported as data, not silently dropped. Cold-load rows are measured in fresh processes.
The load and failure gates passed for the historical artifact. All quick rows, including interval subset RCC5, measured across five seeds; no row timed out. These results must not be read as current performance claims.
The ratio is SoleLogics/Aletheia; allocations are `count / bytes`. Every ratio
cell shows the median, mean ± standard deviation, and the observed per-seed
range. The range is descriptive, not a confidence interval. `[no clear winner]`
means that the mean ± standard deviation band contains `1.00×`. The raw run is retained in
[`data/benchmark-run/run.txt`](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/run.txt),


## Current paired measurements

The audit measured the historical artifact commit against current main on the
same `alderlake` laptop using `nice -n 15`, one Julia process at a time, and
200-batch medians. The current side was commit `36c269e` on 2026-09-05. These
numbers are descriptive evidence for the regression and are not a benchmark
publication; they predate the fixes in this branch.

**Provenance:** audit section 4.4, script `evalmicro.jl`, host `alderlake`, measured 2026-09-05.

| measurement | `6ebaa998` (2026-08-31) | `36c269e` (2026-09-05) | current / artifact |
| --- | ---: | ---: | ---: |
| propositional depth-6 `check` | 43,060 ns | 187,800 ns | 4.4× slower |
| modal 32-world `check` | 10,974 ns | 112,961 ns | 10.3× slower |
| modal 32-world `extension` | 14,004 ns | 103,859 ns | 7.4× slower |
| `Frame` construction, 32 worlds | 12,445 ns | 207,971 ns | 16.7× slower |
| allocations per propositional check | 36,920 bytes | 67,704 bytes | 1.8× |
| allocations per modal check | 23,552 bytes | 108,048 bytes | 4.6× |

The office quick run for this branch is subject to the measurement law. If the
host is not quiet or the harness refuses publication, its refusal remains
provenance rather than a performance claim.

## How to read a row

The labels describe the inputs to the timed call. Unless a section says
otherwise, each seed contributes a median-time sample from 200 paired observations
in a warmed child Julia process; the displayed median, mean, and standard
deviation are across the seed medians. Its allocation count and bytes come from
the same observation. Construction, parsing, printing, checking, and extension setup
happen inside the timed call when the generator does so. Contraction rows use
2000 paired observations per seed for the crossover estimate. A ratio is always **SoleLogics divided by
Aletheia**: above `1×` means Aletheia took less time, below `1×` means it took
more time, and `1×` is parity. Ratio ranges are the observed per-seed minimum and
maximum, not confidence intervals. `[no clear winner]` marks only a ratio whose
mean ± standard deviation band contains `1.00×`. Allocation cells are ordered the
same way: **SoleLogics count / bytes ; Aletheia count / bytes**. They are not ratios.

* **Depth** is the maximum recursive level. The syntax, propositional, and
  many-valued rows use seed-specific full binary formulas with distinct atom
  occurrences; the shared construction row reuses each generated child in the
  Aletheia recipe. Modal rows use a seed-specific `random_recipe` with the
  indicated depth and modal operators. The same generated recipe is built on
  both sides for each seed.
* **Worlds** is the number of worlds in the finite model. `n` in an interval
  row is the coordinate-domain size used to generate all integer intervals
  (the frame therefore contains `n*(n+1)/2` worlds), not that world count.
  `chain n` is instead a formula with `n` nested negations over one atom.
* **Density** is the probability in `[0, 1]` used independently for each
  ordered pair of worlds when generating the directed `R` edges. Thus `.15`
  and `.50` mean 15% and 50% edge probability, not a percentage of worlds;
  the graphs use the seed-specific generated graph. In dataset rows, `uniform` means
  all instances share one generated graph; `non-uniform` means each instance
  gets its own graph.
* **Instances** is the number of dataset models evaluated by a consumer call;
  **rules** is the number of rules in that call, **points** is the number of
  data points used to make each interval frame, and **modal** (or modal target)
  is the probability/target used by that dataset generator. **Hypotheses** is
  the number of candidate formulas scored against the stated number of
  interpretations. In the contraction table, `original n`, `quotient q`, and
  `q/n` mean original worlds, quotient worlds, and their fraction; `K` is the
  number of formulas in a batch, and `C` is one contraction cost.

The rows below also state the operation on each side. This matters: an
identical semantic question can still have different APIs or setup costs, and
those cases are labelled rather than presented as like-for-like calls.

## Syntax and loading

The construction rows build the recipe above on each side: SoleLogics calls
`SyntaxBranch` recursively, while Aletheia inserts atoms and branches into a
`FormulaPool`. The parsing rows parse the same depth-2 text; printing
serializes the already-built depth-2 formulas; round-trip parses and then
serializes them. The equality row builds two `chain 16` formulas and calls
`isequal` (Aletheia builds both in one pool; SoleLogics builds two structural
values). The cold rows are different by design: each side is loaded in a fresh
process, once for package load and once for load plus parsing/printing one atom;
there is no allocation sample for those wall-clock measurements.

**Provenance:** commit `6ebaa998d00e8d4b172c7142fc0c9fbc81298f5e`, measured 2026-08-31 on `alderlake`.

| case | SoleLogics median (mean ± std) | Aletheia median (mean ± std) | ratio median (mean ± std, range) | allocations |
| --- | ---: | ---: | ---: | ---: |
| construction, depth 2 (unshared) | 5.40 μs (mean 5.18 μs ± 1.25 μs) | 2.01 μs (mean 2.28 μs ± 741.8 ns) | 2.36× (mean 2.37× ± 0.60×, range 1.56-3.08×) | 37 / 1,312 bytes ; 56 / 2,656 bytes |
| construction, depth 2 (shared) | 5.27 μs (mean 5.03 μs ± 1.31 μs) | 2.65 μs (mean 2.44 μs ± 474.6 ns) | 2.18× (mean 2.15× ± 0.79×, range 1.33-3.07×) | 37 / 1,312 bytes ; 50 / 2,256 bytes |
| parsing, depth 2 | 46.88 μs (mean 46.87 μs ± 6.22 μs) | 10.23 μs (mean 10.11 μs ± 1.84 μs) | 4.41× (mean 4.82× ± 1.35×, range 3.11-6.46×) | 295 / 12,608 bytes ; 62 / 3,760 bytes |
| printing, depth 2 | 11.72 μs (mean 14.95 μs ± 8.25 μs) | 4.02 μs (mean 4.61 μs ± 1.50 μs) | 2.92× (mean 3.07× ± 0.78×, range 2.30-4.26×) | 45 / 1,792 bytes ; 19 / 864 bytes |
| round-trip, depth 2 | 59.60 μs (mean 63.28 μs ± 12.66 μs) | 13.71 μs (mean 13.30 μs ± 2.48 μs) | 5.14× (mean 4.82× ± 0.89×, range 3.61-5.88×) | 340 / 14,400 bytes ; 81 / 4,624 bytes |
| `isequal`, chain 16 | 3.36 μs (mean 3.40 μs ± 533.6 ns) | 22.0 ns (mean 23.8 ns ± 7.8 ns) | 165.75× (mean 151.33× ± 38.20×, range 95.94-188.95×) | 32 / 1,504 bytes ; 0 / 0 bytes |
| cold time to first result | 3,464.170 ms (mean 3,431.090 ms ± 92.830 ms) | 1,216.440 ms (mean 1,219.820 ms ± 110.990 ms) | 2.69× (mean 2.83× ± 0.29×, range 2.53-3.22×) | —/— |

The retracted cold-load row is intentionally omitted. The load ratio in the
historical artifact was measured across fresh processes and is not attributed
to the evaluator. The equality ratio is the pool-local integer identity path versus
SoleLogics' structural comparison; it is not a claim that the APIs have the
same representation.

## Evaluation suites

The propositional rows build a seed-specific full binary tree and a one-world
Boolean model with one set per distinct leaf atom, then call one per-world check
on each side (`TruthDict` for SoleLogics; indexed `Model` and sets for Aletheia).
The extension rows use the same seed-specific formulas and parity-valued models over
empty 8-world or 32-world frames. Aletheia calls `extension` once, producing a
`BitVector`; SoleLogics calls `check` once for every world, with one shared
`use_memo` dictionary per timed invocation, and collects the answers. Both calls
disable normalization. **This is explicitly not a like-for-like API comparison:**
SoleLogics v0.13.7 has no `extension` method, so its side is the equivalent
all-world semantic loop, not a result SoleLogics does not support.

For each random-modal row, both the formula and directed graph are generated
from the row's seed; edges use the stated density. Both sides check the first
world, and normalization is disabled on the SoleLogics call. Atom valuations
are generated from the same seed and atom names on both sides. These are
finite-model evaluator samples over seed-specific formula shapes.

The dimensional rows construct the generated interval frame before timing.
Adjacency measures all source worlds and the `BEFORE`/`IA_L` successors;
`interval check` evaluates one diamond at the first world; IA3, IA7, and RCC5
measure all-source successor counts for their relation sets. Aletheia uses the canonical generated provider; SoleLogics uses its full
dimensional frame and enumerates `accessibles`. Both sides map targets through a
prebuilt world-position index (the canonical Aletheia `BEFORE` path uses an
arithmetic range and does not read that index). The follow-up `n=12,24,36`
sweep is the same adjacency operation.

The finite-valued rows build the same seed-specific depth-2 tree and one-world
finite model on each side, then ask the designated check question: SoleLogics
calls its finite-algebra check, while Aletheia checks its result against the
algebra's top value. G3 and Ł3 are three-valued chains; H4 is the shipped
four-valued non-chain algebra. The interpretation-learning row constructs four
seed-specific hypotheses and eight models (4–7 worlds, edge probability .35), then
scores all 32 hypothesis/interpretation pairs. SoleLogics stores model/world/
label tuples; Aletheia constructs `learning_from_interpretations` examples.
Example and hypothesis construction is outside the timed score loop, so this
is a paired score/evaluation hot path, not a comparison of learner
construction APIs. The ILP row is supported by the [raw benchmark artefact](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/run.txt):
it scores four hypotheses against eight seeded models (32 pairs; models have
4–7 worlds and edge probability .35).

**Provenance:** commit `6ebaa998d00e8d4b172c7142fc0c9fbc81298f5e`, measured 2026-08-31 on `alderlake`.

| case | SoleLogics median (mean ± std) | Aletheia median (mean ± std) | ratio median (mean ± std, range) | allocations |
| --- | ---: | ---: | ---: | ---: |
| propositional check, depth 2 | 3.06 μs (mean 3.12 μs ± 869.1 ns) | 2.34 μs (mean 2.34 μs ± 300.7 ns) | 1.31× (mean 1.37× ± 0.49×, range 0.88-1.97×) [no clear winner] | 29 / 752 bytes ; 48 / 2,544 bytes |
| propositional check, depth 4 | 18.77 μs (mean 18.08 μs ± 1.39 μs) | 9.38 μs (mean 10.20 μs ± 2.20 μs) | 1.76× (mean 1.83× ± 0.35×, range 1.38-2.30×) | 155 / 4,208 bytes ; 159 / 9,296 bytes |
| propositional check, depth 6 | 70.55 μs (mean 71.26 μs ± 7.71 μs) | 34.69 μs (mean 38.00 μs ± 5.24 μs) | 1.81× (mean 1.91× ± 0.36×, range 1.53-2.34×) | 659 / 18,032 bytes ; 601 / 36,920 bytes |
| extension, 8 worlds / depth 3 | 44.51 μs (mean 47.41 μs ± 8.26 μs) | 10.97 μs (mean 12.35 μs ± 3.21 μs) | 3.91× (mean 3.94× ± 0.69×, range 3.26-5.03×) | 760 / 31,024 bytes ; 143 / 11,920 bytes |
| extension, 32 worlds / depth 4 | 220.31 μs (mean 220.72 μs ± 20.62 μs) | 120.05 μs (mean 131.10 μs ± 29.82 μs) | 1.88× (mean 1.74× ± 0.36×, range 1.22-2.11×) | 2,191 / 112,640 bytes ; 655 / 163,920 bytes |
| random modal, worlds=8 / 0.15 / depth=2 | 4.44 μs (mean 3.91 μs ± 2.70 μs) | 2.04 μs (mean 2.06 μs ± 650.6 ns) | 2.10× (mean 1.70× ± 0.85×, range 0.67-2.63×) [no clear winner] | 136 / 5,280 bytes ; 58 / 3,632 bytes |
| random modal, worlds=24 / 0.15 / depth=2 | 13.36 μs (mean 11.64 μs ± 5.18 μs) | 8.52 μs (mean 8.04 μs ± 3.35 μs) | 1.42× (mean 1.40× ± 0.39×, range 0.88-1.82×) | 264 / 13,616 bytes ; 128 / 20,592 bytes |
| random modal, worlds=8 / 0.5 / depth=2 | 4.62 μs (mean 4.86 μs ± 3.90 μs) | 3.34 μs (mean 3.03 μs ± 1.12 μs) | 1.38× (mean 1.40× ± 0.78×, range 0.67-2.58×) [no clear winner] | 138 / 5,312 bytes ; 58 / 3,632 bytes |
| random modal, worlds=24 / 0.5 / depth=2 | 18.32 μs (mean 17.69 μs ± 10.78 μs) | 12.99 μs (mean 11.62 μs ± 4.97 μs) | 1.42× (mean 1.38× ± 0.55×, range 0.47-1.92×) [no clear winner] | 264 / 13,920 bytes ; 128 / 20,592 bytes |
| random modal, worlds=8 / 0.15 / depth=4 | 12.71 μs (mean 13.20 μs ± 12.11 μs) | 3.31 μs (mean 3.27 μs ± 1.76 μs) | 3.84× (mean 3.24× ± 2.01×, range 0.69-5.21×) | 304 / 11,184 bytes ; 68 / 4,944 bytes |
| random modal, worlds=24 / 0.15 / depth=4 | 35.63 μs (mean 46.73 μs ± 46.80 μs) | 15.65 μs (mean 16.52 μs ± 10.80 μs) | 2.25× (mean 2.37× ± 2.40×, range 0.23-6.19×) [no clear winner] | 390 / 18,656 bytes ; 126 / 20,576 bytes |
| random modal, worlds=8 / 0.5 / depth=4 | 26.42 μs (mean 20.28 μs ± 16.11 μs) | 4.09 μs (mean 4.63 μs ± 3.91 μs) | 3.75× (mean 4.31× ± 3.08×, range 0.40-8.61×) | 307 / 11,536 bytes ; 68 / 4,944 bytes |
| random modal, worlds=24 / 0.5 / depth=4 | 44.96 μs (mean 55.93 μs ± 52.45 μs) | 15.03 μs (mean 13.58 μs ± 8.43 μs) | 2.99× (mean 3.21× ± 2.16×, range 0.35-5.85×) | 390 / 20,320 bytes ; 126 / 20,576 bytes |
| interval adjacency, n=6 | 2.17 μs (mean 2.05 μs ± 467.0 ns) | 1.27 μs (mean 1.17 μs ± 244.6 ns) | 1.77× (mean 1.75× ± 0.12×, range 1.61-1.92×) | 107 / 5,216 bytes ; 100 / 3,744 bytes |
| Allen BEFORE check, n=6 | 14.29 μs (mean 14.42 μs ± 263.2 ns) | 8.92 μs (mean 8.03 μs ± 1.52 μs) | 1.63× (mean 1.86× ± 0.40×, range 1.54-2.39×) | 230 / 33,008 bytes ; 176 / 22,640 bytes |
| interval subset IA3, n=6 | 78.64 μs (mean 81.12 μs ± 25.34 μs) | 9.85 μs (mean 9.26 μs ± 2.27 μs) | 7.45× (mean 9.57× ± 4.97×, range 4.79-17.32×) | 3,048 / 203,376 bytes ; 273 / 41,632 bytes |
| interval subset IA7, n=6 | 49.49 μs (mean 50.42 μs ± 7.57 μs) | 39.48 μs (mean 44.76 μs ± 21.52 μs) | 1.22× (mean 1.41× ± 0.78×, range 0.54-2.44×) [no clear winner] | 2,484 / 144,656 bytes ; 717 / 116,160 bytes |
| interval subset RCC5, n=6 | 111.43 μs (mean 108.43 μs ± 17.93 μs) | 57.30 μs (mean 58.17 μs ± 2.33 μs) | 1.81× (mean 1.87× ± 0.34×, range 1.40-2.29×) | 4,104 / 249,216 bytes ; 1,057 / 131,072 bytes |
| finite chain G3 check, depth 2 | 2.97 μs (mean 3.08 μs ± 357.2 ns) | 3.06 μs (mean 2.71 μs ± 603.8 ns) | 1.10× (mean 1.17× ± 0.19×, range 0.95-1.43×) [no clear winner] | 40 / 1,504 bytes ; 42 / 2,544 bytes |
| finite chain Ł3 check, depth 2 | 4.91 μs (mean 4.73 μs ± 398.2 ns) | 2.65 μs (mean 2.69 μs ± 217.1 ns) | 1.69× (mean 1.76× ± 0.19×, range 1.59-2.05×) | 40 / 1,504 bytes ; 42 / 2,544 bytes |
| non-chain H4 check, depth 2 | 3.73 μs (mean 3.52 μs ± 726.1 ns) | 2.31 μs (mean 2.27 μs ± 342.7 ns) | 1.60× (mean 1.54× ± 0.10×, range 1.40-1.63×) | 40 / 1,504 bytes ; 42 / 2,544 bytes |
| ILP interpretation scoring, 8 models / 4 hypotheses | 697.97 μs (mean 739.46 μs ± 228.09 μs) | 105.75 μs (mean 129.12 μs ± 42.33 μs) | 5.55× (mean 5.79× ± 0.93×, range 4.85-7.15×) | 8,872 / 339,424 bytes ; 2,056 / 133,920 bytes |

The extension comparison is explicitly an equivalent all-world check loop on
SoleLogics because it has no `extension` API; it is not labelled as a win over
an operation SoleLogics does not have. Modal formulas, graphs, and valuations
are regenerated for every seed; normalization is disabled to isolate evaluation.
The ILP row constructs seed-specific `learning_from_interpretations` examples
and scores hypotheses over all interpretations through the check/eval loop.

Aletheia evaluates each extension formula DAG once into a `BitVector`, while the
equivalent SoleLogics all-world loop performs one shared-memo evaluation per
invocation. Aletheia's relation adjacency is held in the weak evaluator-side registry keyed by
frame value equality after its first check, while SoleLogics rebuilds its structural memo per call. Thus the
modal rows are warm repeated-model measurements, not first-call comparisons; the
asymmetry is intentional and labelled.

### Why interval adjacency scales

A naive implementation compares every candidate world against the source
(`target.x > source.y`), which is an O(|W|) scan per source. Aletheia's
generated interval frames instead expose the successor set as an arithmetic
range, while `accessible` stays lazy. The effect grows with the domain size
(the quick n=6 row uses 200 samples; the deep-only sweep uses 500 samples):

**Provenance:** commit `20a9f78c5254aadd223435e028ca26e63de464ee`, measured 2026-08-26.

| n | SoleLogics | Aletheia | ratio | allocations (SoleLogics ; Aletheia) |
| ---: | ---: | ---: | ---: | ---: |
| 6 | 2.17 μs (mean 2.05 μs ± 467.0 ns) | 1.27 μs (mean 1.17 μs ± 244.6 ns) | 1.77× (mean 1.75× ± 0.12×, range 1.61-1.92×) | 107 / 5,216 bytes ; 100 / 3,744 bytes |
| 12 | 14.62 μs | 2.86 μs | 5.11× | 447 / 37,704 bytes ; 373 / 20,032 bytes |
| 24 | 204.31 μs | 29.34 μs | 6.96× | 2,048 / 468,760 bytes ; 1,462 / 165,352 bytes |
| 36 | 1.18 ms | 140.08 μs | 8.43× | 5,066 / 1,804,608 bytes ; 3,358 / 710,296 bytes |

Both loops use a prebuilt position dictionary. The remaining difference is the
canonical Aletheia arithmetic range versus SoleLogics' `accessibles` traversal.
The deep sweep is measured separately with per-cell load averages recorded in
`data/benchmark-run/interval-deep.txt`; its raw values are in that artefact.
All generated edges are checked against their predicates in
`lib/AletheiaCore/test/relations.jl`.

## Checking formulas over real SoleData datasets

This real-dataset suite is separate from the synthetic tables above. The
explicit sweep builds seeded `ExplicitModalLogiset` datasets with 1, 8, or 32
instances and 4, 16, or 32 worlds per instance; each instance has six random
features and a directed graph. It varies formula depth, modal-node probability
(`0`, `.5`, or `1`), and uniform versus independently generated instance
frames (24 quick cases). Each formula is a seeded recursive recipe: leaves
are scalar conditions, Boolean nodes are `¬`, `∧`, `∨`, or `→`, and modal
nodes are `◇`/`□`. SoleData checks every world in every instance; Aletheia
wraps the dataset in `Aletheia.SoleDataFamily`, supplied by the optional
SoleData package extension,
and calls batch or scalar `extension`. The formula-instance-world agreement
gate covered 80 formulas before timing, including uniform and non-uniform
instance frames.

The supported follow-up builds the real default `scalarlogiset` path from a
two-column DataFrame, IA3 interval relations, and its default full/one-step
memosets. Its 15 cases vary instances, points (the interval-domain input),
depth, modal-node probability, and three mixed sizes. It compares cold first
check and warm repeated check with Aletheia batch and scalar callbacks; dataset
construction and the Aletheia family adapter are outside the timed closures.
This is narrow protocol evidence, not a general real-data speed claim.
The protocol workers use the same median-time/allocation pairing as the
consumer worker. A fresh SoleData checkout is unavailable in this measurement
environment, so no numeric SoleData results are included in this quick
benchmark; rerun the two protocol scripts with
`SOLEDATA_PATH` before publishing updated results. The full decision report is
published in [`data/soledata-protocol/`](https://github.com/eduardstan/Aletheia.jl/tree/main/data/soledata-protocol).

## SoleModels rule checks through Aletheia

This is a narrow real-consumer comparison, not a standalone evaluator ratio. Each
case creates a supported SoleData dataset with a given number of instances and
points, and seeded rules whose antecedents have a given depth, modal-node
probability, and shared-subtree flag. Rule atoms are drawn from 12 scalar
conditions; internal nodes use `∧`, `∨`, or `→`, modal nodes use IA_L `◇` or
`□`, and every rule is wrapped in a global `◇`. The timed operation sums
`SoleModels.checkantecedent(rule, dataset)` over all rules. Dataset
construction is outside the timing.

Two paths are compared. The **native** path is SoleModels as installed. The
**Aletheia-backed** path is a patched copy of SoleModels whose adapter builds
an Aletheia model family, converts each formula, calls `extension`, and returns
the same per-instance mask. The comparison is therefore a consumer path with a
wrapper and a conversion shim on the Aletheia-backed side, not two identical
package calls. The table below reports the Aletheia-backed path only, in three
phases:

* **First use** — five datasets the adapter has never seen, after a
  compile-only warmup.
* **Steady state** — the same model family re-used after one warming call.
* **Churn** — six new datasets in a row, so no cache is ever re-used.

Each phase is measured in five repetitions, each preceded by an exact mask
check. Within a repetition, first use and steady state have five timed samples
and churn has six. The displayed min/median/max are across the five repetitions,
and allocations/bytes come from the sample nearest each phase's median time.
Timings are reported per phase because a single averaged figure would conflate
first-use construction with steady-state reuse.

**Provenance:** commit `eac3e2c090324a8db475e6226891840baf9bc533`, measured 2026-08-24.

| representative case | first use min / median / max (ms) | steady min / median / max (ms) | churn min / median / max (ms) |
| --- | ---: | ---: | ---: |
| 16 rules, depth 4, 1 instance | 1.394 / 1.864 / 14.554 | 0.233 / 0.327 / 1.818 | 1.358 / 1.655 / 2.481 |
| 16 rules, depth 4, 16 instances | 4.047 / 4.251 / 8.988 | 2.379 / 2.573 / 5.515 | 4.012 / 4.176 / 9.335 |
| 16 rules, depth 4, 64 instances | 23.993 / 24.890 / 31.406 | 17.085 / 18.947 / 23.876 | 23.575 / 24.698 / 28.259 |

For the one-instance case, paired Aletheia-backed allocations are **24,067 /
3,017,992 bytes** on first use, **3,193 / 601,384** steady state, and **24,067
/ 3,017,992** under churn. The largest sampled churn GC was 42.879 ms. Use the
steady number when reusing a model family; budget first-use construction for
each genuinely new family; treat the churn tail as specific to workloads that
continually create families. The mask gate passed in all five repetitions (six
shapes, 352 exact rule-instance masks each). Correctness is the gating
condition: if it fails, no timing is published.

Instances whose world and relation signatures match share one adjacency index,
attached to the shared frame and independent of each model's valuation.
Without sharing, the same first-use sample costs **4.356 ms and 58,539
allocations / 6,727,592 bytes**; with it, the five-run median is **1.864 ms and
24,067 / 3,017,992**. Steady-state allocations are unchanged.

The full sweep has eighteen cases; six of them share this shape. The large
tails are spread rather than a position effect; the [run-order diagnostic](https://github.com/eduardstan/Aletheia.jl/tree/main/data/solemodels-consumer/order-diagnostic-late-first/)
supports this conclusion. The full distributions and per-repetition logs are
published in
[`data/solemodels-consumer/`](https://github.com/eduardstan/Aletheia.jl/tree/main/data/solemodels-consumer).

## Bisimulation contraction: capability and scope

Bisimulation contraction remains a library capability. The synthetic amortisation
below shows when that capability can pay back its construction cost; it is not a
claim that contraction improves real modal learners. SoleData models compress only
**1.02×–1.15×**: on continuous NATOPS
models, the quotient is nearly the same size as the original. SoleData's
`representatives` path instead visits about **5.6 worlds out of 1,326** per check
(a roughly **238×** reduction), precisely because it need not preserve all modal
truth. ModalDecisionTrees cannot accept a quotient: its memoset is keyed by
interval coordinates and it reports witness worlds.

Rule extraction does manufacture height-8 formulas, the workload shape that
contraction was intended to help, but it still fails on these data because the
models do not compress—not because that workload is absent. The synthetic
amortisation below is therefore a capability boundary, not a motivation for a
learner integration.

The contraction generator makes a complete all-world relation model with binary
atom labels chosen to produce the requested quotient size. `C` times
`bisimulation_contraction`; `P_orig` checks two selected formulas on the
original model; `P_quot` checks the corresponding formulas on the precomputed
quotient model. The batch cells check `K` formulas (cycling through eight), and
the quotient total includes `C`. Each displayed per-formula value is the median-time sample among 2000 paired
observations for each selected formula case; allocations are taken from that
same observation. SoleLogics v0.13.7 has no corresponding contraction API, so it is
**unsupported here and has no ratio**, rather than being assigned a zero or a
loss.

The correctness gate ran **480 seeded random labelled models** and 16 random
modal formulas per model (96 for each of five seeds, plus the deterministic
differential suite); every
original-world truth value equalled its quotient-class value before timing.
The same gate is asserted in `lib/AletheiaCore/test/theory.jl`, so a
disagreement fails tests rather than becoming a performance result.

`C` is one contraction; `P_orig` and `P_quot` are per-formula check times on
the original and the quotient model; `K*` is the number of formulas at which
contraction pays for itself.

**Provenance:** commit `6ebaa998d00e8d4b172c7142fc0c9fbc81298f5e`, measured 2026-08-31 on `alderlake`.

| original n | quotient q | q/n | C (median; mean ± std) | P_orig (median; mean ± std) | P_quot (median; mean ± std) | K* (median; mean ± std; range) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 48 | 1 | 0.021 | C=268.06 μs (mean 272.24 μs ± 17.73 μs) | P_orig=8.80 μs (mean 8.74 μs ± 1.12 μs) | P_quot=2.48 μs (mean 2.54 μs ± 642.3 ns) | K*=42.8 (mean 47.6 ± 17.4, range 33.6-76.1) |
| 48 | 48 | 1.000 | C=1.97 ms (mean 1.97 ms ± 35.61 μs) | P_orig=6.44 μs (mean 6.72 μs ± 865.8 ns) | P_quot=35.20 μs (mean 35.42 μs ± 872.4 ns) | K*=∞ |

For the q=1 case, the observed K* median is 42.8 formulas (mean 47.6 ± 17.4;
range 33.6–76.1). The already-minimal q=48 case never crosses over, so its K*
remains ∞.

## What these results tell you

**What the historical artifact showed.** The `isequal` row is the clearest
representation win: formulas interned in one pool carry pooled integer identity, so equality
is an integer comparison rather than SoleLogics' structural walk. The historical
extension rows showed a smaller mechanism: Aletheia walked the formula DAG once
into a `BitVector`, while the explicitly labelled SoleLogics equivalent performed
an all-world check loop. The interval size sweep was a separate historical result:
canonical generated interval domains exposed arithmetic successor ranges. The
comparison charged both sides for position lookup. The historical depth-4/6
propositional rows and modal rows also benefited from DAG evaluation and from doing
no per-call normalisation; modal traversal still made the graph's world count and
density matter. The ILP row's repeated hypotheses × interpretations score loop
reused that historical evaluator path, but its magnitude varied by seed. None of
these statements describes the current checkout; the paired current measurements
above show the evaluator regression directly.

**Where it loses.** The propositional depth-2 row is near parity. One shallow
check is too little work to repay Aletheia's model/valuation and DAG walk setup,
while SoleLogics' direct `TruthDict` lookup is cheap. The `[no clear winner]`
marker identifies ratios where the mean ± standard deviation band contains
`1.00×`; it does not describe the observed range. Compatibility wrappers,
recipe conversion, and repooling are fixed costs even after eliminating
traversal allocations. The one cold real-dataset loss above
has the same shape: a small formula does not repay callback and adapter setup;
memoized repeated checks removed that fixed-cost disadvantage in the historical artifact.

**Where a win does not generalise.** Contraction amortisation is workload
specific: the K* table shows the crossover for a highly redundant model, while
an already-minimal model makes contraction pure overhead. The learner evidence
above narrows this further: SoleData models compress only **1.02×–1.15×**,
and SoleData's `representatives` path is already much stronger. Hash-consed
subterm sharing is likewise workload-specific. It helps when a workload
repeatedly reuses subterms, but against the flat leftmost representation that
SolePostHoc actually uses it costs **≈16.8× more allocations** and leaves a
larger live footprint. Neither mechanism is a general speedup. The consumer
min / median / max columns are first-use, steady-state, and fresh-dataset churn
phase distributions; use the phase matching your workload and retain the tails.
The interval fast path applies to canonical generated domains with their
arithmetic provider, not automatically to an arbitrary user-supplied frame.
Likewise, the extension ratios compare an all-world SoleLogics loop with a
named Aletheia `extension` API and should not be read as a claim that both
packages expose the same operation.

**What to expect.** If you evaluate many formulas over one finite model, expect
the extension/BitVector path to matter. If you build and compare formulas
repeatedly *with shared subterms*, pooled identity and DAG sharing can matter;
the flat leftmost consumer representation is a measured counterexample, not a
general win. If you check one shallow propositional formula once, expect little
difference and possibly the near-parity outcome seen here. For a new real-data
consumer, first decide whether you are measuring cold adapter construction,
steady reuse, or fresh-dataset churn; this page provides evidence for each, not a
universal speedup.

## Deployed-model apply paths

This is a separate apply-path experiment against a documented Sole stack; it is
not fully optimized because relational precomputation is explicitly disabled
(`relational-precompute=false`). The fixture is one seeded `ModalDecisionTrees` model trained on a
16-instance, 8-point supported scalar dataset. The same translated formula
roots, source data, and world order are used by every mode. The differential
gate compares every formula extension, antecedent mask, and prediction before
any timing.

The Sole rows name the path being measured. **Sole formula-check** calls
`SoleData.check` with full memoization and one-step memoization enabled,
including global precomputation and explicit relational-precompute=false.
**Deployed modal-tree apply** calls `ModalDecisionTrees.apply`, whose direct
`modalstep`/`checkcondition` hot path bypasses SoleData formula memos.
**Decision-list apply** calls `SoleModels.apply` and therefore routes antecedent
checks through `SoleLogics.check`. Aletheia's callback rows use a prepared model family and the same converted
roots: **scalar callback** disables the batch callback, while **vectorized batch
callback** supplies it. The **prepared scalar-data** rows instead use
`DenseFeatureStore`, `prepare_scalar`, and `scalar_family` over materialized
world × instance × feature values; their store/preparation cost is reported
separately from apply. Preparation and frame/model conversion are reported
separately for both paths.

The five seed medians shown here are aggregated by median across seeds
(`0xA1E7_2024`, `0x5EED_2025`, `0xC0FF_EE42`, `0x1234_5678`, and
`0x9ABC_DEF0`); the paired allocation/byte observation is the one nearest that
aggregate median. The raw artifact records five time/allocation-paired samples for timed phases,
the sample nearest the median with its allocations and bytes, fixed seeds, cache controls,
Julia/package versions, child niceness, and uptime before and after each
section. It also records fresh-dataset churn separately from first use and warm
reuse. The published values below are scope-limited.

### Before allocation fix (baseline)

**Provenance:** commit `3acd508d6974ca6064b74fe7ee9ef142dd8f657c`, measured 2026-09-02.

**Provenance:** commit `6af8646107d34183d6d1dbe4da44abd098ed9927`, measured 2026-09-02.

| mode | warm reuse (ms; allocations / bytes) | fresh-dataset churn (ms; allocations / bytes) |
| --- | ---: | ---: |
| Sole formula-check | 11.517; 103,127 / 4,028,272 | 18.359; 222,979 / 10,762,736 |
| supported-cold (construction + first check) | 18.833; 223,554 / 10,934,488 | 19.904; 223,554 / 10,934,488 |
| supported-warm | 10.524; 103,127 / 4,028,272 | 18.743; 222,979 / 10,762,736 |
| deployed modal-tree apply | 0.192; 470 / 34,016 | 0.074; 470 / 34,016 |
| decision-list apply | 4.348; 36,515 / 1,415,616 | 11.128; 109,330 / 6,100,080 |
| Aletheia scalar callback | 1.249; 14,358 / 3,759,120 | 15.958; 117,494 / 21,367,056 |
| Aletheia vectorized batch callback | 0.749; 7,414 / 1,274,512 | 18.235; 110,550 / 18,882,448 |
| Aletheia bridge scalar-data | 1.256; 14,371 / 4,117,952 bytes | 15.252; 117,507 / 21,725,888 bytes |
| Aletheia bridge vectorized scalar-data | 0.683; 7,427 / 1,384,256 bytes | 16.148; 110,563 / 18,992,192 bytes |
| Aletheia dense scalar-data | 1.268; 14,371 / 4,117,952 bytes | 17.244; 117,507 / 21,725,888 bytes |
| Aletheia dense vectorized scalar-data | 0.871; 7,427 / 1,384,256 bytes | 16.019; 110,563 / 18,992,192 bytes |

### After allocation fix

The rerun is retained in `data/benchmark-run/deployed-apply-after.txt`. The quiet-machine and differential gates passed (`load_gate=PASS start=1.21 end=1.67 peak=1.67`, `differential=PASS`). Recorded uptime was `uptime_before_differential= 14:27:01 up 3 days, 20:54,  1 user,  load average: 1.21, 1.30, 1.13` and `uptime_after_run= 14:49:57 up 3 days, 21:17,  1 user,  load average: 1.67, 1.57, 1.38`.

**Provenance:** before values commit `3acd508d6974ca6064b74fe7ee9ef142dd8f657c`, after values commit `1927fb7d356db0460f6ab2e15806858e523967be`; both measured 2026-09-02.

| mode | warm reuse (ms; allocations / bytes) (before → after) | fresh-dataset churn (ms; allocations / bytes) (before → after) |
| --- | ---: | ---: |
| Sole formula-check | 10.293 → 8.054 ms; 103,127 / 4,028,272 → 103,127 / 4,028,272 | 18.209 → 15.334 ms; 222,979 / 10,762,736 → 222,979 / 10,762,736 |
| supported-cold (construction + first check) | 18.833 → 15.828 ms; 223,554 / 10,934,488 → 223,554 / 10,934,488 | 19.904 → 15.860 ms; 223,554 / 10,934,488 → 223,554 / 10,934,488 |
| supported-warm | 10.094 → 8.324 ms; 103,127 / 4,028,272 → 103,127 / 4,028,272 | 19.353 → 15.593 ms; 222,979 / 10,762,736 → 222,979 / 10,762,736 |
| deployed modal-tree apply | 0.192 → 0.057 ms; 470 / 34,016 → 470 / 34,016 | 0.074 → 0.075 ms; 470 / 34,016 → 470 / 34,016 |
| decision-list apply | 4.348 → 3.697 ms; 36,515 / 1,415,616 → 36,693 / 1,421,888 | 11.128 → 9.078 ms; 109,330 / 6,100,080 → 110,135 / 6,103,200 |
| Aletheia scalar callback | 1.249 → 0.794 ms; 14,358 / 3,759,120 → 12,369 / 3,607,984 | 15.958 → 1.427 ms; 117,494 / 21,367,056 → 18,815 / 4,708,480 |
| Aletheia vectorized batch callback | 0.749 → 0.444 ms; 7,414 / 1,274,512 → 4,529 / 635,056 | 18.235 → 1.017 ms; 110,550 / 18,882,448 → 10,975 / 1,735,552 |
| Aletheia bridge scalar-data | 1.256 → 0.838 ms; 14,371 / 4,117,952 → 12,965 / 3,996,384 | 15.252 → 12.392 ms; 117,507 / 21,725,888 → 116,101 / 21,604,320 |
| Aletheia bridge vectorized scalar-data | 0.683 → 0.551 ms; 7,427 / 1,384,256 → 5,797 / 1,251,936 | 16.148 → 12.211 ms; 110,563 / 18,992,192 → 108,933 / 18,859,872 |
| Aletheia dense scalar-data | 1.268 → 0.849 ms; 14,371 / 4,117,952 → 12,965 / 3,996,384 | 17.244 → 12.153 ms; 117,507 / 21,725,888 → 116,101 / 21,604,320 |
| Aletheia dense vectorized scalar-data | 0.871 → 0.533 ms; 7,427 / 1,384,256 → 5,797 / 1,251,936 | 16.019 → 13.395 ms; 110,563 / 18,882,448 → 108,933 / 18,859,872 |

### After frame sharing

The frame-sharing rerun uses the logged `APPLY_DATA_SEED` for dataset generation
and is retained in
[`data/benchmark-run/deployed-apply-after-sharing.txt`](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/deployed-apply-after-sharing.txt).
It uses the merged `benchmark/deployed_apply.jl` harness with scale cases capped
at 128 instances. The differential gate passed for all five seeds, and the
quiet-machine gate passed (`load_gate=PASS start=1.88 end=1.30 peak=2.40`), so
these allocation and byte rows also include the permitted timing evidence.
Values are selected by mode name from the five per-seed fresh-dataset and warm
samples in the artifact.

| mode | warm reuse (ms; allocations / bytes) | fresh-dataset churn (ms; allocations / bytes) |
| --- | ---: | ---: |
| Aletheia bridge scalar-data | 0.833; 12,350 / 3,956,304 | 1.554; 18,796 / 5,056,800 |
| Aletheia bridge vectorized scalar-data | 0.513; 5,182 / 1,211,856 | 1.251; 11,628 / 2,312,352 |
| Aletheia dense scalar-data | 0.856; 12,350 / 3,956,304 | 1.610; 18,796 / 5,056,800 |
| Aletheia dense vectorized scalar-data | 0.539; 5,182 / 1,211,856 | 1.109; 11,628 / 2,312,352 |

The scalar-data churn now matches the prepared callback paths in allocation
order, while non-equal frame signatures remain separate.

The scale sweep keeps the trained formula roots fixed and changes only the
supported dataset size. It compares native `SoleModels.apply` with prepared
Aletheia scalar and vectorized callbacks under the same five seeds. Each child
runs under a 6 GB resident-memory limit and a 900-second section timeout; its
peak RSS is retained in the raw artifact. The largest completed case is the
largest one shown as measured below; memory- or time-limited cases are shown as
skipped rather than imputed.

### Before allocation fix (baseline scale sweep)

**Provenance:** commit `1ea253c22038ba9aef663abbc638e9bddc70957d`, measured 2026-09-02.

| instances × points | native decision-list warm / churn (ms) | Aletheia scalar warm / churn (ms) | Aletheia vectorized warm / churn (ms) |
| --- | ---: | ---: | ---: |
| 32 × 8 | 8.804 / 23.152 ms | 1.933 / 41.266 ms | 1.645 / 36.654 ms |
| 64 × 8 | 14.168 / 38.021 ms | 8.157 / 79.684 ms | 3.051 / 77.516 ms |
| 128 × 8 | 23.382 / 66.419 ms | 16.619 / 185.868 ms | 7.559 / 166.299 ms |
| 256 × 8 | 51.334 / 148.870 ms | 36.094 / 389.007 ms | 12.506 / 353.174 ms |
| 512 × 8 | 113.189 / 352.923 ms | 98.969 / 706.175 ms | 26.180 / 727.951 ms |

### After allocation fix

The new scale cases are capped at 128 instances. The quiet-machine and differential gates passed (`load_gate=PASS start=1.21 end=1.67 peak=1.67`, `differential=PASS`).

**Provenance:** before values commit `1ea253c22038ba9aef663abbc638e9bddc70957d`, after values commit `1927fb7d356db0460f6ab2e15806858e523967be`; both measured 2026-09-02.

| instances × points | native warm / churn (ms; before → after) | Aletheia scalar warm / churn (ms; before → after) | Aletheia vectorized warm / churn (ms; before → after) | native allocations / bytes (warm; before → after) | Aletheia scalar allocations / bytes (warm; before → after) | Aletheia vectorized allocations / bytes (warm; before → after) | native allocations / bytes (churn; before → after) | Aletheia scalar allocations / bytes (churn; before → after) | Aletheia vectorized allocations / bytes (churn; before → after) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 32 × 8 | 8.804 → 7.641 / 23.152 → 18.993 ms | 1.933 → 1.458 / 41.266 → 2.655 ms | 1.645 → 0.833 / 36.654 → 1.492 ms | 77,398 / 2,971,376 → 77,754 / 2,983,920 | 28,661 / 7,498,528 → 24,560 / 7,187,392 | 14,773 / 2,529,312 → 8,880 / 1,241,536 | 230,125 / 12,692,424 → 231,828 / 12,713,904 | 234,933 / 42,714,400 → 31,006 / 8,287,888 | 221,045 / 37,745,184 → 15,326 / 2,342,032 |
| 64 × 8 | 14.168 → 11.827 / 38.021 → 31.065 ms | 8.157 → 3.557 / 79.684 → 3.810 ms | 3.051 → 1.575 / 77.516 → 2.206 ms | 122,406 / 4,703,056 → 123,064 / 4,726,224 | 57,273 / 14,982,240 → 48,944 / 14,346,432 | 29,497 / 5,043,808 → 17,584 / 2,454,720 | 386,732 / 21,870,384 → 389,674 / 21,927,360 | 469,817 / 85,413,984 → 55,390 / 15,446,928 | 442,041 / 75,475,552 → 24,030 / 3,555,216 |
| 128 × 8 | 23.382 → 18.583 / 66.419 → 50.236 ms | 16.619 → 9.232 / 185.868 → 10.393 ms | 7.559 → 3.607 / 166.299 → 4.659 ms | 195,544 / 7,555,704 → 196,590 / 7,592,440 | 114,489 / 29,940,416 → 97,712 / 28,664,736 | 58,937 / 10,063,552 → 34,992 / 4,881,312 | 666,596 / 38,011,568 → 671,308 / 38,095,144 | 939,577 / 170,803,904 → 104,158 / 29,765,232 | 884,025 / 150,927,040 → 41,438 / 5,981,808 |

A one-iteration `Profile.Allocs` profile is recorded beside the scale rows. It
runs the exact apply call on a never-used fresh fixture after a separate
profiler warm-up and reports aggregated stack-frame file:line sites, bytes, and
counts for the callback, native decision list, and dense-store path. The top
vectorized callback site is [`AletheiaCore`](api.md)/`lib/AletheiaCore/src/evaluation.jl:321`
(16,781,888 bytes), with [`AletheiaData`](families.md) source line
[`lib/AletheiaData/src/dataset.jl:352`](https://github.com/eduardstan/Aletheia.jl/blob/main/lib/AletheiaData/src/dataset.jl#L352)
next (15,733,020 bytes). The dense-store profile has the same evaluator sites
(`lib/AletheiaCore/src/evaluation.jl:321`, 16,891,200 bytes; source line
[`lib/AletheiaData/src/dataset.jl:352`](https://github.com/eduardstan/Aletheia.jl/blob/main/lib/AletheiaData/src/dataset.jl#L352), 15,835,500 bytes). Native apply is led by
`SoleModels/.../other.jl:149` (5,554,802 bytes) and
`SoleModels/.../other.jl:165` (5,501,874 bytes),
with `SoleLogics/.../rule-and-branch.jl:490` next (5,501,570 bytes). The
profile therefore attributes the measured fresh-fixture gap to Aletheia
extension/data evaluation allocation sites, not to eager dense feature
materialization in the apply call; preparation remains outside apply timing.

The construction and first-use values are intentionally not folded into warm
reuse. This is a result for the declared workload and mode, never
"universally faster". Reproduce it with the package paths and command in
[`benchmark/README.md`](https://github.com/eduardstan/Aletheia.jl/blob/main/benchmark/README.md);
this run is publishable because both recorded gates pass. The full per-seed output is retained in
[`data/benchmark-run/deployed-apply-after.txt`](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/deployed-apply-after.txt).

## Correctness and coverage

`benchmark/differential.jl` uses the same fixed seed and passes its syntax and
semantic checks before timings. Run package tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
