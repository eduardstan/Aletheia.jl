# Aletheia/SoleLogics measurement harness

This is a human-run benchmark project. **It is not run in CI**: timings on shared
runners are noisy and are not a useful gate. The deterministic differential suite
is also kept here, rather than in Aletheia's package tests, so Aletheia never
depends on SoleLogics.

The harness currently measures the syntax layer only (construction, parsing,
printing, round-trips, and equality). Semantic suites are named and printed as
empty rows until stages 2 and 3 provide propositional, modal, interval-temporal,
and many-valued evaluators. Empty is intentional; it is not a fake benchmark.

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

The theory row is intentionally a measurement, not a promise. In the recorded quick run (600 dense, identically labelled worlds), raw checking was 0.64 ms and contraction plus checking was 16.97 ms: contraction did **not** win once quotient construction was included. That negative result is published rather than hidden; a downstream workload may amortize the quotient across many checks.
