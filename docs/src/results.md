# Measured results

The benchmark is reproducible from a fresh checkout with one command:

```sh
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

`run.jl` prints Julia/CPU, the fixed seed, medians, allocation counts, a
correctness gate, and its wall clock. `--deep` expands the size and ratio
sweeps. Each section runs in a warmed child Julia process; GNU `timeout` kills a
section at the printed hard bound (120 s quick, 180 s deep). A timeout is
reported as data, not silently dropped. Cold-load rows are intentionally fresh
process measurements.

The quick run below used Julia 1.12.7, `alderlake`, 12 threads, SoleLogics
0.13.7, seed `0xA1E7_2024` (decimal 2716278820), five samples, and completed in
**590.2 s (9.8 min)**. The ratio is SoleLogics/Aletheia; allocations are
`count / bytes`. The section process amortisation is why this is finite rather
than paying package startup once per cell.

## How to read a row

The labels describe the inputs to the timed call, not a claim that every
benchmark is a general workload. Unless a section says otherwise, each number
is the median of five samples in a warmed child Julia process; construction,
parsing, printing, checking, and extension setup happen inside the timed call
when the generator does so. A ratio is always **SoleLogics divided by
Aletheia**: above `1×` means Aletheia took less time, below `1×` means it took
more time, and `1×` is parity. Allocation cells are ordered the same way:
**SoleLogics count / bytes ; Aletheia count / bytes**. They are not ratios.

* **Depth** is the number of recursive levels. The ordinary syntax and
  propositional/many-valued rows use a full binary `∧` tree of depth `d`, with
  `2^d` leaves whose names cycle through eight atoms (`p1`–`p8`). `unshared`
  constructs each occurrence separately. `shared` passes the same recipe child
  twice; Aletheia's pool can preserve that shared node, while the incumbent
  builder constructs each occurrence as it recurses. Modal formulas use the
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
| construction, depth 2 (unshared) | 3.55 μs | 1.70 μs | 2.09× | 37 / 1.281 KiB ; 56 / 2.594 KiB |
| construction, depth 2 (shared) | 3.27 μs | 1.46 μs | 2.24× | 37 / 1.281 KiB ; 50 / 2.203 KiB |
| parsing, depth 2 | 37.58 μs | 5.52 μs | 6.81× | 275 / 11.672 KiB ; 63 / 3.719 KiB |
| printing, depth 2 | 6.53 μs | 2.55 μs | 2.56× | 45 / 1.641 KiB ; 19 / 800 B |
| round-trip, depth 2 | 47.44 μs | 8.94 μs | 5.31× | 320 / 13.312 KiB ; 82 / 4.500 KiB |
| `isequal`, chain 16 | 2.18 μs | 16.0 ns | 136.00× | 32 / 1.469 KiB ; 0 / 0 B |
| cold package load | 722.60 ms | 8.58 ms | 84.17× | n/a |
| cold time to first result | 2,497.63 ms | 747.12 ms | 3.34× | n/a |

The load ratio is measured across fresh processes and is not attributed to the
evaluator. The equality ratio is the pool-local integer identity path versus
the incumbent structural comparison; it is not a claim that the APIs have the
same representation.

## Evaluation suites

The propositional rows build an unshared tree and a one-world Boolean model
with eight atom sets, then call one per-world check on each side (`TruthDict`
for SoleLogics; indexed `Model` and sets for Aletheia). The extension rows use
the same unshared formulas and parity-valued eight-atom models over empty
8-world or 32-world frames. Aletheia calls `extension` once, producing a
`BitVector`; SoleLogics calls `check` once for every world and collects the
answers. **This is explicitly not a like-for-like API comparison:** SoleLogics
v0.13.7 has no `extension` method, so its side is the equivalent all-world
semantic loop, not an unsupported incumbent result.

For each random-modal row, the formula is the deterministic
`modal_formula(depth)` shape described above; only the directed graph is
random, with each edge drawn at the stated density and seed `SEED + worlds +
depth`. Both sides check the first world, and normalization is disabled on the
SoleLogics call. The default atom valuation is fixed (odd worlds for `p`,
worlds divisible by three for `q`). These are therefore finite-model evaluator
samples, not random formula populations.

The dimensional rows construct the generated interval frame before timing.
Adjacency measures all source worlds and the `BEFORE`/`IA_L` successors;
`interval check` evaluates one diamond at the first world; IA3, IA7, and RCC5
measure all-source successor counts for their relation sets. Aletheia uses the
canonical generated provider and its prebuilt world index; SoleLogics uses its
full dimensional frame and enumerates `accessibles`. The follow-up `n=12,24,36`
sweep is the same adjacency operation, not additional formula checks.

The finite-valued rows build the same unshared depth-2 tree and one-world
finite model on each side, then ask the designated check question: SoleLogics
calls its finite-algebra check, while Aletheia checks its result against the
algebra's top value. G3 and Ł3 are three-valued chains; H4 is the landed
four-valued non-chain. The interpretation-learning row constructs four
hypotheses and eight seeded models (4–7 worlds, edge probability .35), then
scores all 32 hypothesis/interpretation pairs. SoleLogics stores model/world/
label tuples; Aletheia constructs `learning_from_interpretations` examples.
Example and hypothesis construction is outside the timed score loop, so this
is a paired score/evaluation hot path, not a comparison of learner
construction APIs.

| case | SoleLogics | Aletheia | ratio | allocations |
| --- | ---: | ---: | ---: | ---: |
| propositional check, depth 2 | 1.92 μs | 2.08 μs | 0.92× | 29 / 752 B ; 48 / 2.422 KiB |
| propositional check, depth 4 | 10.23 μs | 4.52 μs | 2.26× | 155 / 4.109 KiB ; 91 / 5.188 KiB |
| propositional check, depth 6 | 42.27 μs | 4.37 μs | 9.67× | 659 / 17.609 KiB ; 99 / 5.641 KiB |
| extension, 8 worlds / depth 3 | 1.05 ms | 9.54 μs | 110.04× | 12,604 / 479.500 KiB ; 143 / 11.641 KiB |
| extension, 32 worlds / depth 4 | 12.29 ms | 36.48 μs | 336.89× | 78,436 / 3.120 MiB ; 339 / 80.812 KiB |
| random modal, 8 worlds / .15 / depth 2 | 7.19 μs | 2.57 μs | 2.80× | 153 / 5.828 KiB ; 64 / 4.438 KiB |
| random modal, 24 worlds / .15 / depth 2 | 8.25 μs | 5.60 μs | 1.47× | 191 / 8.594 KiB ; 96 / 14.062 KiB |
| random modal, 8 worlds / .50 / depth 2 | 5.88 μs | 2.73 μs | 2.15× | 153 / 6.000 KiB ; 64 / 4.438 KiB |
| random modal, 24 worlds / .50 / depth 2 | 7.99 μs | 5.58 μs | 1.43× | 185 / 9.859 KiB ; 96 / 14.062 KiB |
| random modal, 8 worlds / .15 / depth 4 | 17.37 μs | 2.80 μs | 6.21× | 337 / 11.750 KiB ; 74 / 4.891 KiB |
| random modal, 24 worlds / .15 / depth 4 | 21.06 μs | 6.34 μs | 3.32× | 409 / 17.703 KiB ; 106 / 14.516 KiB |
| random modal, 8 worlds / .50 / depth 4 | 18.87 μs | 3.28 μs | 5.75× | 341 / 12.234 KiB ; 74 / 4.891 KiB |
| random modal, 24 worlds / .50 / depth 4 | 20.19 μs | 7.03 μs | 2.87× | 406 / 20.781 KiB ; 106 / 14.516 KiB |
| interval adjacency, n=6 | 0.94 μs | 0.84 μs | 1.12× | 103 / 4.141 KiB ; 100 / 3.656 KiB |
| Allen BEFORE check, n=6 | 14.14 μs | 6.70 μs | 2.11× | 230 / 32.234 KiB ; 176 / 22.109 KiB |
| finite chain G3 check, depth 2 | 2.32 μs | 1.70 μs | 1.36× | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| finite chain Ł3 check, depth 2 | 2.23 μs | 2.08 μs | 1.08× | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| non-chain H4 check, depth 2 | 2.47 μs | 2.07 μs | 1.19× | 40 / 1.469 KiB ; 42 / 2.484 KiB |
| learning from interpretations, 8 models / 4 hypotheses | 235.70 μs | 71.03 μs | 3.32× | 6,354 / 226.531 KiB ; 1,928 / 115.469 KiB |

The extension comparison is explicitly an equivalent all-world check loop on
SoleLogics because it has no `extension` API; it is not labelled as an
unsupported incumbent win. Modal rows use the fixed seed above and disable
normalization to isolate evaluation. The ILP row constructs
`learning_from_interpretations` examples and scores hypotheses over all
interpretations through the check/eval loop. H4 is the landed finite
non-chain FLew algebra, not a fabricated placeholder.

The largest evaluation ratios are attributable to allocation shape: the
incumbent all-world extension loop allocates a fresh structural evaluation per
world (12,604 and 78,436 allocations), while Aletheia evaluates the formula DAG
once into a BitVector (143 and 339). The random modal ratios shrink with larger
world counts because both sides then pay relation traversal; this is measured
allocation/time behavior, not an assumed cause.

### Dimensional traversal profile and size sweep

The pre-fix Julia `Profile` trace sampled the `relation_successors` generator
at `src/dimensional.jl` while it compared every candidate world with
`target.x > source.y`; this was the per-source O(|W|) scan. The fix keeps
`accessible` lazy, but canonical interval providers now expose arithmetic
ranges to the adjacency builder. A follow-up sweep (same warmed benchmark
child, five samples) was:

| n | SoleLogics | Aletheia | allocations (incumbent ; ours) |
| ---: | ---: | ---: | ---: |
| 6 | 0.94 μs | 0.84 μs | 103 / 4.141 KiB ; 100 / 3.656 KiB |
| 12 | 19.12 μs | 2.89 μs | 442 / 33.484 KiB ; 373 / 19.563 KiB |
| 24 | 1.01 ms | 23.12 μs | 2,036 / 394.969 KiB ; 1,462 / 161.477 KiB |
| 36 | 10.43 ms | 123.36 μs | 5,054 / 1.598 MiB ; 3,358 / 693.648 KiB |

The superlinear incumbent curve confirms traversal, not fixed call overhead,
is the regression. The interval adjacency row above reuses the frame's prebuilt world index; the
index is part of Aletheia's generated-frame evaluator cache and is not rebuilt
in the hot call. The same run measured the consumer subsets at n=6: IA3
50.03 μs vs 4.69 μs (3,048 vs 211 allocations), IA7 37.81 μs vs 10.65 μs
(2,484 vs 407), and RCC5 71.00 μs vs 38.22 μs (4,104 vs 999), SoleLogics vs
Aletheia. All generated edges are checked against their predicates in
`test/relations.jl`.

## Stage 2a SoleModels consumer (corrected measurement)

This is a narrow real-consumer trial, not a standalone evaluator ratio. Each
case is encoded as `rules:points:depth:modal:shared:instances`: it creates a
supported SoleData dataset with the stated number of instances and points,
and seeded rules whose antecedents have the stated depth, modal-node
probability, and shared-subtree flag. Rule atoms are drawn from 12 scalar
conditions; internal nodes use `∧`, `∨`, or `→`, modal nodes use IA_L `◇` or
`□`, and every rule is wrapped in a global `◇`. The timed operation sums
`SoleModels.checkantecedent(rule, dataset)` over all rules. The baseline is the
installed/native SoleModels path. The routed side is a disposable patched
SoleModels copy: its adapter builds an Aletheia model family, converts each
formula, and calls Aletheia `extension`, then returns the per-instance mask.
Thus baseline versus routed is deliberately labelled as a consumer-path
comparison with a wrapper/conversion shim on the routed side, not as two
identical package calls. Dataset construction is outside the timing.

There are five gated repetitions. For each repetition, first use and steady
state each have five timed samples; churn has six. The displayed min/median/max
are across those five repetitions, and allocations/bytes are from the sample
nearest each phase's median time. First use evaluates five genuinely new
identities after compile-only warmup; steady state repeats one populated
family; churn evaluates six fresh identities. The repeated row is a run-order
diagnostic, not a new shape. Routed-only adapter, conversion, and extension
measurements are subcomponents, not extra speed headlines.

The former **12.3× cold / 15.0× warm** and later **14.9× cold / 15.1× warm**
headlines are retired.  The old cold cell mixed first-use adjacency construction
with six fresh-dataset identities and BenchmarkTools reported the minimum
allocation count over a variable sample population.  Those figures were
misleading, not an unexplained product change.

The corrected experiment uses five fixed-seed repetitions, an exact mask gate
before each timing, warmed child processes under GNU `timeout`, and file-backed
output.  It reports three distinct routed phases: first use on five genuinely
new datasets, steady state after one cache-populating call, and six-dataset
fresh-family churn.  Every allocation/byte figure is paired with the sample
nearest the median time; the within-measurement range and maximum GC time are
retained.  The full corrected distributions and endpoint loads are in
`data/al-dataset-consumer/report.md`, `data/al-dataset-consumer/corrected-repetitions/`, and `data/al-dataset-consumer/optimization-before-after.txt`.

| representative case | first use min / median / max (ms) | steady min / median / max (ms) | churn min / median / max (ms) |
| --- | ---: | ---: | ---: |
| 16 rules, depth 4, 1 instance (row 1) | 1.394 / 1.864 / 14.554 | 0.233 / 0.327 / 1.818 | 1.358 / 1.655 / 2.481 |
| 16 rules, depth 4, 16 instances (row 6) | 4.047 / 4.251 / 8.988 | 2.379 / 2.573 / 5.515 | 4.012 / 4.176 / 9.335 |
| 16 rules, depth 4, 64 instances (row 4) | 23.993 / 24.890 / 31.406 | 17.085 / 18.947 / 23.876 | 23.575 / 24.698 / 28.259 |

For row 1, paired routed allocations are **24,067 / 3,017,992 bytes** on
first use, **3,193 / 601,384** steady state, and **24,067 / 3,017,992** under
churn.  The largest sampled churn GC was 42.879 ms.  Use the steady number when
reusing a model family; budget first-use construction for each genuinely new
family; treat the churn tail as specific to workloads that continually create
families.  The mask gate passed all five repetitions (six shapes, 352 exact
rule-instance masks each), outranking every timing result.

The route now shares adjacency indexes across instances only when their world
and relation signatures are equal.  Aletheia attaches the relation cache to the
shared frame, safely independent of each model's valuation.  Before sharing,
the row-1 first-use sample was **4.356 ms, 58,539 allocations / 6,727,592
bytes**; after sharing the five-run median is **1.864 ms, 24,067 / 3,017,992**.
Steady-state allocations are unchanged.  This is a measured optimization, not
warmup that hides first use.  The change in the published numbers is explicitly
from the corrected phase labels, paired allocation sampler, and this measured
sharing optimization.

A run-order diagnostic also checked the apparent later-row degradation.  The
same case occurs at rows 3, 6, 9, 12, 15, and 18; in published order its
first-use maxima were 4.554, 8.988, 10.097, 7.455, 70.375, and 60.159 ms.  In
three additional gated repetitions with rows 13–18 run first, the corresponding
maxima were 4.409, 4.091, 4.473, 4.214, 4.268, and 4.812 ms in that same
original-row order.  The large tails did not move to the first positions, so
there is no simple monotonic position effect.  The later observations remain
published as measured spread; the diagnostic artifacts are in
`data/al-dataset-consumer/order-diagnostic-late-first/`.

## Stage 1 SoleData real-dataset protocol

This benchmark-only suite is separate from the synthetic tables above. The
explicit sweep builds seeded `ExplicitModalLogiset` datasets with 1, 8, or 32
instances and 4, 16, or 32 worlds per instance; each instance has six random
features and a directed graph. It varies formula depth, modal-node probability
(`0`, `.5`, or `1`), and uniform versus independently generated instance
frames (24 quick cases). Each formula is a seeded recursive recipe: leaves
are scalar conditions, Boolean nodes are `¬`, `∧`, `∨`, or `→`, and modal
nodes are `◇`/`□`. SoleData checks every world in every instance;
Aletheia builds a `SoleDataFamily` and calls batch or scalar `extension`. The
formula-instance-world agreement gate covered 80 formulas before timing.

The supported follow-up builds the real default `scalarlogiset` path from a
two-column DataFrame, IA3 interval relations, and its default full/one-step
memosets. Its 15 cases vary instances, points (the interval-domain input),
depth, modal-node probability, and three mixed sizes. It compares cold first
check and warm repeated check with Aletheia batch and scalar callbacks; dataset
construction and the Aletheia family adapter are outside the timed closures.
This is narrow protocol evidence, not a general real-data speed headline.
There is one cold real-dataset loss: 16 instances, 8 points, depth 6, modal
target `.5`, where SoleData took **0.030 ms** and Aletheia's vectorized
callback **0.044 ms**. The small-formula callback/setup cost dominates there;
after memoization the same case was **0.110 ms** for SoleData versus **0.044 ms**
for Aletheia. The full decision report is
`data/al-dataset-protocol/report.md`.

## Bisimulation contraction amortisation

The contraction generator makes a complete all-world relation model with binary
atom labels chosen to produce the requested quotient size. `C` times
`bisimulation_contraction`; `P_orig` checks two selected formulas on the
original model; `P_quot` checks the corresponding formulas on the precomputed
quotient model. The batch cells check `K` formulas (cycling through eight), and
the quotient total includes `C`. Each displayed per-formula value is the
median across the two selected formula cases, with five timing samples per
case. SoleLogics v0.13.7 has no corresponding contraction API, so it is
**unsupported here and has no ratio**, rather than being assigned a zero or a
loss.

The correctness gate ran **96 seeded random labelled models** and 16 random
modal formulas per model (plus the deterministic differential suite); every
original-world truth value equalled its quotient-class value before timing.
The same gate is asserted in `test/theory.jl`, so a disagreement fails tests
rather than becoming a performance result.

| original n | quotient q | q/n | C | P_orig | P_quot | K* |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 48 | 1 | 0.021 | 622.55 μs | 69.67 μs | 16.08 μs | 11.6 |
| 48 | 48 | 1.000 | 1.31 ms | 6.33 μs | 28.49 μs | ∞ |

`K* = C / (P_orig − P_quot)`; infinity means the quotient is slower per
formula or there is no positive saving. Measured total crossover (raw original
batch / contraction plus quotient batch) was:

| q/n | K=1 | K=8 | K=32 |
| ---: | ---: | ---: | ---: |
| 0.021 | 0.114 ms / 0.671 ms | 0.858 ms / 0.779 ms | 3.126 ms / 1.808 ms |
| 1.000 (already minimal) | 0.006 ms / 1.347 ms | 0.057 ms / 1.600 ms | 0.282 ms / 2.438 ms |

SoleLogics is **unsupported** for this experiment: v0.13.7 has no
bisimulation contraction API. It is not assigned a ratio.

The measured rule is: for a highly redundant model (q/n≈0.02), contraction
paid back at about 12 formulas in this run; the measured curve crossed between
K=8 and K=32. On an already minimal model contraction is pure overhead and
never pays. This is evidence for a workload-dependent rule, not a universal
threshold; the `--deep` ratio sweep is the reproducible follow-up.

## What these results tell you

**Where the design wins.** The `isequal` row is the clearest representation
win: formulas interned in one pool carry pooled integer identity, so equality
is an integer comparison rather than the incumbent's structural walk. The
extension rows show the other large mechanism: Aletheia walks the formula DAG
once into a `BitVector`, whereas the explicitly labelled incumbent equivalent
repeats a structural check for every world. That is why the 110.04× and
336.89× values are large, and why their allocation counts differ by orders of
magnitude. The interval size sweep is a separate win: canonical generated
interval domains expose arithmetic successor ranges, avoiding the incumbent's
candidate-world scan. It explains the widening `n=12,24,36` gap, but not every
possible dimensional frame. The depth-4/6 propositional rows and the modal
rows also benefit from DAG evaluation and from doing no per-call
normalisation; modal traversal still makes the graph's world count and density
matter. The ILP row wins because its repeated hypotheses × interpretations
score loop reuses that evaluator path.

**Where it loses.** At propositional depth 2, the ratio is **0.92×**: one
shallow check is too little work to repay Aletheia's model/valuation and DAG
walk setup, while the incumbent's direct `TruthDict` lookup is cheap. The
separate compatibility construction-from-recipe evidence reports **1.10×**
in its Aletheia/native convention (about **0.91×** in this page's
SoleLogics/Aletheia convention): compatibility wrappers, recipe conversion,
and repooling are fixed costs even after the allocation-free traversal fix.
The one cold real-dataset loss above has the same shape: a small formula does
not repay callback and adapter setup; memoized repeated checks remove that
fixed-cost disadvantage. These are measured losses with identifiable fixed
costs, not figures to hide behind a headline average.

**Where a win does not generalise.** Contraction amortisation is workload
specific: for the highly redundant `q/n≈0.02` model it pays back at about 12
formulas (the measured curve crosses between `K=8` and `K=32`), while an
already-minimal model makes contraction pure overhead. The consumer min /
median / max columns are first-use, steady-state, and fresh-family churn
phase distributions, not a single speed headline; use the phase matching
your workload and retain the tails. The interval fast path applies to
canonical generated domains with their arithmetic provider, not automatically
to an arbitrary user-supplied frame. Likewise, the extension ratios compare
an all-world incumbent loop with a named Aletheia extension API and should not
be read as a claim that both packages expose the same operation.

**What to expect.** If you evaluate many formulas over one finite model, expect
the extension/BitVector path to matter. If you build and compare formulas
repeatedly, expect pooled identity and DAG sharing to matter. If you check one
shallow propositional formula once, expect little difference and possibly the
0.92× outcome seen here. For a new real-data consumer, first decide whether
you are measuring cold adapter construction, steady reuse, or fresh-family
churn; this page provides evidence for each, not a universal product speedup.

## Correctness and coverage

`benchmark/differential.jl` uses the same fixed seed and passes its syntax and
semantic checks before timings. Run package tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
