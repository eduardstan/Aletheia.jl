# Contributing

Thanks for helping build Aletheia. Before opening a pull request, please work
from a clean checkout and run the relevant checks from the repository root. On
Julia 1.10, run `julia --project=. scripts/bootstrap.jl` first so local focused
packages are developed into each test environment.

## Before your first pull request

- Run the package tests; they include the Aqua and JET checks:
  `julia --project=. -e 'using Pkg; Pkg.test()'`.
- Build the citation-aware documentation with
  `julia --project=docs docs/make.jl`.
- Format changed Julia source with
  `julia --project=format -e 'using JuliaFormatter; format(["src", "lib", "test", "benchmark", "examples", "docs"])'`
  and review the resulting diff.
- If your change affects compatibility or semantics, run the differential
  comparison (it needs a SoleLogics checkout):
  `SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/differential.jl`.
- Keep source coverage at **95% or higher**; CI enforces that floor across
  every package. Run `Pkg.test(coverage=true)` in each `lib/Aletheia*/` project
  before the coverage check. The complete validation details are in
  [Development and validation](docs/src/development.md).

Performance claims must include the exact command that produced the numbers and
should use the benchmark harness described in the development guide. The full
benchmark is human-run rather than a CI job because it compares against a
separately checked-out SoleLogics package and takes minutes on a real machine;
CI runs correctness and coverage gates instead. Record benchmark conditions and
link the complete results when reporting a claim.
