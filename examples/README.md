# Runnable examples

Run any example from the repository root with `julia --project=. examples/<name>.jl`.
Each example is a small, self-contained lesson and uses Aletheia's rich terminal displays for its models, extensions, and other domain objects. Every file carries an expected-output block, and the test suite runs each example and enforces its complete output.

- `quickstart.jl` — Parse a modal formula, build a two-world model, and inspect its satisfying worlds.
- `bisimulation.jl` — See how changing an atom label lets `◇p` distinguish otherwise bisimilar roots.
- `contraction.jl` — Inspect a bisimulation quotient and verify that it preserves an extension.
- `ilp_walkthrough.jl` — Follow θ-subsumption, lazy refinement, and a modal interpretation example.
- `interval_meets.jl` — Use Allen's MEETS relation as modal accessibility between closed intervals.
- `many_valued.jl` — Compare Gödel and Łukasiewicz values and see primitive modal folds at a dead end.
- `normal_forms.jl` — Convert a classical formula to CNF and DNF and check semantic preservation.
- `standard_translation.jl` — Compare direct modal evaluation with first-order standard translation.
- `model_family.jl` — Evaluate one formula across a family of models sharing a frame.
