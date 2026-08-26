# Stage 1 dataset-protocol decision report

## Fair-opponent result (loss first)

There is one cold first-check loss on the real default SupportedLogiset sweep:
for `16` instances, `8` points per instance (36 interval worlds), depth `6`,
and modal target `0.5`, SoleData took **0.030 ms**, versus **0.044 ms** for
Aletheia with the vectorized callback and **0.075 ms** with a scalar callback.
This is a small-formula cold case.  On the same case after memoization, SoleData
took **0.110 ms**, while Aletheia took **0.044 ms** (vectorized) and **0.075 ms**
(scalar): Aletheia wins the warm case.

The fair comparison still supports the direction, but the earlier bare-logiset
77x headline must be retired.  Against the real default path, Aletheia's
vectorized evaluator has a median advantage of **38.7x cold** and **21.2x warm**.

## Measurement-status note

The benchmark workers now pair allocation and memory with the sample nearest the
median time. This checkout did not contain a SoleData installation, so the
existing numeric tables above remain the prior run's values rather than being
quietly relabelled as corrected measurements. Re-run `dataset_protocol.jl` and
`dataset_protocol_supported.jl` with `SOLEDATA_PATH` before changing those cells.

## Agreement gates: PASS

The original explicit-logiset gate remains clean: installed SoleData 0.16.9
`ExplicitModalLogiset`, fixed seed `0xDADA_2024` (3671728164), 80 generated
formulas and 1,540 formula-instance-world cases, with exact agreement for every
Aletheia extension and per-world check.

The fair gate now uses the actual scalar path:

```julia
SoleData.scalarlogiset(data, features;
    conditions=metaconditions, relations=relations)
```

No memoization keyword is overridden: `use_full_memoization=true` and
`use_onestep_memoization=true` are the defaults when conditions and relations
are supplied.  The resulting `SupportedLogiset` has both a one-step memoset and
a full memoset.  It uses a real two-variable DataFrame of per-instance vectors,
with interval frames and IA3 relations.  The fair gate covered 80 formulas and
**4,860 formula-instance-world cases**, exact in both cold and repeated checks.

## Post-rebase measurements

Both sweeps were rerun after rebasing on current main commit `d8629b7` (the
merged allocation-free compatibility traversal).  Each section runs in a
warmed child Julia process under GNU `timeout`, writes output to a temporary
file rather than a pipe, and reports five-sample BenchmarkTools medians with
allocation counts and bytes.  SoleData is 0.16.9.  The complete raw outputs
are `run.txt` (explicit baseline) and `run-supported.txt` (fair opponent).

For the SupportedLogiset sweep, the case key is
`instances:points:depth:modal-target:uniform`; a p-point interval frame has
`p*(p+1)/2` worlds.  The 15 cases varied instances (1, 8, 16, 32), points
(3, 4, 5, 6, 7, 8), depth (2, 4, 6), and modal target (0.0, 0.5, 1.0).
SupportedLogiset frames are uniform by construction; the explicit sweep still
contains uniform and non-uniform frame cases.

| opponent / path | Aletheia callback | cases Aletheia wins | median opponent/Aletheia time | median opponent/Aletheia allocations |
|---|---|---:|---:|---:|
| SupportedLogiset, cold first check | vectorized | 14/15 | 38.7x | 22.1x |
| SupportedLogiset, cold first check | scalar | 14/15 | 40.6x | 10.6x |
| SupportedLogiset, warm repeated check | vectorized | 15/15 | 21.2x | 8.5x |
| SupportedLogiset, warm repeated check | scalar | 15/15 | 14.8x | 4.3x |
| **ExplicitModalLogiset (labelled strawman only)** | vectorized | 23/24 | 96.0x | 111.4x |
| **ExplicitModalLogiset (labelled strawman only)** | scalar | 23/24 | 109.4x | 78.7x |

Memoization paid for SoleData: the median cold/warm time ratio was 2.55x and
the allocation ratio was 2.63x.  It materially narrows Aletheia's advantage,
but does not erase it in this sweep.  The explicit numbers are retained only
as a separate labelled baseline and are not the decision headline.

## Callback boundary

The vectorized callback remains the right boundary.  On the SupportedLogiset
sweep, scalar/vectorized time was 1.19x and scalar/vectorized allocations were
1.46x (median), with the vectorized path faster in 11/15 cases.  At small cases
the batch materialization closure can lose; it does not destroy the BitVector
advantage at scale.  Aletheia performs no SoleData memoization, so the warm
comparison is deliberately against the consumer's cached repeated-check path.

## Recommendation

**Start stage 2 narrowly for evaluator consumers, subject to captain review.**
The real default SupportedLogiset comparison is still a go signal: all warm
cases and 14/15 cold cases favor Aletheia's vectorized evaluator, with exact
semantics.  Do not claim a ModalDecisionTrees training speedup: that learner
does not call `check`.  Stage 2 should focus first on callback/batch overhead
and should not begin the later representatives, aggregation, or memoization
bridge without a separate decision.
