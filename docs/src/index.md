# Aletheia.jl

Aletheia is a syntax-first foundation for propositional, modal, many-valued,
first-order, and inductive logic programming experiments. It is deliberately a
small set of composable layers rather than a monolithic logic hierarchy:
formulas are pooled DAG handles, semantics live in models, and evaluation is a
single walk over that DAG.

The vocabulary follows the modal-logic distinction between a similarity type,
its formulas, frames, models, and satisfaction. See Blackburn, de Rijke, and
Venema, §§1.2–1.3 (pp. 9–26) [blackburn2001; §§1.2–1.3, pp. 9–26](@cite).

## Choose a path

- **[Quick start](quickstart.md)** installs the package and builds a formula, frame,
  model, and check in that order. Every code example in the guide is a
  Documenter doctest.
- **[Syntax and design](design.md)** explains the decisions that make the layers
  composable: truth values are not formulas, formulas have pool-local identity,
  and `Box` is not implemented as a syntactic negation/`Diamond` trick.
- **[Semantics and evaluation](semantics.md)** covers Boolean, Gödel, and Łukasiewicz
  algebras, frames, models, lazy accessibility, `check`, and `extension`.
- **[Finite FLew-algebras](algebras.md)** covers finite residuated lattices,
  non-chain examples, derived implication, and integer-indexed evaluation.
- **[Relations and frame classes](relations.md)** covers relation-family protocols,
  generated dimensional frames, Allen/RCC8 values, and correspondence schemas.
- **[Theory](theory.md)** covers the standard translation, first-order reference
  evaluation, bisimulation/contraction, classical normal forms, and the prover
  boundary.
- **[Learning from interpretations](learning.md)** makes the ILP connection concrete:
  a Kripke model is an interpretation example, so a modal learner can consume
  it without a second representation.
- **[Measured results](results.md)** publishes the comparison protocol, wins, and
  losses. It is a measurement report, not a claim that every workload is
  faster.
- **[Development and validation](development.md)** gives copy-paste test, docs,
  benchmark, and differential commands, pass markers, and measured timings.
- **[Migration from SoleLogics](compatibility.md)** is the consumer-derived mapping and gap
  inventory. It is the one migration page; the other chapters do not duplicate
  it.

## What the package does not pretend to be

Aletheia supplies syntax, semantic structures, finite evaluation, a small
first-order target syntax/evaluator, theory utilities, and ILP foundations. It
does **not** ship a modal theorem prover, a first-order prover, a learner, RCC5
composition, or the incumbent's many-valued tableau engines. The
[theory](theory.md) and [learning](learning.md) chapters call these boundaries out
where they matter.

The design and measurements were developed in stages. The accompanying
benchmark is human-run, and its differential suite is kept outside package
tests so Aletheia never acquires the incumbent as a dependency. The source of
truth for the protocol is `benchmark/README.md`; the [results](results.md) chapter
summarises it without hiding negative rows.

## References

```@bibliography
```
