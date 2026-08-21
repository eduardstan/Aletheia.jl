# Aletheia/SoleLogics measurement harness

This is a human-run benchmark project. **It is not run in CI**: timings on shared
runners are noisy and are not a useful gate. The deterministic differential suite
is also kept here, rather than in Aletheia's package tests, so Aletheia never
depends on SoleLogics.

The harness measures the syntax layer (construction, parsing, printing,
round-trips, and equality) plus guarded generated interval-temporal and theory-contraction cases. The interval row compares Aletheia's generated Allen-before frame access
with SoleLogics' IA-L access; every incumbent call runs in a fresh process with
a timeout. Propositional random-frame, general modal, and many-valued rows
remain explicitly empty until their later benchmark stages.

## Reproduce

The incumbent checkout is expected at the path used by the launch brief. Set
`SOLELOGICS_PATH` when it is elsewhere:

```sh
julia --project=benchmark benchmark/run.jl
# optional slower/deeper diagnostic run:
julia --project=benchmark benchmark/run.jl --deep
# or, for the deterministic correctness comparison:
julia --project=benchmark benchmark/differential.jl
SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/run.jl
```

`run.jl` develops the two local checkouts into the benchmark environment and
instantiates `BenchmarkTools`. The default **quick** run uses 5 samples and a
0.01-second per-case budget, with bounded formula sizes, and is intended to
finish in about five minutes including cold package processes. `--deep` raises
the per-case budget to 15 samples/0.05 seconds and expands the size range for
occasional diagnostics; it is not the default reproducibility command. The generated benchmark `Manifest.toml` is local
machine state and is not committed. Every benchmark run prints Julia, CPU,
thread count, sample budget, and the incumbent checkout. `BenchmarkTools` reports
median time, allocations, and bytes; the table reports allocation counts and the
ratio `SoleLogics/Aletheia` (larger than 1 means Aletheia is faster).

The differential run uses the fixed seed `0xA1E7_2024`, prints it, generates 64
random formulas over seven atom names, and tests canonical structure, parser and
printer round trips, equality decisions, and subformula sets. The two deliberate
representation differences (pool-local integer equality and DAG subterms versus
tree occurrence lists) are documented in `differential.jl`; no unexplained
exception is suppressed.

Cold load and time-to-first-result rows use fresh Julia subprocesses, while
ordinary rows use `BenchmarkTools.@benchmark`. These are separate measurements
and should not be compared as if they were the same kind of trial.

### Equality note

The equality range reports `isequal`, the incumbent's explicit structural
comparison, and separately reports its generic `==` behavior. The `==` rows
make a guarded first call and then a second call in the same fresh process;
the displayed time and ratio use the second (warmed) call, while each cell also
prints both timings. On this machine `isequal` returns for chains of 16/64/256
nodes, while `==` is already `>10s` at 32. At chain 24, the first and second
`==` calls are both hundreds of milliseconds, so this is not merely compiler
startup; the timeout cells explicitly say when a second call is unavailable.
This is not a harness substitution: SoleLogics defines
`Base.isequal(::Formula, ::Formula)` and recursively compares `tree` in
`src/types/syntactical.jl` (including `Base.isequal(::SyntaxTree,...)`), but
defines no corresponding `==` method for `SyntaxTree` (`@which` resolves to
Julia's generic `Base.:(==)`). The generic field-wise comparison of nested
formula values is pathological. `SyntaxBranch`'s field is actually
`NTuple{N,SyntaxTree} where N` rather than a depth-parameterized concrete child
type, so we do not claim a nested-concrete-type cause without evidence. We do
not change or work around the incumbent; the guarded `==` rows preserve the
finding.

### Interval-temporal amortization

The original `generated IA-before` row is a single lazy accessibility query
and remains an honest footnote. The operative evaluator measurements build the
full row/column adjacency shape and create a fresh model for each end-to-end
check, so one-time model-local adjacency construction is included.

The **before** run (before `relation_successors`) was:

| row | SoleLogics | Aletheia | ratio (S/A) | allocations |
| --- | ---: | ---: | ---: | ---: |
| generated IA-before | 354 ns | 6.91 μs | 0.05x | 6 / 95 |
| full adjacency n=6 (21 worlds) | 1.78 μs | 3.03 μs | 0.59x | 106 / 157 |
| end-to-end check n=6 | 16.77 μs | 9.28 μs | 1.81x | 247 / 259 |
| full adjacency n=12 (78 worlds) | 36.83 μs | 352.94 μs | 0.10x | 446 / 764 |
| end-to-end check n=12 | 74.45 μs | 88.32 μs | 0.84x | 745 / 1036 |
| full adjacency n=24 (300 worlds) | 216.38 μs | 493.12 μs | 0.44x | 2047 / 4093 |
| end-to-end check n=24 | 759.09 μs | 1.03 ms | 0.74x | 2852 / 5171 |

The **after** run (same quick suite, after the hook and arithmetic generated
frame paths) was:

| row | SoleLogics | Aletheia | ratio (S/A) | allocations |
| --- | ---: | ---: | ---: | ---: |
| generated IA-before | 316 ns | 6.14 μs | 0.05x | 6 / 98 |
| full adjacency n=6 (21 worlds) | 1.66 μs | 3.36 μs | 0.49x | 106 / 202 |
| end-to-end check n=6 | 16.98 μs | 8.18 μs | 2.08x | 247 / 320 |
| full adjacency n=12 (78 worlds) | 18.55 μs | 36.31 μs | 0.51x | 446 / 1534 |
| end-to-end check n=12 | 81.53 μs | 86.84 μs | 0.94x | 745 / 1806 |
| full adjacency n=24 (300 worlds) | 180.56 μs | 1.05 ms | 0.17x | 2047 / 17002 |
| end-to-end check n=24 | 663.66 μs | 1.13 ms | 0.59x | 2852 / 18427 |

These are remeasurements after merging the theory stage into the branch. The
hook materially improves Aletheia's n=12 adjacency construction versus the
pre-hook row (353 μs → 36.3 μs), but the n=24 row is highly variable (493 μs
pre-hook versus 1.05 ms here). The hook does **not** close the gap reliably:
Aletheia remains 1.70x slower end-to-end at n=24, and the single-query row
remains about 19x slower. The n=6 end-to-end case is 2.08x faster for Aletheia;
n=12 is effectively tied at 0.94x.

The hook is optional: generated interval, rectangle, and point frames provide
arithmetic successor paths for their built-in relation families, while an
external family that only defines `relation_holds` receives `nothing` and uses
the generic predicate filter. The external-family tests cover both paths.

### Theory contraction

The theory row is intentionally a measurement, not a promise. In the merged-base
quick run (600 dense, identically labelled worlds), raw checking was 976.77 μs
and contraction plus checking was 16.05 ms (0.06x): contraction did **not**
win once quotient construction was included. That negative result is published
rather than hidden; a downstream workload may amortize the quotient across many
checks.
