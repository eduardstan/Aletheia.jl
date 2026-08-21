# Stage 2a consumer decision report

## Result first: the evaluator win survives, but the end-to-end signal is noisy

This is **not** the Stage 1 21x claim repeated at a different call site.  In
this consumer-shaped run, the end-to-end median was **15.0x warm** and
**12.3x cold** in favour of the routed path (SoleModels / routed Aletheia).
The routed path won all 18 committed sweep rows, with median allocation ratios
of 10.1x warm and 10.3x cold.  The result is useful but not yet a stable speed
claim: repeating the same 16-rule, depth-4 case on this shared runner moved the
warm routed median between roughly 2.6 ms and 40 ms, and an earlier run of the
same sweep produced a 0.88x warm loss.  The raw committed run, rather than the
best repeat, is the result to use.  The safe conclusion is **a large but noisy
win, not a promise of 21x in a real consumer**.

The end-to-end number includes the actual `checkantecedent(rule, X)` dispatch,
SoleModels rule objects, Aletheia formula conversion/cache lookup, extension
construction, and one mask per rule.  It excludes dataset construction for
both sides.  The Stage 1 evaluator-only result therefore overstated the number
that a consumer should expect.

## Agreement gate: PASS

The gate ran before every timing.  It used a fixed `MersenneTwister` seed
`0xDADA_2024` and six real `SupportedLogiset` shapes, with 48 rules (eight per
shape), **352 rule-instance masks**, and exact equality of the complete mask
files.  The sweep includes 0%, 50%, and 100% local modal formulas and rules
with a shared common subformula.  The modal antecedents use an outer grounded
`globalrel` connective and inner `IA_L` modalities, so `checkantecedent(rule,
X)` is exercised without supplying a world.

The baseline is an unmodified scratch copy of the installed SoleModels source;
its `checkantecedent` method is the package method that delegates to
`SoleLogics.check`.  The routed copy adds one scratch-only method for
`SoleData.AbstractLogiset`.  That method builds an Aletheia model family once
per dataset, translates the SoleLogics formula into an Aletheia hash-consing
pool, calls `Aletheia.extension`, and reduces each instance's world extension
to the same existential mask that the baseline check returns.  No installed
package or checkout is modified, and the scratch copies are deleted when the
harness exits.

## End-to-end sweep

The 18 rows in `run.txt` sweep rule count (1, 4, 16, 64), antecedent depth (2,
4, 6), instances (4, 16, 32), frame points (3, 6, 8), local modal share (0,
0.5, 1), and shared-subformula construction (off/on).  Each side runs in its
own warmed Julia child.  Each measurement is a five-sample BenchmarkTools
median with allocation count and bytes; a GNU `timeout` is a hard kill switch
and incomplete timing rows are represented as timeout data rather than being
silently dropped.  Child stdout and stderr go to files, never pipes.

Selected committed rows (milliseconds; the full table is the raw artifact):

| sweep | baseline cold | routed cold | baseline warm | routed warm |
|---|---:|---:|---:|---:|
| 1 rule | 133.555 | 4.536 | 68.713 | 0.278 |
| 4 rules | 23.903 | 4.928 | 22.450 | 0.679 |
| 16 rules | 84.520 | 9.002 | 34.214 | 25.088 |
| 64 rules | 1160.287 | 25.821 | 400.631 | 178.216 |
| depth 2 / 4 / 6 | 510.095 / 1834.782 / 1238.960 | 92.004 / 24.015 / 10.820 | 255.091 / 117.298 / 659.083 | 31.142 / 2.584 / 5.783 |
| instances 4 / 16 / 32 | 35.009 / 107.190 / 5671.122 | 2.022 / 17.003 / 16.516 | 12.758 / 174.087 / 1040.570 | 1.954 / 2.588 / 6.852 |
| points 3 / 6 / 8 | 167.614 / 109.112 / 121.516 | 2.778 / 108.730 / 19.555 | 59.446 / 37.779 / 145.414 | 8.249 / 2.882 / 3.541 |
| local modal share 0 / .5 / 1 | 199.525 / 104.147 / 64.463 | 11.065 / 16.976 / 6.132 | 94.795 / 38.895 / 19.679 | 5.229 / 2.546 / 1.767 |
| shared subtree off / on | 110.473 / 106.151 | 20.420 / 7.504 | 35.889 / 38.736 | 3.095 / 2.628 |

The rows with very large baseline cold values are real first-check costs from
SoleData's full memo path, not dataset construction.  The routed adapter does
not use that memo protocol, so this is deliberately a cold-vs-cold consumer
comparison.  Warm rows are the more representative repeated-rule use case.

## Where the routed time goes

The routed side measures the one-time adapter build, formula conversion, and
extension/mask path separately.  Across the committed sweep their medians
were:

| component | median | range |
|---|---:|---:|
| model-family adapter build per dataset | 1.594 ms | 0.205–11.638 ms |
| SoleLogics-to-Aletheia formula conversion for all rules | 0.135 ms | 0.016–11.638 ms |
| extension plus world-to-instance mask | 5.658 ms | 0.730–145.920 ms |

The adapter materializes one Aletheia frame/model and two relation maps per
instance.  It is paid once: on the 16-instance, 6-point baseline, it is about
0.9 ms in the small-rule rows and is larger than one warm rule evaluation; it
is clearly amortized by 16 rules.  At 32 instances or 8 points it is several
milliseconds and should not be hidden behind an evaluator-only benchmark.

The extension/mask component has essentially the routed path's allocation
profile (the median routed-warm/component allocation ratio was 1.00x), so the
remaining consumer overhead is not where the Stage 1 headline was hiding.  It
is nevertheless the least stable elapsed-time component on this runner; the
allocation counts are more reproducible than the wall-clock medians.

Shared subformulas across *different* rules do not become one cross-rule
extension.  `checkantecedent` is called once per rule and each call walks its
own Aletheia formula DAG.  The shared pool removes repeated formula-conversion
work, but it does not make the shared subtree's truth vector reusable.  The
paired shared/off rows and the separate conversion/extension measurements show
no reliable shared-rule speedup; the routed path should be treated as
independent per-rule evaluation.  This is the important boundary for any
future optimisation work.

## Recommendation

**Stage 2b: worth a narrowly scoped start.**  The real consumer reaches the
protocol with exact masks and a substantial end-to-end win, subject to the
noise and adapter-amortisation caveats above.  Keep the Sole vocabulary bridge
separate; this experiment did not add it.

**Stage 2c: do not start on this evidence alone.**  The consumer experiment
shows no cross-rule DAG reuse and does not exercise representatives,
one-step aggregation, or the memo protocol.  A 2c proposal should first state
whether it will batch several rule antecedents or persist shared evaluations;
otherwise it risks optimising a path that the actual consumer invokes
independently.  The captain should treat 2c as a new measurement decision,
not as an automatic consequence of this win.

## Reproduction and scope

Run `benchmark/dataset_consumer.jl` with `SOLEDATA_PATH` and
`SOLEMODELS_PATH` set to read-only checkouts.  It writes the raw output to
`data/al-dataset-consumer/run.txt`.  The only consumer-specific code is the
scratch route copied from `benchmark/dataset_consumer_route.jl`; no Aletheia
production source was added, and `using Aletheia` still has no SoleData
dependency.  The explicit Sole vocabulary layer and optimisation contract
remain out of scope.
