# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Syntax layer

- The syntax implementation lives in `src/syntax.jl` and `src/parse.jl`; it is deliberately semantic-free.
- Validate both package tests and the citation-aware docs build with `julia --project=. -e 'using Pkg; Pkg.test()'` and `julia --project=docs docs/make.jl`.
