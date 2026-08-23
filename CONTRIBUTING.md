# Contributing

Thanks for helping build Aletheia. Before opening a pull request, please work
from a clean checkout and run the relevant checks from the repository root.

## Before your first pull request

- Run the package tests; they include the Aqua and JET checks:
  `julia --project=. -e 'using Pkg; Pkg.test()'`.
- Build the citation-aware documentation with
  `julia --project=docs docs/make.jl`.
- If your change affects compatibility or semantics, run the differential
  comparison (it needs a SoleLogics checkout):
  `SOLELOGICS_PATH=/path/to/SoleLogics.jl julia --project=benchmark benchmark/differential.jl`.
- Keep source coverage at **95% or higher**; CI enforces that floor. The
  complete coverage commands and other validation details are in
  [Development and validation](docs/src/development.md).

Performance claims must include the exact command that produced the numbers and
should use the benchmark harness described in the development guide. The full
benchmark is human-run rather than a CI job because it compares against a
separately checked-out SoleLogics package and takes minutes on a real machine;
CI runs correctness and coverage gates instead. Record benchmark conditions and
link the complete results when reporting a claim.
