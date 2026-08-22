# Stage 2a consumer re-measurement (stage 2b head)

## Verdict

The original **12.3× cold / 15.0× warm** figures remain representative as a
central tendency, but they do **not** survive as a stable end-to-end claim.
I repeated the unchanged stage 2a method **eight** times (the required five
plus three because the first five were visibly unstable).  Across all 18
rows and repetitions, the median of the baseline/routed ratios was **14.9×
cold** and **15.1× warm** (median of row medians: **15.1× cold** and **14.6×
warm**).  Those numbers must not be quoted without the distributions below:
several rows have multi-fold or order-of-magnitude spreads.

The answer to the parity question is **yes**.  The range includes parity or a
loss in these rows: row 1 cold (**0.25×**), row 2 cold (**0.55×**), row 3 warm
(**0.99×**), row 8 cold (**1.06×**, effectively parity), and row 13 cold
(**0.73×**).  Here a ratio is baseline/routed, so below 1× is a routed loss.
The canonical 16-rule, depth-4, 16-instance rows (6, 9, 12, 15, 18) have
median warm ratios from 13.6× to 15.1×, but their ranges still include
substantial outliers; row 6 warm reaches **1.10×** at its worst.

## Agreement gate: PASS

The gate ran before the timing in **all eight repetitions** after rebasing
onto the current `integration/dataset-protocol` head (`8040a19`, including
stage 2b).  Every gate reported fixed seed `0xDADA_2024`, six real
`SupportedLogiset` shapes, 352 rule-instance masks, and exact baseline/routed
mask-file equality.  No timing was retained from a failed gate.

The method is unchanged: disposable writable SoleModels copies, one baseline
and one routed warmed child per side, GNU `timeout`, output redirected to
files, a five-sample BenchmarkTools median per measurement, fixed rule seed,
and allocation counts/bytes.  Dataset construction is excluded from both
sides.  The per-repetition raw files are in `repetitions/`; `run.txt` is their
concatenated raw output and `repetitions/loads.tsv` records the full load
figures and timestamps.

## Per-row distributions

Each timing cell is **min / median / max / spread**, in milliseconds.  Ratio
ranges are across the eight repetitions; the parenthesized value is the ratio
of the eight-sample medians.  The case encoding is
`rules:points:depth:modal-share:shared:instances`.

