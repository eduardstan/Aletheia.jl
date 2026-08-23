# Stage 2a consumer: corrected first-use, steady-state, and churn measurements

## Verdict

The earlier `cold` column was a harness artefact, not a single user-facing cost.
It warmed only `datasets[1]` and then timed `datasets[2]`, so every trial paid
first-use adjacency construction for a new dataset and manufactured six
cache-cold model families.  The old `measure_cold` also used BenchmarkTools'
five-second default.  Its `Trial.allocs` and `Trial.memory` are minima over the
samples that happened to fit that budget, not allocations paired with the
median-time sample.  That is why the published baseline counts alternated
between 366,976 and 817,361.

This report replaces that column.  The corrected benchmark has three explicit
phases:

* **first use:** one compile-only dataset followed by five genuinely new
  datasets, each evaluated once;
* **steady state:** one dataset is populated once, then the same call is
  sampled five times;
* **fresh-dataset churn:** six new datasets are evaluated once each, retaining
  the sample spread and GC time to show collection pressure from this workload.

Each phase reports the median-time sample's own allocation and GC figures.  The
sample range is shown beside it; it is not discarded.  This makes an allocation
count such as `24,067 / 3,017,992 bytes` mean the allocations and bytes of the
sample whose time is printed, rather than BenchmarkTools' unrelated minimum.

## Corrected method and agreement gate

There were **five** corrected repetitions (rep-02 through rep-06).  Each used
fixed seed `0xDADA_2024`, a warmed Julia child under GNU `timeout`, file-backed
stdout/stderr, five timing samples for first use and steady state, six samples
for churn, and load readings at both endpoints.  The raw outputs and endpoint
loads are in `corrected-repetitions/` and `optimization-before-after.txt`.  The mask gate ran before timing in every
repetition and passed: six shapes and **352 exact rule-instance masks** per
baseline/routed pair.  No timing was retained from a failed gate.

The timed sampler uses `Base.gc_num()` around each call.  It chooses the sample
nearest the median elapsed time and carries that sample's allocation count,
bytes, and GC time into the reported cell; it also retains the within-measurement
minimum, maximum, and maximum GC time.  Thus the allocation figures below are
paired figures, not minima over a variable sample set.

## Load endpoints

The endpoint load averages for the five corrected repetitions are recorded in
`corrected-repetitions/loads.tsv` (columns are 1/5/15-minute averages):

| repetition | start | end |
|---:|---|---|
| 2 | 2.23 / 3.72 / 4.22 | 3.63 / 3.22 / 3.76 |
| 3 | 3.63 / 3.22 / 3.76 | 3.46 / 3.44 / 3.67 |
| 4 | 3.46 / 3.44 / 3.67 | 3.67 / 3.47 / 3.62 |
| 5 | 3.67 / 3.47 / 3.62 | 3.43 / 3.72 / 3.71 |
| 6 | 3.37 / 3.70 / 3.71 | 12.67 / 5.60 / 4.26 |

The transient rise in repetition 6 is retained rather than used to discard
samples; the timing spread is reported below.

## Routed phase distributions

Cells are **minimum / median / maximum milliseconds across the five
repetitions**.  The case encoding is `rules:points:depth:modal:shared:instances`.
The churn phase is deliberately separate from first use: it has the same
per-call first-use work but exposes the collection pressure caused by creating
many fresh model families.

