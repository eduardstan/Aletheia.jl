# Aletheia.jl

Aletheia is a syntax-first Julia package for foundations of propositional,
modal, many-valued, and first-order logic. The initial layers provide explicit
similarity types, hash-consed immutable formulas, extensible connective traits,
round-trippable parsing/printing, truth algebras, relational frames, models,
and atom interpretation; compound-formula evaluation is available through `check` and `extension`.

**[Read the documentation](https://eduardstan.github.io/Aletheia.jl/)**

## Start here

From a terminal, clone the repository and run the first result:

```sh
git clone https://github.com/eduardstan/Aletheia.jl.git
cd Aletheia.jl
julia --project=.
```

Paste this into the Julia prompt (or save it as a script):

```julia
using Aletheia

signature = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
q = atom(pool, "q")
formula = parse(pool, "⟨R⟩p ∧ [R]q")
println(syntaxstring(formula))

frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(frame, BOOLEAN,
    Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))
println(check(formula, model, :w₁))
```

Expected output:

```text
⟨R⟩p ∧ [R]q
true
```

For the same steps as a runnable file, use `julia --project=. examples/quickstart.jl`.
Then continue with the [Quick start](https://eduardstan.github.io/Aletheia.jl/quickstart/) and the
[runnable examples](examples/README.md).

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
