# Changelog

All notable changes to Aletheia are documented here. The package is currently
pre-release (`0.1.0-DEV`), so there is no released version yet.

## Unreleased

- Added syntax-first pooled formulas, parsing, printing, and connective traits.
- Added truth algebras and finite FLew algebras, including non-chain families.
- Added relational frames, models, compound evaluation, Compass and RCC
  relation families, generated dimensional frames, and frame-condition traits.
- Added theory utilities including standard translation, bisimulation and
  contraction, plus ILP foundations and a dataset protocol.
- Added an opt-in SoleLogics compatibility layer, including many-valued
  compatibility adapters.
- Added runnable examples, structured documentation, and reproducible
  differential and performance benchmark harnesses.
- Fixed the canonical interval fast path for `Topo_DR`, which enumerated some
  targets twice.
- `inverse(MINIMUM)` and `inverse(MAXIMUM)` now throw instead of returning a
  relation that is not their converse. Both relate every source to one fixed
  boundary world, so their converse is not a value this vocabulary names.
- Added generated-input relation properties covering the converse law,
  involution, Allen/RCC8 JEPD, fast-path/predicate agreement, and the IA3/IA7
  coarsening unions.
