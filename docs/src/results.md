# Measured results

Reproducing these measurements needs a local checkout of SoleLogics, because
Aletheia deliberately does not depend on it:

```sh
git clone https://github.com/aclai-lab/SoleLogics.jl
SOLELOGICS_PATH=$PWD/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

The numbers on this page were produced with SoleLogics 0.13.7.

`run.jl` prints Julia/CPU, the fixed seed, paired medians, allocation counts, a
correctness gate, and its wall clock. `--deep` expands the size and ratio
sweeps. Each section runs in a warmed child Julia process; GNU `timeout` kills a
section at the printed hard bound (120 s quick, 180 s deep). A timeout is
reported as data, not silently dropped. Cold-load rows are intentionally fresh
process measurements. The raw run and provenance are retained in
[`data/benchmark-run/run.txt`](https://github.com/eduardstan/Aletheia.jl/tree/main/data/benchmark-run).

The corrected quick run used Julia 1.12.7, `alderlake`, SoleLogics 0.13.7,
seed `0xA1E7_2024` (decimal 2716278820), and completed in **414.1 s
(6.9 min)**. The remeasured modal cells used **200 paired samples** and its
recorded load average was **3.83, 3.46, 3.44** (`uptime`, 1/5/15-minute
values). The extension and unshared-leaf headline cells are retained from the
previous corrected run; the raw 200-sample run is still provided for audit. The ratio is SoleLogics/Aletheia;
allocations are `count / bytes`. All cases in a section share one warmed Julia
child process, so the total does not include a package load per measured cell.

> **Correction notice.** The extension and interval headlines below are retractions
> of the earlier published values. The extension harness discarded SoleLogics'
> shared subformula memo once per world (and left normalization on), inflating
> **110.04× → 4.02×** and **336.89× → 2.38×**. The interval harness charged
> SoleLogics a `findfirst` world-position scan that Aletheia was not charged;
> the corrected deep sweep now uses an index on both sides and reports 5.11×,
6.96×, and 8.43× at n=12, 24, and 36. A subsequent audit
> found that the first corrected modal rerun used only five fixed samples: on a
> contended machine that made its medians unstable, moving **52.97× → 2.33×**
> (8/.15/depth 2) and **27.71× → 1.48×** (24/.15/depth 2) after 200 samples.
> The fixed-five cells were retracted; this is a sampling correction, not a
> change to either evaluator.
> Finally, the old contraction baseline used too few samples: **K*=11.6 → 46.7**
> after 2000 paired samples. These are not silent swaps; causes and raw artefacts
> are retained in `data/benchmark-run/`.

## How to read a row

The labels describe the inputs to the timed call. Unless a section says
otherwise, each number is the median-time sample among 200 paired observations
in a warmed child Julia process; its allocation count and bytes come from that
same observation. Construction, parsing, printing, checking, and extension setup
happen inside the timed call when the generator does so. Contraction rows use
2000 paired observations to stabilize the crossover estimate. A ratio is always **SoleLogics divided by
Aletheia**: above `1×` means Aletheia took less time, below `1×` means it took
more time, and `1×` is parity. Allocation cells are ordered the same way:
**SoleLogics count / bytes ; Aletheia count / bytes**. They are not ratios.

* **Depth** is the number of recursive levels. The ordinary syntax and
  propositional/many-valued rows use a full binary `∧` tree of depth `d`, with
  `2^d` leaves. `unshared` gives each occurrence a distinct atom name, while
  `shared` passes the same recipe child twice. Aletheia's pool preserves that
  shared node; SoleLogics' builder constructs each occurrence as it recurses. Modal formulas use the
  deterministic `modal_formula(d)` generator instead: one recursive connective
  per level (cycling `◇`, `□`, `∧q`, `∨p`) and the indicated atom leaves.
* **Worlds** is the number of worlds in the finite model. `n` in an interval
  row is the coordinate-domain size used to generate all integer intervals
  (the frame therefore contains `n*(n+1)/2` worlds), not that world count.
  `chain n` is instead a formula with `n` nested negations over one atom.
* **Density** is the probability in `[0, 1]` used independently for each
  ordered pair of worlds when generating the directed `R` edges. Thus `.15`
  and `.50` mean 15% and 50% edge probability, not a percentage of worlds;
  the graphs use the published fixed seed. In dataset rows, `uniform` means
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

| case | SoleLogics | Aletheia | ratio | allocations |
| --- | ---: | ---: | ---: | ---: |
| construction, depth 2 (unshared) | 4.29 μs | 2.00 μs | 2.15× | 37 / 1.281 KiB ; 56 / 2.594 KiB |
| construction, depth 2 (shared) | 3.60 μs | 1.74 μs | 2.07× | 37 / 1.281 KiB ; 50 / 2.203 KiB |
| parsing, depth 2 | 61.39 μs | 15.07 μs | 4.07× | 275 / 11.672 KiB ; 63 / 3.719 KiB |
| printing, depth 2 | 8.75 μs | 2.98 μs | 2.94× | 45 / 1.641 KiB ; 19 / 800 B |
| round-trip, depth 2 | 63.54 μs | 8.61 μs | 7.38× | 320 / 13.312 KiB ; 82 / 4.500 KiB |
| `isequal`, chain 16 | 2.56 μs | 14.0 ns | 182.79× | 32 / 1.469 KiB ; 0 / 0 B |
| cold package load | 722.60 ms | 8.58 ms | 84.17× | n/a |
| cold time to first result | 2,497.63 ms | 747.12 ms | 3.34× | n/a |

The load ratio is measured across fresh processes and is not attributed to the
evaluator. The equality ratio is the pool-local integer identity path versus
SoleLogics' structural comparison; it is not a claim that the APIs have the
same representation.

## Evaluation suites

The propositional rows build an unshared tree and a one-world Boolean model
with one set per distinct leaf atom, then call one per-world check on each side (`TruthDict`
for SoleLogics; indexed `Model` and sets for Aletheia). The extension rows use the same unshared formulas and parity-valued models over
empty 8-world or 32-world frames. Aletheia calls `extension` once, producing a
`BitVector`; SoleLogics calls `check` once for every world, with one shared
`use_memo` dictionary per timed invocation, and collects the answers. Both calls
disable normalization. **This is explicitly not a like-for-like API comparison:**
SoleLogics v0.13.7 has no `extension` method, so its side is the equivalent
all-world semantic loop, not a result SoleLogics does not support.

For each random-modal row, the formula is the deterministic
`modal_formula(depth)` shape described above; only the directed graph is
random, with each edge drawn at the stated density and seed `SEED + worlds +
depth`. Both sides check the first world, and normalization is disabled on the
SoleLogics call. The default atom valuation is fixed (odd worlds for `p`,
worlds divisible by three for `q`). These are therefore finite-model evaluator
samples over a fixed formula shape.

The dimensional rows construct the generated interval frame before timing.
Adjacency measures all source worlds and the `BEFORE`/`IA_L` successors;
`interval check` evaluates one diamond at the first world; IA3, IA7, and RCC5
measure all-source successor counts for their relation sets. Aletheia uses the canonical generated provider; SoleLogics uses its full
dimensional frame and enumerates `accessibles`. Both sides map targets through a
prebuilt world-position index (the canonical Aletheia `BEFORE` path uses an
arithmetic range and does not read that index). The follow-up `n=12,24,36`
sweep is the same adjacency operation.

The finite-valued rows build the same unshared depth-2 tree and one-world
finite model on each side, then ask the designated check question: SoleLogics
calls its finite-algebra check, while Aletheia checks its result against the
algebra's top value. G3 and Ł3 are three-valued chains; H4 is the shipped
four-valued non-chain algebra. The interpretation-learning row constructs four
hypotheses and eight seeded models (4–7 worlds, edge probability .35), then
scores all 32 hypothesis/interpretation pairs. SoleLogics stores model/world/
label tuples; Aletheia constructs `learning_from_interpretations` examples.
Example and hypothesis construction is outside the timed score loop, so this
is a paired score/evaluation hot path, not a comparison of learner
construction APIs. The ILP row is supported by the [raw benchmark artefact](https://github.com/eduardstan/Aletheia.jl/blob/main/data/benchmark-run/run.txt#L39):
it scores four hypotheses against eight seeded models (32 pairs; models have
4–7 worlds and edge probability .35).

| case | SoleLogics | Aletheia | ratio | allocations |
| --- | ---: | ---: | ---: | ---: |
| propositional check, depth 2 | 2.50 μs | 2.52 μs | 0.99× | 29 / 752 B ; 48 / 2.484 KiB |
| propositional check, depth 4 | 11.15 μs | 7.19 μs | 1.55× | 155 / 4.109 KiB ; 159 / 9.078 KiB |
| propositional check, depth 6 | 48.10 μs | 32.40 μs | 1.48× | 659 / 17.609 KiB ; 601 / 36.055 KiB |
| extension, 8 worlds / depth 3 | 42.22 μs | 10.51 μs | 4.02× | 739 / 28.938 KiB ; 143 / 11.641 KiB |
| extension, 32 worlds / depth 4 | 172.54 μs | 72.42 μs | 2.38× | 2,099 / 89.266 KiB ; 655 / 160.078 KiB |
| random modal, 8 worlds / .15 / depth 2 | 5.61 μs | 2.41 μs | 2.33× | 153 / 5.828 KiB ; 64 / 4.438 KiB |
| random modal, 24 worlds / .15 / depth 2 | 7.39 μs | 4.98 μs | 1.48× | 191 / 8.594 KiB ; 96 / 14.062 KiB |
| random modal, 8 worlds / .50 / depth 2 | 5.86 μs | 2.38 μs | 2.46× | 153 / 6.000 KiB ; 64 / 4.438 KiB |
| random modal, 24 worlds / .50 / depth 2 | 7.70 μs | 4.74 μs | 1.62× | 185 / 9.859 KiB ; 96 / 14.062 KiB |
| random modal, 8 worlds / .15 / depth 4 | 14.88 μs | 2.65 μs | 5.62× | 337 / 11.750 KiB ; 74 / 4.891 KiB |
| random modal, 24 worlds / .15 / depth 4 | 18.45 μs | 5.08 μs | 3.63× | 409 / 17.703 KiB ; 106 / 14.516 KiB |
| random modal, 8 worlds / .50 / depth 4 | 15.74 μs | 2.56 μs | 6.15× | 341 / 12.234 KiB ; 74 / 4.891 KiB |
| random modal, 24 worlds / .50 / depth 4 | 19.32 μs | 5.13 μs | 3.76× | 406 / 20.781 KiB ; 106 / 14.516 KiB |
| interval adjacency, n=6 | 1.54 μs | 648.0 ns | 2.38× | 107 / 5.094 KiB ; 100 / 3.656 KiB |
| Allen BEFORE check, n=6 | 15.66 μs | 7.17 μs | 2.18× | 230 / 32.234 KiB ; 176 / 22.109 KiB |
| finite chain G3 check, depth 2 | 3.21 μs | 2.21 μs | 1.45× | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| finite chain Ł3 check, depth 2 | 2.13 μs | 2.08 μs | 1.02× | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| non-chain H4 check, depth 2 | 3.00 μs | 2.11 μs | 1.42× | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| learning from interpretations, 8 models / 4 hypotheses | 261.45 μs | 79.41 μs | 3.29× | 6,354 / 226.531 KiB ; 1,928 / 118.344 KiB |

The extension comparison is explicitly an equivalent all-world check loop on
SoleLogics because it has no `extension` API; it is not labelled as a win over
an operation SoleLogics does not have. Modal rows use the fixed seed above and
disable normalization to isolate evaluation. The ILP row constructs
`learning_from_interpretations` examples and scores hypotheses over all
interpretations through the check/eval loop.

The corrected extension ratios reflect allocation shape: Aletheia evaluates the
formula DAG once into a `BitVector`, while the equivalent SoleLogics all-world
loop still performs one shared-memo evaluation per invocation. The old allocation
headline (12,604 and 78,436) is retracted because it came from discarding that
memo once per world. Aletheia's relation adjacency is cached on the reused
`Model` after its first check, while SoleLogics rebuilds its structural memo per
call. Thus the modal rows are warm repeated-model measurements, not first-call
comparisons; the asymmetry is intentional and labelled.

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

The earlier n=12/24/36 values are retracted: `findfirst` was a harness-added
linear position scan on the SoleLogics side only. The corrected run uses a
prebuilt position dictionary for both loops; its remaining difference is the
canonical Aletheia arithmetic range versus SoleLogics' `accessibles` traversal,
not a hidden scan. The deep sweep was measured separately with per-cell load averages recorded in
`data/benchmark-run/interval-deep.txt`; its raw values are in `data/benchmark-run/interval-deep.txt`.
The same corrected quick run measured the consumer subsets at n=6: IA3 57.80 μs
vs 8.87 μs (3,048 vs 273 allocations), IA7 43.78 μs vs 23.09 μs (2,484 vs 717),
and RCC5 83.75 μs vs 48.77 μs (4,104 vs 1,121), SoleLogics vs Aletheia. All
generated edges are checked against their predicates in `test/relations.jl`.

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
The protocol workers now use the same median-time/allocation pairing as the
consumer worker. A fresh SoleData checkout was unavailable in this measurement
environment, so the numeric SoleData table below is retained from the prior run
and is explicitly not presented as a new measurement; rerun the two protocol
scripts with `SOLEDATA_PATH` before updating those cells. There is one cold
real-dataset loss: 16 instances, 8 points, depth 6, modal
target `.5`, where SoleData took **0.030 ms** and Aletheia's vectorized
callback **0.044 ms**. Both figures are microsecond-scale differences at the
edge of what this harness resolves; the point is the direction, not the
magnitude. The small-formula callback/setup cost dominates there; after
memoization the same case was **0.110 ms** for SoleData versus **0.044 ms**
for Aletheia. The full decision report is published in
[`data/soledata-protocol/`](https://github.com/eduardstan/Aletheia.jl/tree/main/data/soledata-protocol).

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

## Bisimulation contraction amortisation

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

The correctness gate ran **96 seeded random labelled models** and 16 random
modal formulas per model (plus the deterministic differential suite); every
original-world truth value equalled its quotient-class value before timing.
The same gate is asserted in `test/theory.jl`, so a disagreement fails tests
rather than becoming a performance result.

`C` is one contraction; `P_orig` and `P_quot` are per-formula check times on
the original and the quotient model; `K*` is the number of formulas at which
contraction pays for itself.

| original n | quotient q | q/n | C | P_orig | P_quot | K* |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 48 | 1 | 0.021 | 232.16 μs | 6.24 μs | 1.26 μs | 46.7 |
| 48 | 48 | 1.000 | 1.68 ms | 6.20 μs | 34.38 μs | ∞ |

`K* = C / (P_orig − P_quot)`; infinity means the quotient is slower per
formula or there is no positive saving. Measured total crossover (raw original
batch / contraction plus quotient batch) was:

| q/n | K=1 | K=8 | K=32 |
| ---: | ---: | ---: | ---: |
| 0.021 | 0.006 ms / 0.233 ms | 0.057 ms / 0.249 ms | 0.322 ms / 0.359 ms |
| 1.000 (already minimal) | 0.007 ms / 1.710 ms | 0.061 ms / 2.002 ms | 0.409 ms / 13.124 ms |

The earlier `K*=11.6` is retracted: its five-sample `P_orig` was not stable.
With 2000 paired observations, contraction pays back at **K*=46.7** for this
q/n≈0.02 model. The displayed batch curve has not crossed by K=32 (the new
estimate predicts a crossing near K=47). On an already minimal model contraction
is pure overhead and never pays. This is evidence for a workload-dependent rule,
not a universal threshold.

## What these results tell you

**Where the design wins.** The `isequal` row is the clearest representation
win: formulas interned in one pool carry pooled integer identity, so equality
is an integer comparison rather than SoleLogics' structural walk. The
The corrected extension rows show a smaller but still measurable mechanism:
Aletheia walks the formula DAG once into a `BitVector`, while the explicitly
labelled SoleLogics equivalent performs an all-world check loop. The earlier
110.04× and 336.89× headlines were retracted because that loop discarded its
shared memo once per world. The interval size sweep is a separate win: canonical generated interval domains
expose arithmetic successor ranges. The corrected comparison charges both sides
for position lookup; it explains the remaining n=12/24/36 gap, but not every
possible dimensional frame. The depth-4/6 propositional rows and the modal
rows also benefit from DAG evaluation and from doing no per-call
normalisation; modal traversal still makes the graph's world count and density
matter. The ILP row wins because its repeated hypotheses × interpretations
score loop reuses that evaluator path.

**Where it loses.** At propositional depth 2, the ratio is **0.99×**: one
shallow check is too little work to repay Aletheia's model/valuation and DAG
walk setup, while SoleLogics' direct `TruthDict` lookup is cheap. The
separate compatibility construction-from-recipe evidence reports **1.10×**
in its Aletheia/native convention (about **0.91×** in this page's
SoleLogics/Aletheia convention): compatibility wrappers, recipe conversion,
and repooling are fixed costs even after the allocation-free traversal fix.
The one cold real-dataset loss above has the same shape: a small formula does
not repay callback and adapter setup; memoized repeated checks remove that
fixed-cost disadvantage. These are measured losses with identifiable fixed
costs.

**Where a win does not generalise.** Contraction amortisation is workload specific: for the highly redundant
`q/n≈0.02` model the corrected 2000-sample estimate pays back at about 47
formulas, while an already-minimal model makes contraction pure overhead. The consumer min /
median / max columns are first-use, steady-state, and fresh-family churn phase
distributions; use the phase matching your workload and retain the tails. The interval fast path applies to
canonical generated domains with their arithmetic provider, not automatically
to an arbitrary user-supplied frame. Likewise, the extension ratios compare
an all-world SoleLogics loop with a named Aletheia `extension` API and should
not be read as a claim that both packages expose the same operation.

**What to expect.** If you evaluate many formulas over one finite model, expect
the extension/BitVector path to matter. If you build and compare formulas
repeatedly, expect pooled identity and DAG sharing to matter. If you check one
shallow propositional formula once, expect little difference and possibly the
0.99× outcome seen here. For a new real-data consumer, first decide whether
you are measuring cold adapter construction, steady reuse, or fresh-family
churn; this page provides evidence for each, not a universal speedup.

## Correctness and coverage

`benchmark/differential.jl` uses the same fixed seed and passes its syntax and
semantic checks before timings. Run package tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
