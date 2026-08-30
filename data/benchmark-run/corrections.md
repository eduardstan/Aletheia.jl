# Benchmark corrections and superseded runs

_Dated 2026-08-30._ This note preserves the correction history for the benchmark
results. The published results page describes only the current measurements; this
provenance note and the raw artefacts retain the superseded values and causes.

## Quick-run history

The corrected quick run used Julia 1.12.7, `alderlake`, SoleLogics 0.13.7,
and five seeds (`0xA1E7_2024`, `0x5EED_2025`, `0xC0FF_EE42`,
`0x1234_5678`, `0x9ABC_DEF0`). It records
uptime at start and end, and retains **200 paired samples per seed** (2000 for
contraction). The raw run beside this page is the provenance for every quick-run table
row below; deep sweeps and consumer trials retain their own artefacts. No values
are retained from an earlier quick run. A three-seed pilot showed
material spread in several ratios, so five seeds are used here. The full run
cost about 7.7 minutes rather than the retired 6.9-minute single-seed run; the
200 paired samples per seed were not reduced. In the final sweep, ILP ratios
ranged from **4.09× to 7.83×**, and propositional depth 2 ranged from **0.68×
to 1.37×**. Those spreads are why the rows are marked **UNSTABLE**, not hidden
behind a single precise-looking median. The first five-seed pass executed seeds sequentially, took 38.7 minutes, and
its recorded load rose from 3.00 to 6.28; it was discarded and that confound is
not used for publication. The published pass
interleaves seeds within each row and rotates their order between rows. Its load
moved from 3.76 to 3.26, and each row retains paired per-seed load readings in
`run.txt` (`seed_loads`). The rows remain unstable after this control, so the
finding is not explained away by that load drift.

## Correction notice

The extension and interval headlines below are retractions
of the earlier published values. The extension harness discarded SoleLogics'
shared subformula memo once per world (and left normalization on), inflating
**110.04× → 4.02×** and **336.89× → 2.38×**. The interval harness charged
SoleLogics a `findfirst` world-position scan that Aletheia was not charged;
the corrected deep sweep now uses an index on both sides and reports 5.11×,
6.96×, and 8.43× at n=12, 24, and 36. A subsequent audit
found that the first corrected modal rerun used only five fixed samples: on a
contended machine that made its medians unstable, moving **52.97× → 2.33×**
(8/.15/depth 2) and **27.71× → 1.48×** (24/.15/depth 2) after 200 samples.
The fixed-five cells were retracted; this is a sampling correction, not a
change to either evaluator.
Finally, the old contraction baseline used too few samples: **K*=11.6 → 41.6**
(mean **42.8 ± 8.1**, marked **UNSTABLE**) after 2000 paired samples per seed. These are not silent swaps; causes and raw artefacts
are retained in `data/benchmark-run/`.

## Extension and interval details

The corrected extension ratios reflect allocation shape: Aletheia evaluates the
formula DAG once into a `BitVector`, while the equivalent SoleLogics all-world
loop still performs one shared-memo evaluation per invocation. The old allocation
headline (12,604 and 78,436) is retracted because it came from discarding that
memo once per world. Aletheia's relation adjacency is cached on the reused
`Model` after its first check, while SoleLogics rebuilds its structural memo per
call. Thus the modal rows are warm repeated-model measurements, not first-call
comparisons; the asymmetry is intentional and labelled.

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

## SoleData protocol status

The protocol workers now use the same median-time/allocation pairing as the
consumer worker. A fresh SoleData checkout was unavailable in this measurement
environment, so the numeric SoleData table below is retained from the prior run
and is explicitly not presented as a new measurement; rerun the two protocol
scripts with `SOLEDATA_PATH` before updating those cells.

## Contraction history

The earlier `K*=11.6` is retracted: its five-sample `P_orig` was not stable.
Across five seeds and 2000 paired observations per seed, contraction pays back at
**K*=41.6** (mean **42.8 ± 8.1**, **UNSTABLE**) for this q/n≈0.02 model; the
per-seed estimates range from 35.9 to 55.8.

## Repeated result-summary references

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
matter. The ILP row has a median ratio of **5.44×** (mean **5.50× ± 1.44×**) and is
marked **UNSTABLE**; its repeated hypotheses × interpretations score loop
reuses that evaluator path, but the magnitude varies by seed.

**Where it loses.** At propositional depth 2, the seed-sweep median is **1.01×**
(mean **1.02× ± 0.26×**) and is marked **UNSTABLE**. One shallow check is too
little work to repay Aletheia's model/valuation and DAG walk setup, while
SoleLogics' direct `TruthDict` lookup is cheap. The
separate compatibility construction-from-recipe evidence reports **1.10×**
in its Aletheia/native convention (about **0.91×** in this page's
SoleLogics/Aletheia convention): compatibility wrappers, recipe conversion,
and repooling are fixed costs even after the allocation-free traversal fix.
The one cold real-dataset loss above has the same shape: a small formula does
not repay callback and adapter setup; memoized repeated checks remove that
fixed-cost disadvantage. These are measured losses with identifiable fixed
costs.

**Where a win does not generalise.** Contraction amortisation is workload specific: for the highly redundant
`q/n≈0.02` model the corrected five-seed estimate pays back at about 42
formulas (and is marked **UNSTABLE**), while an already-minimal model makes contraction pure overhead. The
learner evidence above narrows this further: real continuous models compress only
1.02×–1.15×, and the existing `representatives` path is already much stronger.