| row | case | baseline cold min / median / max / spread (ms) | routed cold min / median / max / spread (ms) | baseline warm min / median / max / spread (ms) | routed warm min / median / max / spread (ms) | cold ratio range (×) | warm ratio range (×) |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1 | `16:6:4:0.5:1:1` | 10.684/11.304/12.057/1.373 | 3.725/4.501/45.799/42.074 | 4.213/4.710/4.871/0.658 | 0.205/0.232/2.493/2.288 | 0.25–3.15 (med 2.55) | 1.80–22.10 (med 20.11) |
| 2 | `16:6:4:0.5:1:4` | 25.707/26.700/28.073/2.366 | 4.341/4.750/48.344/44.003 | 9.559/10.194/11.222/1.663 | 0.525/0.577/1.194/0.669 | 0.55–6.22 (med 5.55) | 8.92–21.38 (med 16.99) |
| 3 | `16:6:4:0.5:1:16` | 89.054/91.944/1440.405/1351.351 | 6.607/7.248/74.888/68.281 | 36.898/37.264/569.893/532.995 | 2.432/2.783/37.645/35.213 | 1.25–218.01 (med 12.69) | 0.99–234.33 (med 13.63) |
| 4 | `16:6:4:0.5:1:64` | 822.262/967.328/1008.861/186.599 | 20.698/22.245/27.383/6.685 | 330.227/384.038/1274.841/944.614 | 14.466/16.249/18.148/3.682 | 35.23–46.23 (med 41.29) | 19.61–70.25 (med 23.62) |
| 5 | `16:6:2:0.5:1:16` | 22.840/26.294/312.902/290.062 | 5.518/6.499/6.969/1.451 | 10.415/12.623/183.942/173.527 | 1.812/2.119/2.255/0.443 | 3.68–47.05 (med 4.09) | 5.43–86.68 (med 5.98) |
| 6 | `16:6:4:0.5:1:16` | 91.995/108.418/1329.756/1237.761 | 6.669/7.159/68.638/61.969 | 34.484/38.678/507.606/473.122 | 2.545/2.708/35.292/32.747 | 1.52–199.39 (med 14.66) | 1.10–190.54 (med 13.60) |
| 7 | `16:6:6:0.5:1:16` | 1148.769/1212.387/13954.246/12805.477 | 10.281/11.392/148.044/137.763 | 484.346/529.029/568.709/84.363 | 6.058/6.543/7.491/1.433 | 94.26–113.51 (med 106.91) | 67.49–86.02 (med 81.45) |
| 8 | `4:6:4:0.5:1:16` | 34.383/35.783/37.811/3.428 | 2.193/2.354/33.680/31.487 | 12.181/13.716/15.084/2.903 | 0.772/0.975/12.579/11.807 | 1.06–17.02 (med 15.16) | 1.12–17.96 (med 14.04) |
| 9 | `16:6:4:0.5:1:16` | 99.760/108.862/116.358/16.598 | 6.574/7.256/73.111/66.537 | 33.950/39.206/51.086/17.136 | 2.610/2.772/28.032/25.422 | 1.51–16.47 (med 14.73) | 1.38–19.57 (med 13.81) |
| 10 | `32:6:4:0.5:1:16` | 367.101/416.606/4658.775/4291.674 | 14.400/15.530/152.168/137.768 | 130.268/147.894/1699.996/1569.728 | 6.186/6.570/61.269/55.083 | 23.27–30.62 (med 26.83) | 18.45–137.37 (med 22.73) |
| 11 | `16:3:4:0.5:1:16` | 169.300/179.029/191.343/22.043 | 2.650/2.960/3.293/0.643 | 62.878/67.971/72.275/9.397 | 1.853/2.106/2.525/0.672 | 52.92–67.72 (med 59.79) | 26.53–36.84 (med 32.82) |
| 12 | `16:6:4:0.5:1:16` | 102.748/109.607/117.880/15.132 | 6.703/7.386/7.935/1.232 | 34.605/40.321/43.933/9.328 | 2.676/2.814/4.260/1.584 | 13.36–16.35 (med 15.21) | 9.84–16.06 (med 13.74) |
| 13 | `16:8:4:0.5:1:16` | 115.519/124.534/132.501/16.982 | 17.325/18.242/171.133/153.808 | 39.684/43.766/82.087/42.403 | 3.599/3.707/4.086/0.487 | 0.73–7.63 (med 6.77) | 10.64–20.09 (med 12.13) |
| 14 | `16:6:4:0.0:1:16` | 184.680/194.748/204.305/19.625 | 9.755/10.436/133.405/123.650 | 88.412/95.156/1087.794/999.382 | 5.535/5.961/54.766/49.231 | 1.44–20.94 (med 18.35) | 1.68–196.53 (med 15.85) |
| 15 | `16:6:4:0.5:1:16` | 106.064/110.574/1302.885/1196.821 | 6.651/7.541/75.299/68.648 | 36.415/39.827/77.612/41.197 | 2.581/2.938/3.371/0.790 | 1.50–173.93 (med 15.11) | 12.13–25.72 (med 13.65) |
| 16 | `16:6:4:1.0:1:16` | 68.933/70.892/73.024/4.091 | 5.801/6.376/14.089/8.288 | 19.203/20.867/22.813/3.610 | 1.508/1.756/16.365/14.857 | 5.18–12.49 (med 11.12) | 1.29–13.68 (med 11.81) |
| 17 | `16:6:4:0.5:0:16` | 108.240/117.093/128.411/20.171 | 6.785/7.600/101.570/94.785 | 34.356/38.713/40.971/6.615 | 2.289/2.467/22.594/20.305 | 1.19–17.29 (med 15.72) | 1.77–16.74 (med 15.32) |
| 18 | `16:6:4:0.5:1:16` | 106.883/113.297/129.079/22.196 | 7.196/7.398/8.557/1.361 | 36.927/41.492/500.642/463.715 | 2.445/2.713/12.363/9.918 | 12.49–17.37 (med 15.46) | 13.75–40.50 (med 15.11) |

The spread is the max minus min, not a confidence interval.  The wide spreads
are the result, not noise removed from the result.

