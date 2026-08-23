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

## Syntax and loading

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

## Bisimulation contraction amortisation

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

## Correctness and coverage

`benchmark/differential.jl` uses the same fixed seed and passes its syntax and
semantic checks before timings. Run package tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