| row | case | first use (ms) | steady state (ms) | fresh-dataset churn (ms) |
|---:|---|---:|---:|---:|
| 1 | `16:6:4:0.5:1:1` | 1.394/1.864/14.554 | 0.233/0.327/1.818 | 1.358/1.655/2.481 |
| 2 | `16:6:4:0.5:1:4` | 1.793/1.841/2.920 | 0.529/0.588/1.073 | 1.631/1.853/2.647 |
| 3 | `16:6:4:0.5:1:16` | 3.979/4.243/4.554 | 2.363/2.765/3.281 | 3.827/4.234/4.688 |
| 4 | `16:6:4:0.5:1:64` | 23.993/24.890/31.406 | 17.085/18.947/23.876 | 23.575/24.698/28.259 |
| 5 | `16:6:2:0.5:1:16` | 3.293/3.565/8.359 | 1.896/1.930/6.067 | 3.332/3.377/9.455 |
| 6 | `16:6:4:0.5:1:16` | 4.047/4.251/8.988 | 2.379/2.573/5.515 | 4.012/4.176/9.335 |
| 7 | `16:6:6:0.5:1:16` | 8.076/9.136/18.686 | 5.304/5.967/13.272 | 7.697/8.307/19.413 |
| 8 | `4:6:4:0.5:1:16` | 1.668/1.725/3.865 | 0.739/0.835/1.895 | 1.516/1.570/4.128 |
| 9 | `16:6:4:0.5:1:16` | 4.108/4.302/10.097 | 2.324/2.547/6.092 | 3.982/4.181/9.477 |
| 10 | `32:6:4:0.5:1:16` | 8.872/9.559/18.663 | 5.911/6.071/12.294 | 8.588/8.951/18.456 |
| 11 | `16:3:4:0.5:1:16` | 2.427/2.527/6.878 | 1.951/2.907/5.168 | 3.351/3.547/11.457 |
| 12 | `16:6:4:0.5:1:16` | 3.925/5.487/7.455 | 2.408/2.626/4.189 | 4.200/4.251/6.701 |
| 13 | `16:8:4:0.5:1:16` | 6.532/7.358/293.022 | 3.251/3.616/93.410 | 6.891/7.069/149.655 |
| 14 | `16:6:4:0.0:1:16` | 7.367/7.663/260.379 | 5.273/5.926/87.078 | 7.425/7.476/146.349 |
| 15 | `16:6:4:0.5:1:16` | 4.151/4.549/70.375 | 2.536/2.992/39.996 | 4.082/4.400/64.452 |
| 16 | `16:6:4:1.0:1:16` | 2.918/3.056/97.677 | 1.567/1.663/24.263 | 2.885/3.002/44.945 |
| 17 | `16:6:4:0.5:0:16` | 3.738/3.893/60.694 | 2.154/2.204/32.397 | 3.613/3.923/59.245 |
| 18 | `16:6:4:0.5:1:16` | 3.870/4.226/60.159 | 2.357/2.570/37.527 | 3.989/4.202/61.336 |

For comparison, the corresponding baseline/routed distributions for three
anchors are below.  These are descriptive medians, not speed guarantees; the
large baseline tails are retained.

| case | baseline first | routed first | baseline steady | routed steady | baseline churn | routed churn |
|---|---:|---:|---:|---:|---:|---:|
| row 1, 1 instance | 12.712/14.377/155.553 | 1.394/1.864/14.554 | 4.652/7.513/56.158 | 0.233/0.327/1.818 | 13.018/24.566/153.882 | 1.358/1.655/2.481 |
| row 4, 64 instances | 940.760/944.937/1027.183 | 23.993/24.890/31.406 | 377.718/385.343/423.614 | 17.085/18.947/23.876 | 951.096/1013.048/1073.252 | 23.575/24.698/28.259 |
| row 6, 16 instances | 113.332/116.689/1424.731 | 4.047/4.251/8.988 | 37.178/39.376/438.790 | 2.379/2.573/5.515 | 109.134/115.820/1360.137 | 4.012/4.176/9.335 |

For the one-rule anchor (row 1), routed first use is **1.394 / 1.864 /
14.554 ms**, steady state is **0.233 / 0.327 / 1.818 ms**, and six-dataset
churn is **1.358 / 1.655 / 2.481 ms**.  The paired allocation figures are,
respectively, **24,067 / 3,017,992 bytes**, **3,193 / 601,384 bytes**, and
**24,067 / 3,017,992 bytes**.  The largest within-churn GC sample was **42.879
ms**.  A reader reusing one family should use the steady-state number; a reader
creating a new family should budget the first-use number; a workload creating
many families should treat the churn tail as a real workload risk, not as the
ordinary first-call cost.

