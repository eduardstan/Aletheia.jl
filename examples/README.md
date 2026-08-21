# Runnable examples

Run any example from the repository root with `julia --project=. examples/<name>.jl`.
Each one uses only Aletheia and ends with a statement of what it demonstrated.
Cold Julia startup dominates these timings; each is roughly 2–5 seconds on a laptop.

- `quickstart.jl` — How do I parse, print, build a two-world model, and check a formula? (~2 s)
- `interval_meets.jl` — How does Allen MEETS become modal accessibility, and which endpoints/worlds are used? (~2 s)
- `bisimulation.jl` — Are two labelled roots bisimilar, and can `◇p` separate them after relabelling? (~2 s)
- `contraction.jl` — Does bisimulation contraction reduce worlds without changing formula values? (~2 s)
- `standard_translation.jl` — Does first-order standard translation agree with direct modal evaluation? (~2 s)
- `normal_forms.jl` — Do CNF and DNF conversions preserve a classical formula's extension? (~2 s)
- `many_valued.jl` — Where do Gödel and Łukasiewicz evaluation genuinely differ? (~2 s)
- `ilp_walkthrough.jl` — How do θ-subsumption, refinement, and interpretation wrappers fit together? (~2 s)