## Load and allocation checks

The machine was not literally idle for this run: one-minute load at repetition
start ranged from 1.09 to 5.27 on 12 CPUs.  These are the recorded endpoint
figures (the raw files retain all five `/proc/loadavg` fields):

| rep | start loadavg (1/5/15m) | end loadavg (1/5/15m) | exit |
|---:|---|---|---:|
| 1 | 1.09 / 1.04 / 1.37 | 2.59 / 2.18 / 1.80 | 0 |
| 2 | 2.17 / 2.11 / 1.78 | 2.66 / 2.53 / 2.10 | 0 |
| 3 | 2.66 / 2.53 / 2.10 | 5.27 / 4.01 / 3.06 | 0 |
| 4 | 5.27 / 4.01 / 3.06 | 2.15 / 3.33 / 3.20 | 0 |
| 5 | 2.15 / 3.33 / 3.20 | 4.27 / 3.55 / 3.23 | 0 |
| 6 | 2.36 / 3.14 / 3.10 | 2.66 / 3.25 / 3.21 | 0 |
| 7 | 2.66 / 3.25 / 3.21 | 3.32 / 3.00 / 3.08 | 0 |
| 8 | 3.32 / 3.00 / 3.08 | 3.07 / 3.10 / 3.09 | 0 |

Load provides evidence against blaming every outlier on a competing full test
suite, but it does not explain the variance by itself.  For example, the row 6
baseline-cold outlier (1329.756 ms) occurred in repetition 6 at load
2.36→2.66, and the row 3 routed-warm outlier (26.547 ms) occurred in
repetition 1 at 1.09→2.59.  Conversely, the largest baseline-cold row 7 value
(13954.246 ms) occurred at 2.66→3.32.  There is no monotone relationship
between endpoint load and elapsed time.  The machine load contributed
contention (and the endpoints cannot detect a transient spike), but the
remaining instability is intrinsic to the measured process/scheduling and is
not established as external contention alone.

Allocation counts were checked independently of elapsed time:

| measurement | rows with varying allocation counts |
|---|---|
| baseline cold | row 3: 366976, 817361; row 6: 366976, 817361; row 7: 4454512, 7151883; row 10: 1329728, 2649343; row 15: 366976, 817361 |
| routed cold | none (all 8 repetitions identical) |
| baseline warm | none (all 8 repetitions identical) |
| routed warm | none (all 8 repetitions identical) |
| adapter | none (all 8 repetitions identical) |
| formula conversion | none (all 8 repetitions identical) |
| extension/mask | none (all 8 repetitions identical) |

All routed measurements and all warm measurements were allocation-deterministic.
Baseline cold allocation counts varied in five rows, with the alternate counts
shown above.  This is a genuine nondeterministic path in the incumbent cold
measurement (likely its memoization/first-check path), not an averageable timing
noise source.  It is reported as a defect/measurement finding rather than
silently discarded.  No timeout occurred.

## Stage 2b comparison

The pre-stage-2b committed single run had a median of per-row ratios of
**12.33× cold / 15.01× warm** (the published 12.3× / 15.0×).  On the current
stage-2b head, the repeated median is **14.9× / 15.1×** across all samples
(**15.1× / 14.6×** using row medians).  The new distributions are broad enough
that this difference is not evidence of a stage 2b movement.  The stage 2b
vocabulary changes therefore show **no measurable systematic shift** here,
while the mask gate remains exact.

## Publication recommendation

Publish the distributions, not a single headline: the central tendency still
supports a substantial typical win, but the end-to-end result is unstable and
has parity/loss rows.  Do not describe 12–15× as a guaranteed per-row speedup,
and do not start a follow-up optimization based on the median alone until the
baseline cold allocation nondeterminism and the intrinsic wall-clock variance
are understood.

## Reproduction and scope

Run `benchmark/dataset_consumer.jl` with `SOLEDATA_PATH` and
`SOLEMODELS_PATH` set to read-only checkouts.  It writes one raw result per
invocation to `DATASET_CONSUMER_RESULT`; the repeated invocation artifacts in
this report were made without modifying an installed package or checkout.
The consumer route remains benchmark-only and no SoleData dependency was added
to Aletheia production code.