Row 4 (64 instances) illustrates dilution by evaluation work: first use
**23.993 / 24.890 / 31.406 ms**, steady state **17.085 / 18.947 / 23.876 ms**,
and churn **23.575 / 24.698 / 28.259 ms**.  Its paired first-use allocation
figure is **238,333 / 41,728,784 bytes**; steady state is **208,757 /
38,957,136 bytes**.

## Run-order diagnostic

The repeated-case rows are intentionally the same case:
`16:6:4:0.5:1:16` appears at rows 3, 6, 9, 12, 15, and 18.  In the
published-order repetitions, their routed first-use maximums (the maximum of
the five-repetition median-time samples) were 4.554, 8.988, 10.097, 7.455,
70.375, and 60.159 ms.  That is not monotonic in row position, although the
large observations happened in the later positions.

I then ran **three** more gated repetitions with rows 13–18 first, followed by
rows 1–12, using the same fixed seeds, sampler, timeout, and file-backed load
recording.  The permutation and raw outputs are in
`order-diagnostic-late-first/`.  The result did **not** move the large tails to
the first six positions:

| original row | position in late-first run | original-order max (ms) | late-first max (ms) |
|---:|---:|---:|---:|
| 3 | 9 | 4.554 | 4.409 |
| 6 | 12 | 8.988 | 4.091 |
| 9 | 15 | 10.097 | 4.473 |
| 12 | 18 | 7.455 | 4.214 |
| 15 | 3 | 70.375 | 4.268 |
| 18 | 6 | 60.159 | 4.812 |

Thus the current evidence rejects a simple monotonic sweep-position effect:
putting rows 13–18 first removed rather than reproduced their 60–70 ms
selected-sample tails.  The later-row observations remain real measurements,
but this intervention does not identify heap growth or fragmentation as their
cause; process-level GC/scheduling variance or another accumulating condition
would need a more controlled probe.  Readers comparing rows should treat the
published min/median/max as a distribution over the run, not as a shape-only
cost.

## First-use optimization: shared frame adjacency

The first-use construction was genuine, so widening warmup was not used to hide
it.  The route now canonicalizes each instance's two relation adjacencies and
shares one Aletheia `Frame` among instances only when the world and adjacency
signatures are equal.  Aletheia's relation adjacency cache is attached to the
frame, rather than duplicated in every valuation-bearing `Model`; models with
different valuations can therefore share indexes safely.  Non-uniform frames
remain separate.

A one-rule, six-point, one-instance before/after check on the same fixed seed
measured the route before sharing at **4.356 ms, 58,539 allocations / 6,727,592
bytes** for first use and **0.232 ms, 3,193 / 601,384** steady state.  After
sharing, the five corrected repetitions measured first use **1.394–14.554 ms
(median 1.864)** with **24,067 / 3,017,992** paired allocations, while steady
state was **0.233–1.818 ms (median 0.327)** with **3,193 / 601,384**.  The
first-use allocation reduction is about 55%; the steady-state allocation path
is unchanged.  The gate remained exact in all five after runs, so this change
was kept.  The occasional first-use and churn GC samples remain visible above.

## Why the published numbers changed

The old routed cold headline (including the 45.8 ms row-1 outlier) mixed
first-use cache construction with six-dataset churn.  The corrected report
splits those phases and records GC pressure explicitly.  The old allocation
column silently changed meaning when the five-second BenchmarkTools budget
truncated its sample population; the corrected cells select a median-time
sample and show its paired allocations.  Numbers changed because the
measurement now answers a different, labelled question and because the
measured frame-sharing optimization removed duplicated adjacency construction;
this is a correction, not an unexplained improvement.  The old aggregate
`14.9x cold / 15.1x warm` claim is therefore retired as a headline.

## Reproduction

From the repository root, set read-only SoleData and SoleModels checkout paths
and run `benchmark/dataset_consumer.jl`.  It creates disposable package copies,
runs the agreement gate first, and writes the raw table to
`data/solemodels-consumer/run.txt`.  The benchmark's subprocesses use GNU
`timeout` and file redirection, never a pipe.  Dataset construction is outside
the timed closures.  No SoleData or SoleModels package was modified.
