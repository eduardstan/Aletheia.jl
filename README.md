# Aletheia.jl

Aletheia is a syntax-first Julia package for foundations of propositional,
modal, many-valued, and first-order logic. The initial layers provide explicit
similarity types, hash-consed immutable formulas, extensible connective traits,
round-trippable parsing/printing, truth algebras, relational frames, models,
and atom interpretation; compound-formula evaluation is available through `check` and `extension`.

## Grounding references

- Patrick Blackburn, Maarten de Rijke, and Yde Venema, *Modal Logic*, Cambridge Tracts in Theoretical Computer Science 53, Cambridge University Press, 2001.
- Valentin Goranko, *Logic as a Tool: A Guide to Formal Logical Reasoning*, Wiley, 2016.
- Wolfgang Schwarz, *Logic 2: Modal Logic*, 2024 lecture notes, CC BY-NC-SA 4.0, [github.com/wo/logic2](https://github.com/wo/logic2).
- Stephen Muggleton and Luc De Raedt, “Inductive Logic Programming: Theory and Methods”, *Journal of Logic Programming* 19–20 (1994), 629–679.
- Filip Železný and Nada Lavrač (eds), *Inductive Logic Programming: 18th International Conference, ILP 2008*, LNAI 5194, Springer, 2008.

Released under the [MIT License](LICENSE).

## Modal breadth

Named Allen interval, point, and RCC8 relation values compose with generated
`interval_frame` and `rectangle_frame` worlds. Frame conditions are traits
(`isreflexive`, `istransitive`, `issymmetric`, `isserial`) and the named systems
`K`, `T`, `S4`, and `S5`, rather than a cross-product of frame types and
relation families. See the documentation for the endpoint conventions and the
RCC8 choice (the incumbent-compatible seven-relation list is `RCC8_BASICS`;
formal `RCC8_RELATIONS` also includes equality). RCC8 is selected because it is the
incumbent's complete topological fragment; RCC5 composition is left for a later
stage.
