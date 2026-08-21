# Stage 1 dataset-protocol decision report

## Loss first

The scalar-only callback has one clear loss: for the uniform case
`instances=8, worlds=8, depth=4, modal target=0.5`, scalar Aletheia took
**0.185 ms** versus SoleData's **0.018 ms** (10.3× slower).  The vectorized
callback took 0.013 ms on that same case, so this is a callback-path loss, not
an evaluator-semantics disagreement.

## Agreement gate: PASS

The gate used the installed SoleData `ExplicitModalLogiset` (SoleData 0.16.9)
and both uniform and deliberately non-uniform `SimpleModalFrame` instances.
It ran before timing with fixed seed `0xDADA_2024` (3671728164):

- 80 generated formulas;
- 1,540 formula-instance-world comparisons;
- every `Aletheia.extension` result and every per-world `Aletheia.check`
  result equalled `SoleData.check(...; perform_normalization=false)` exactly;
- uniform-frame detection identified both uniform and non-uniform families.

No disagreement was found.

## Measurement

The post-rebase run was made from main commit `89e878a` (the merged relation
enumeration optimization), on Julia 1.12.7.  Each side ran in a warmed child
process under GNU `timeout` (180 s hard bound), with output captured in a
 temporary file rather than a pipe.  Each case used five BenchmarkTools median
samples and reports time, allocation count, and allocated bytes.  The complete
24-case sweep is in `run.txt`; its case key is
`instances:worlds:depth:modal-target:uniform-frame`.

The sweep varied each requested driver independently:

- instances: 1, 8, 32;
- worlds: 4, 8, 16, 32;
- depth: 2, 4, 6;
- modal target: 0.0, 0.5, 1.0;
- uniform and non-uniform frames.

The primary comparison is vectorized Aletheia extension against the equivalent
all-world SoleData.check loop:

| comparison | cases where Aletheia wins | median SoleData/Aletheia time | median SoleData/Aletheia allocations |
|---|---:|---:|---:|
| vectorized callback | 24/24 | 77.2× | 111.4× |
| scalar callback | 23/24 | 82.1× | 78.7× |

Representative post-rebase medians (time; allocations / bytes):

| case | SoleData | Aletheia vectorized | Aletheia scalar |
|---|---:|---:|---:|
| 1:8:4:0.5:1 | 0.049 ms; 1,484 / 49,576 | 0.004 ms; 67 / 7,480 | 0.020 ms; 73 / 4,048 |
| 8:16:4:0.5:1 | 1.646 ms; 47,222 / 1,666,112 | 0.023 ms; 424 / 56,896 | 0.018 ms; 600 / 45,184 |
| 32:16:4:0.5:0 | 21.203 ms; 416,296 / 14,388,512 | 0.372 ms; 2,737 / 405,648 | 1.954 ms; 4,145 / 311,952 |
| 8:16:4:0.0:0 | 47.174 ms; 267,494 / 9,296,192 | 0.103 ms; 1,136 / 257,536 | 0.068 ms; 2,192 / 187,264 |

## Callback boundary

The vectorized callback is a real batch boundary: one callback receives all
worlds for an atom, and the evaluator produces a `BitVector`.  It reduced
allocation counts in 22/24 cases versus the scalar callback (median scalar /
vectorized allocations 1.42×).  At 32 instances it was 6.1× faster than the
scalar callback; at the small eight-instance cases scalar callbacks were often
faster because this adapter's per-batch closure and result materialization
costs dominate.  The boundary therefore does **not** destroy the bit-vector
advantage, but the adapter must keep batches materialized and avoid per-world
crossing.  This stage does not add the later SoleData optimization contract.

## Recommendation

**Start stage 2 narrowly for evaluator consumers**, subject to captain review:
the agreement gate is clean and the vectorized path wins every timed comparison
against the real SoleData check loop.  Do not represent this as a
ModalDecisionTrees speedup: that learner does not call `check`, as the hot-path
report established.  Stage 2 should first reduce callback/batch overhead and
keep the uniform-frame detection useful; the larger representatives,
aggregation, and memoization bridge remains out of scope here.
