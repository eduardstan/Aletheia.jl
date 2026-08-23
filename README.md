# Aletheia.jl

Aletheia is a syntax-first Julia foundation for propositional, modal, many-valued,
and first-order logic. It provides pooled immutable formulas, extensible
connectives, parsing and printing, truth algebras (including finite FLew
non-chain families), relational frames and models, Compass and RCC relation
families, evaluation, bisimulation and contraction, standard translation, and
ILP foundations. It also includes a dataset protocol and an opt-in SoleLogics
compatibility layer. Aletheia is a foundation: it is **not** a prover and it is
**not** a learner.

**[Read the documentation](https://eduardstan.github.io/Aletheia.jl/)**

## Install

Aletheia is not yet in the Julia General registry. Install the current package
from this repository with either:

```julia
using Pkg
Pkg.develop(url="https://github.com/eduardstan/Aletheia.jl.git")
# or: Pkg.add(url="https://github.com/eduardstan/Aletheia.jl.git")
```

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

## Measurements

Representative rows from the [full measured results](https://eduardstan.github.io/Aletheia.jl/results/) compare
like-for-like APIs (SoleLogics / Aletheia):

- Parsing, depth 2: **6.81×** (37.58 μs / 5.52 μs).
- Propositional `check`, depth 6: **9.67×** (42.27 μs / 4.37 μs).
- Propositional `check`, depth 2: **0.92×** (1.92 μs / 2.08 μs), so not every workload improves.

These are the published quick-run medians; see the results page for conditions,
allocations, and the complete measurements.

## Modal breadth

Named Allen interval, point, Compass, and RCC relation values compose with generated
`interval_frame` and `rectangle_frame` worlds. Frame conditions are traits
(`isreflexive`, `istransitive`, `issymmetric`, `isserial`) and the named systems
`K`, `T`, `S4`, and `S5`, rather than a cross-product of frame types and
relation families. See the documentation for endpoint conventions and the RCC8
choice.

## Grounding references

- Patrick Blackburn, Maarten de Rijke, and Yde Venema, *Modal Logic*, Cambridge Tracts in Theoretical Computer Science 53, Cambridge University Press, 2001.
- Valentin Goranko, *Logic as a Tool: A Guide to Formal Logical Reasoning*, Wiley, 2016.
- Wolfgang Schwarz, *Logic 2: Modal Logic*, 2024 lecture notes, CC BY-NC-SA 4.0, [github.com/wo/logic2](https://github.com/wo/logic2).
- Stephen Muggleton and Luc De Raedt, “Inductive Logic Programming: Theory and Methods”, *Journal of Logic Programming* 19–20 (1994), 629–679.
- Filip Železný and Nada Lavrač (eds), *Inductive Logic Programming: 18th International Conference, ILP 2008*, LNAI 5194, Springer, 2008.

Released under the [MIT License](LICENSE).
