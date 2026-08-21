# Measured results

These numbers are published with the negative results because benchmark scope
matters. The harness is human-run, not a CI gate: shared-runner timings are too
noisy. The deterministic differential suite remains outside package tests so
Aletheia never depends on SoleLogics.

## Protocol and reproduction

The authoritative commands are:

```sh
julia --project=benchmark benchmark/run.jl
julia --project=benchmark benchmark/differential.jl
```

Set `SOLELOGICS_PATH=/path/to/SoleLogics.jl` when the incumbent checkout is not
at the launch-brief default. The quick run uses five BenchmarkTools samples and
a 0.01-second per-case budget; `--deep` uses 15 samples and 0.05 seconds. It
prints Julia version, CPU, thread count, and checkout path. Cold-load rows use
fresh Julia processes; ordinary rows use warmed BenchmarkTools trials and
should not be compared as if they were the same kind of measurement.

The report below is the merged-base quick run on **Julia 1.12.7**, CPU
**`alderlake`**, **12 threads**, with **SoleLogics 0.13.7**. Times are medians;
the ratio is SoleLogics/Aletheia, so a ratio above 1 means Aletheia is faster.
The differential run used seed `0xA1E7_2024`, 64 formulas over seven atom names,
and passed 577/577 checks.

## Syntax and loading

| row | SoleLogics | Aletheia | ratio (S/A) |
| --- | ---: | ---: | ---: |
| parsing, depth 6 | 1.13 ms | 69.52 μs | 16.32× |
| printing, depth 6 | 166.89 μs | 48.00 μs | 3.48× |
| round-trip, depth 6 | 15.30 ms | 111.34 μs | 137.41× |
| `isequal`, chain 256 | 31.64 μs | 14 ns | 2,260× |
| cold package load | 719.69 ms | 2.52 ms | 285.41× |
| cold time to first result | 2,485.53 ms | 860.16 ms | 2.89× |

The construction rows also include shared and unshared formulas; at depths 2,
4, and 6 their ratios range from 1.62× to 2.46×. The differential test treats
pool-local integer equality and DAG subterms as deliberate representation
differences rather than pretending they are tree-occurrence semantics.

The benchmark separately guards generic `==` in fresh processes. On this
machine the incumbent's warmed chain-24 call remained 273.17 ms, while
Aletheia's was 2.89 μs; chain 32 and 64 timed out at 10 seconds on the
incumbent. This paragraph reports observable code behavior only. It is not a
claim about why the implementation was written that way.

## Interval accessibility: the loss is part of the result

A single generated `BEFORE` accessibility query is not Aletheia's strong case:

| row | SoleLogics | Aletheia | ratio (S/A) |
| --- | ---: | ---: | ---: |
| one query, generated interval `n=6` | 216 ns | 6.08 μs | 0.04× |
| full adjacency, `n=24` | 193.81 μs | 342.21 μs | 0.57× |
| end-to-end check, `n=24` | 720.50 μs | 786.28 μs | 0.92× |

The one-query row loses by about 28×. The evaluator-relevant end-to-end row is
near parity because it amortizes adjacency over the check. The current numbers
use the lazy arithmetic successor hook and the reused adjacency buffer. An
earlier allocating hook raised Aletheia's allocations from 4,093 to 17,002 at
`n=24`; that was fixed as an allocation-shape bug, not explained away as
noise. External relation families still use the generic fallback.

## Contraction: another honest loss

The theory harness uses 600 densely connected, identically labelled worlds:

| workload | raw check | contraction + check | ratio (raw / contracted) |
| --- | ---: | ---: | ---: |
| one formula | 984.90 μs | 16.20 ms | 0.06× |

Quotient construction does **not** pay for itself on one check. It may amortize
when the same quotient serves many formulas; Aletheia does not claim that
workload without a measurement.

## Deliberate gaps

The benchmark still leaves later-stage rows explicitly empty: random modal
checking, many-valued checking in the comparison harness, and future relation
fragments. RCC5 composition and 2-D point semantics are also intentionally
absent. The package's semantic/evaluation tests do cover Boolean, Gödel,
Łukasiewicz, modal, generated-frame, and custom-family behavior; an empty
comparison row is not an unimplemented package API silently presented as a win.

For source-level validation, run package tests, the JET gate, and the coverage
project described in `AGENTS.md`. The documentation build itself is
citation-aware and runs all doctests.
