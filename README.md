# Aletheia.jl

Aletheia is a Julia monorepo of focused packages built around one pooled
syntax DAG and one model/evaluation walk. `AletheiaCore` supplies syntax,
validated truth-algebra semantics, relational frames, and theory utilities;
`AletheiaData`, `AletheiaCircuits`, `AletheiaGraphs`, `AletheiaLearn`,
`AletheiaSole`, `AletheiaAudit`, and `AletheiaNeSy` provide data, probability,
graph, learning, compatibility, audit, and neural-symbolic boundaries. The
umbrella `Aletheia` re-exports them for a single-import workflow. See the
[one-engine overview](https://eduardstan.github.io/Aletheia.jl/engine/) for the
architecture and the [documentation](https://eduardstan.github.io/Aletheia.jl/).

- Pooled immutable formulas, extensible connectives, parsing and printing.
- Truth algebras, including finite FLew non-chain families.
- Relational frames and models with Allen interval, Compass, and RCC relation
  families.
- Evaluation, bisimulation and contraction, and the standard translation.
- ILP foundations and a model-family API for evaluating one formula across many
  models.
- Deterministic audit traces and explicit metric applicability.
- A neural-symbolic boundary with validated neural leaves and exact finite-case
  extraction.
- Finite distribution-semantics circuits with certified BDD compilation and
  Float64 or exact Rational weighted model counting.

## Package layout

The repository is a Julia monorepo with an umbrella and focused packages:

- `AletheiaCore` contains pooled syntax, semantics, relations, theory utilities,
  and proof-search interfaces. It has no runtime dependencies.
- `AletheiaData` contains model families and scalar-data preparation.
- `AletheiaLearn` contains clauses, refinement operators, and ILP foundations.
- `AletheiaSole` contains the opt-in compatibility vocabulary and adapters.
- `AletheiaAudit` contains deterministic artifact traces, replay, and metrics.
- `AletheiaNeSy` contains validated neural leaves and exact symbolic extraction.
- `AletheiaCircuits` contains the finite distribution-semantics front end,
  certified event diagrams, and semiring WMC.
- `AletheiaGraphs` contains typed knowledge graphs and relational frame adapters.
- `Aletheia` assembles the focused packages and re-exports the top-level API.

Use a focused package when you want a smaller dependency surface:

```julia
using AletheiaCore
using AletheiaData
using AletheiaLearn
using AletheiaSole.SoleLogics
using AletheiaCircuits
using AletheiaGraphs
using AletheiaAudit
using AletheiaNeSy
```

Existing applications can continue to use `using Aletheia`; focused imports
are available when a smaller dependency boundary is appropriate. The opt-in
compatibility namespace remains available through the umbrella. See the
[Coming from SoleLogics](https://eduardstan.github.io/Aletheia.jl/compatibility/)
on-ramp for mappings and migration scope.

## Try it in two minutes

From a terminal, clone the repository and run the first result:

```sh
git clone https://github.com/eduardstan/Aletheia.jl.git
cd Aletheia.jl
julia --project=.
```

Paste this into the Julia prompt (or save it as a script):

```jldoctest readme_quickstart
using Aletheia

signature = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
formula = parse(pool, "⟨R⟩p ∧ [R]q")
println(syntaxstring(formula))

base_frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(base_frame, BOOLEAN,
    Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))
println(check(formula, model, :w₁))

# output

⟨R⟩p ∧ [R]q
true
```

For the same steps as a runnable file, use `julia --project=. examples/quickstart.jl`.
Then continue with the [Quick start](https://eduardstan.github.io/Aletheia.jl/quickstart/) and the
[runnable examples](examples/README.md).

## Use it in your own project

Once you want Aletheia in a project of your own, add it from the repository —
it is not yet in the General registry:

```julia
using Pkg
Pkg.develop(url="https://github.com/eduardstan/Aletheia.jl.git")
# or: Pkg.add(url="https://github.com/eduardstan/Aletheia.jl.git")
```

## Measurements

The [measured results](https://eduardstan.github.io/Aletheia.jl/results/) report
five-seed medians, means, standard deviations, `[no clear winner]` labels,
allocations, and raw provenance. See that page for the workload and reproduction command.

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
- Fabrizio Riguzzi, *Foundations of Probabilistic Logic Programming: Languages, Semantics, Inference and Learning*, River Publishers, 2023.
- Adnan Darwiche and Pierre Marquis, “A Knowledge Compilation Map”, *Journal of Applied and Non-Classical Logics* (2002).
- Angelika Kimmig, Guy Van den Broeck, and Luc De Raedt, “Algebraic Model Counting”, *Journal of Applied Logic* (2017).
- Robin Manhaeve et al., “Neural Probabilistic Logic Programming in DeepProbLog”, *Artificial Intelligence* (2021); Ziyang Li, Jiani Huang, and Mayur Naik, “Scallop” (2023); and related works on the [reference shelf](references/README.md).
- “Symbols and Neurons: A Review of Symbolic XAI in Deep Learning”, *Journal of Artificial Intelligence Research* (2026), for audit-metric scope; see the [reference shelf](references/README.md).

Released under the [MIT License](LICENSE).
