# Measured results

Reproducing these measurements needs a local checkout of SoleLogics, because
Aletheia deliberately does not depend on it:

```sh
git clone https://github.com/aclai-lab/SoleLogics.jl /tmp/SoleLogics.jl
SOLELOGICS_PATH=/tmp/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

The quick run uses Julia 1.12.7 on `alderlake` with SoleLogics 0.13.7 and five
seeds (`0xA1E7_2024`, `0x5EED_2025`, `0xC0FF_EE42`, `0x1234_5678`,
`0x9ABC_DEF0`). It records uptime at start and end, retains **200 paired
samples per seed** (2000 for contraction), and prints the seed set, paired
medians, allocation counts, correctness gate, and wall clock. Sampling is
paired and interleaved, with seed order rotated between rows. Per-seed load
readings are retained in the raw run artefact.

Each section runs in a warmed child Julia process; GNU `timeout` kills a section
at the printed hard bound (120 s quick, 180 s deep). `--deep` expands the size
and ratio sweeps. A timeout is reported as data, not silently dropped. Cold-load rows are measured in fresh processes.
The ratio is SoleLogics/Aletheia; allocations are `count / bytes`. Every ratio
cell shows the median, mean ± standard deviation, and the observed per-seed
range. The range is descriptive, not a confidence interval. `[no clear winner]`
means that the mean ± standard deviation band contains `1.00×`. The raw run is retained in
[`data/benchmark-run/run.txt`](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/run.txt),
and the correction history is in
[`data/benchmark-run/corrections.md`](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/corrections.md).


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

| case | SoleLogics median (mean ± std) | Aletheia median (mean ± std) | ratio median (mean ± std, range) | allocations |
| --- | ---: | ---: | ---: | ---: |
| construction, depth 2 (unshared) | 6.10 μs (mean 6.36 μs ± 1.78 μs) | 5.45 μs (mean 5.65 μs ± 1.38 μs) | 1.00× (mean 1.22× ± 0.57×, range 0.64-2.04×) [no clear winner] | 37 / 1.281 KiB ; 56 / 2.594 KiB |
| construction, depth 2 (shared) | 6.35 μs (mean 6.52 μs ± 422.2 ns) | 4.18 μs (mean 4.41 μs ± 796.8 ns) | 1.52× (mean 1.52× ± 0.30×, range 1.04-1.83×) | 37 / 1.281 KiB ; 50 / 2.203 KiB |
| parsing, depth 2 | 83.33 μs (mean 110.64 μs ± 50.62 μs) | 18.36 μs (mean 16.36 μs ± 5.38 μs) | 7.58× (mean 7.60× ± 4.53×, range 3.17-14.51×) | 295 / 12.312 KiB ; 62 / 3.672 KiB |
| printing, depth 2 | 18.17 μs (mean 18.16 μs ± 7.55 μs) | 4.92 μs (mean 5.27 μs ± 1.59 μs) | 2.87× (mean 3.52× ± 1.32×, range 2.36-5.25×) | 45 / 1.750 KiB ; 19 / 864 bytes |
| round-trip, depth 2 | 144.62 μs (mean 133.94 μs ± 35.49 μs) | 33.29 μs (mean 31.37 μs ± 12.40 μs) | 4.09× (mean 4.66× ± 1.94×, range 3.21-8.06×) | 340 / 14.062 KiB ; 81 / 4.516 KiB |
| `isequal`, chain 16 | 5.01 μs (mean 5.33 μs ± 546.7 ns) | 33.0 ns (mean 33.6 ns ± 3.3 ns) | 157.33× (mean 158.75× ± 9.00×, range 149.48-171.48×) | 32 / 1.469 KiB ; 0 / 0 bytes |
| cold package load | 2163.70 ms (mean 3963.84 ms ± 4012.27 ms) | 56.87 ms (mean 62.51 ms ± 10.98 ms) | 38.64× (mean 65.16× ± 65.77×, range 21.92-181.68×) [no clear winner] | —/— |
| cold time to first result | 7078.23 ms (mean 12870.39 ms ± 11812.11 ms) | 2829.49 ms (mean 3623.74 ms ± 2014.91 ms) | 3.10× (mean 3.26× ± 1.06×, range 2.29-4.96×) | —/— |

The load ratio is measured across fresh processes and is not attributed to the
evaluator. The equality ratio is the pool-local integer identity path versus
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

| case | SoleLogics median (mean ± std) | Aletheia median (mean ± std) | ratio median (mean ± std, range) | allocations |
| --- | ---: | ---: | ---: | ---: |
| propositional check, depth 2 | 3.80 μs (mean 4.23 μs ± 1.28 μs) | 5.42 μs (mean 6.09 μs ± 1.55 μs) | 0.76× (mean 0.73× ± 0.26×, range 0.37-1.06×) | 29 / 752 bytes ; 48 / 2.484 KiB |
| propositional check, depth 4 | 37.95 μs (mean 46.46 μs ± 19.91 μs) | 21.64 μs (mean 25.10 μs ± 10.10 μs) | 1.67× (mean 1.96× ± 1.00×, range 1.27-3.72×) [no clear winner] | 155 / 4.109 KiB ; 159 / 9.078 KiB |
| propositional check, depth 6 | 107.96 μs (mean 119.23 μs ± 26.24 μs) | 94.04 μs (mean 98.60 μs ± 19.73 μs) | 1.23× (mean 1.25× ± 0.34×, range 0.72-1.54×) [no clear winner] | 659 / 17.609 KiB ; 601 / 36.055 KiB |
| e×tension, 8 worlds / depth 3 | 166.63 μs (mean 156.91 μs ± 23.65 μs) | 18.34 μs (mean 21.35 μs ± 8.77 μs) | 8.75× (mean 8.02× ± 2.24×, range 4.80-10.59×) | 760 / 30.297 KiB ; 143 / 11.641 KiB |
| e×tension, 32 worlds / depth 4 | 727.10 μs (mean 667.47 μs ± 162.91 μs) | 238.62 μs (mean 229.25 μs ± 54.93 μs) | 2.86× (mean 2.91× ± 0.18×, range 2.73-3.14×) | 2191 / 110.000 KiB ; 655 / 160.078 KiB |
| random modal, worlds=8 / 0.15 / depth=2 | 7.11 μs (mean 6.65 μs ± 4.38 μs) | 3.84 μs (mean 3.65 μs ± 1.30 μs) | 2.06× (mean 1.69× ± 0.81×, range 0.81-2.42×) [no clear winner] | 136 / 5.156 KiB ; 58 / 3.547 KiB |
| random modal, worlds=24 / 0.15 / depth=2 | 28.46 μs (mean 27.45 μs ± 15.26 μs) | 16.27 μs (mean 14.29 μs ± 8.07 μs) | 1.56× (mean 2.18× ± 1.73×, range 1.16-5.25×) [no clear winner] | 264 / 13.297 KiB ; 128 / 20.109 KiB |
| random modal, worlds=8 / 0.5 / depth=2 | 9.54 μs (mean 10.90 μs ± 8.33 μs) | 7.79 μs (mean 7.03 μs ± 2.78 μs) | 1.83× (mean 1.43× ± 0.83×, range 0.53-2.30×) [no clear winner] | 138 / 5.188 KiB ; 58 / 3.547 KiB |
| random modal, worlds=24 / 0.5 / depth=2 | 48.18 μs (mean 37.06 μs ± 20.25 μs) | 30.86 μs (mean 27.30 μs ± 18.32 μs) | 1.52× (mean 1.49× ± 1.02×, range 0.35-3.09×) [no clear winner] | 264 / 13.469 KiB ; 128 / 20.109 KiB |
| random modal, worlds=8 / 0.15 / depth=4 | 31.02 μs (mean 38.54 μs ± 35.64 μs) | 4.93 μs (mean 6.47 μs ± 3.84 μs) | 5.92× (mean 4.80× ± 2.93×, range 0.60-8.04×) | 304 / 10.922 KiB ; 68 / 4.828 KiB |
| random modal, worlds=24 / 0.15 / depth=4 | 42.12 μs (mean 80.04 μs ± 86.43 μs) | 11.84 μs (mean 16.55 μs ± 12.60 μs) | 3.56× (mean 3.72× ± 2.97×, range 0.61-8.33×) [no clear winner] | 390 / 18.219 KiB ; 126 / 20.094 KiB |
| random modal, worlds=8 / 0.5 / depth=4 | 54.32 μs (mean 43.72 μs ± 35.14 μs) | 7.46 μs (mean 7.32 μs ± 4.94 μs) | 5.97× (mean 5.08× ± 2.65×, range 0.78-7.28×) | 307 / 11.266 KiB ; 68 / 4.828 KiB |
| random modal, worlds=24 / 0.5 / depth=4 | 72.72 μs (mean 96.89 μs ± 111.86 μs) | 24.40 μs (mean 23.06 μs ± 18.09 μs) | 2.45× (mean 3.52× ± 3.80×, range 0.47-10.10×) [no clear winner] | 390 / 19.844 KiB ; 126 / 20.094 KiB |
| interval adjacency, n=6 | 4.39 μs (mean 4.58 μs ± 733.3 ns) | 3.69 μs (mean 4.29 μs ± 1.19 μs) | 1.19× (mean 1.15× ± 0.43×, range 0.61-1.80×) [no clear winner] | 107 / 5.094 KiB ; 100 / 3.656 KiB |
| Allen BEFORE check, n=6 | 25.87 μs (mean 25.36 μs ± 9.68 μs) | 13.98 μs (mean 14.06 μs ± 2.47 μs) | 1.85× (mean 1.80× ± 0.61×, range 1.15-2.71×) | 230 / 32.234 KiB ; 176 / 22.109 KiB |
| interval subset IA3, n=6 | 135.85 μs (mean 126.86 μs ± 27.40 μs) | 13.93 μs (mean 15.87 μs ± 5.52 μs) | 9.76× (mean 9.37× ± 5.16×, range 4.46-17.00×) | 3048 / 198.609 KiB ; 273 / 40.656 KiB |
| interval subset IA7, n=6 | 86.73 μs (mean 86.31 μs ± 9.91 μs) | 46.96 μs (mean 66.18 μs ± 36.01 μs) | 1.88× (mean 1.54× ± 0.59×, range 0.80-2.10×) [no clear winner] | 2484 / 141.266 KiB ; 717 / 113.438 KiB |
| interval subset RCC5, n=6 | 185.07 μs (mean 204.56 μs ± 69.39 μs) | empty [0/5 seeds] | — | 4104 / 243.375 KiB ; — |
| finite chain G3 check, depth 2 | 4.24 μs (mean 4.70 μs ± 1.52 μs) | 3.28 μs (mean 3.25 μs ± 541.2 ns) | 1.34× (mean 1.46× ± 0.43×, range 0.89-1.92×) | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| finite chain Ł3 check, depth 2 | 6.62 μs (mean 6.65 μs ± 916.2 ns) | 3.69 μs (mean 3.82 μs ± 471.3 ns) | 1.63× (mean 1.77× ± 0.39×, range 1.33-2.31×) | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| non-chain H4 check, depth 2 | 3.44 μs (mean 4.99 μs ± 2.63 μs) | 3.36 μs (mean 3.52 μs ± 814.2 ns) | 1.26× (mean 1.43× ± 0.73×, range 0.76-2.68×) [no clear winner] | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| ILP interpretation scoring, 8 models / 4 hypotheses | 702.33 μs (mean 1.01 ms ± 764.26 μs) | 160.12 μs (mean 164.02 μs ± 33.22 μs) | 4.60× (mean 5.74× ± 2.94×, range 3.88-10.96×) | 8872 / 331.469 KiB ; 2056 / 130.781 KiB |

The extension comparison is explicitly an equivalent all-world check loop on
SoleLogics because it has no `extension` API; it is not labelled as a win over
an operation SoleLogics does not have. Modal formulas, graphs, and valuations
are regenerated for every seed; normalization is disabled to isolate evaluation.
The ILP row constructs seed-specific `learning_from_interpretations` examples
and scores hypotheses over all interpretations through the check/eval loop.

Aletheia evaluates each extension formula DAG once into a `BitVector`, while the
equivalent SoleLogics all-world loop performs one shared-memo evaluation per
invocation. Aletheia's relation adjacency is cached on the reused `Model` after
its first check, while SoleLogics rebuilds its structural memo per call. Thus the
modal rows are warm repeated-model measurements, not first-call comparisons; the
asymmetry is intentional and labelled.

### Why interval adjacency scales

A naive implementation compares every candidate world against the source
(`target.x > source.y`), which is an O(|W|) scan per source. Aletheia's
generated interval frames instead expose the successor set as an arithmetic
range, while `accessible` stays lazy. The effect grows with the domain size
(the quick n=6 row uses 200 samples; the deep-only sweep uses 500 samples):

| n | SoleLogics | Aletheia | ratio | allocations (SoleLogics ; Aletheia) |
| ---: | ---: | ---: | ---: | ---: |
| 6 | 1.54 μs | 648.0 ns | 2.38× | 107 / 5.094 KiB ; 100 / 3.656 KiB |
| 12 | 14.62 μs | 2.86 μs | 5.11× | 447 / 36.820 KiB ; 373 / 19.562 KiB |
| 24 | 204.31 μs | 29.34 μs | 6.96× | 2,048 / 457.773 KiB ; 1,462 / 161.477 KiB |
| 36 | 1.18 ms | 140.08 μs | 8.43× | 5,066 / 1.721 MiB ; 3,358 / 693.648 KiB |

Both loops use a prebuilt position dictionary. The remaining difference is the
canonical Aletheia arithmetic range versus SoleLogics' `accessibles` traversal.
The deep sweep is measured separately with per-cell load averages recorded in
`data/benchmark-run/interval-deep.txt`; its raw values are in that artefact.
All generated edges are checked against their predicates in `test/relations.jl`.

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
environment, so the numeric SoleData table is a recorded protocol result, not
part of this quick benchmark; rerun the two protocol scripts with
`SOLEDATA_PATH` before updating those cells. The full decision report is
published in [`data/soledata-protocol/`](https://github.com/eduardstan/Aletheia.jl/tree/main/data/soledata-protocol).

## Routing a SoleModels rule check through Aletheia

This is a narrow real-consumer trial, not a standalone evaluator ratio. Each
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

The full sweep has eighteen cases; six of them share this shape, and their
first-use maxima ranged from 4.6 ms to 70.4 ms. Re-running with the last six
cases first gave maxima of 4.1–4.8 ms across the same shapes, so the large
tails are spread rather than a position effect. The full distributions,
per-repetition logs, the run-order diagnostic, and the before/after
optimisation record are published in
[`data/solemodels-consumer/`](https://github.com/eduardstan/Aletheia.jl/tree/main/data/solemodels-consumer).

## Bisimulation contraction: capability and scope

Bisimulation contraction remains a library capability. The synthetic amortisation
below shows when that capability can pay back its construction cost; it is not a
claim that contraction improves real modal learners. Two independent learner
probes found that real models compress only **1.02×–1.15×**: on continuous NATOPS
models, the quotient is nearly the same size as the original. The incumbent's
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
The same gate is asserted in `test/theory.jl`, so a disagreement fails tests
rather than becoming a performance result.

`C` is one contraction; `P_orig` and `P_quot` are per-formula check times on
the original and the quotient model; `K*` is the number of formulas at which
contraction pays for itself.

| original n | quotient q | q/n | C (median; mean ± std) | P_orig (median; mean ± std) | P_quot (median; mean ± std) | K* (median; mean ± std; range) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 48 | 1 | 0.021 | empty [0/5 seeds] | empty [0/5 seeds] | empty [0/5 seeds] | ∞ |
| 48 | 48 | 1.000 | empty [0/5 seeds] | empty [0/5 seeds] | empty [0/5 seeds] | ∞ |

The contraction cells timed out in this quick run, so no K* crossover estimate
is available. The already-minimal case is expected to remain pure overhead; the
raw artefact records the timeout result.

## What these results tell you

**Where the design wins.** The `isequal` row is the clearest representation
win: formulas interned in one pool carry pooled integer identity, so equality
is an integer comparison rather than SoleLogics' structural walk. The extension
rows show a smaller but still measurable mechanism: Aletheia walks the formula
DAG once into a `BitVector`, while the explicitly labelled SoleLogics equivalent
performs an all-world check loop. The interval size sweep is a separate win:
canonical generated interval domains expose arithmetic successor ranges. The
comparison charges both sides for position lookup. The depth-4/6 propositional
rows and the modal rows also benefit from DAG evaluation and from doing no
per-call normalisation; modal traversal still makes the graph's world count and
density matter. The ILP row's repeated hypotheses × interpretations score loop
reuses that evaluator path, but its magnitude varies by seed.

**Where it loses.** The propositional depth-2 row is near parity. One shallow
check is too little work to repay Aletheia's model/valuation and DAG walk setup,
while SoleLogics' direct `TruthDict` lookup is cheap. The `[no clear winner]`
marker identifies ratios where the mean ± standard deviation band contains
`1.00×`; it does not describe the observed range. The separate compatibility
construction-from-recipe evidence reports **1.10×** in its Aletheia/native
convention (about **0.91×** in this page's SoleLogics/Aletheia convention):
compatibility wrappers, recipe conversion, and repooling are fixed costs even
after the allocation-free traversal fix. The one cold real-dataset loss above
has the same shape: a small formula does not repay callback and adapter setup;
memoized repeated checks remove that fixed-cost disadvantage.

**Where a win does not generalise.** Contraction amortisation is workload
specific: the K* table shows the crossover for a highly redundant model, while
an already-minimal model makes contraction pure overhead. The learner evidence
above narrows this further: real continuous models compress only **1.02×–1.15×**,
and the existing `representatives` path is already much stronger. Hash-consed
subterm sharing is likewise workload-specific. It helps when a workload
repeatedly reuses subterms, but against the flat leftmost representation that
SolePostHoc actually uses it costs **≈16.8× more allocations** and leaves a
larger live footprint. Neither mechanism is a general speedup. The consumer
min / median / max columns are first-use, steady-state, and fresh-family churn
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
steady reuse, or fresh-family churn; this page provides evidence for each, not a
universal speedup.

## Correctness and coverage

`benchmark/differential.jl` uses the same fixed seed and passes its syntax and
semantic checks before timings. Run package tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
