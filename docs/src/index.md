# Aletheia.jl

Aletheia is a syntax-first Julia foundation for propositional, modal,
many-valued, first-order logic, and inductive logic programming. It is
deliberately a small set of composable layers rather than a monolithic logic
hierarchy: formulas are pooled DAG handles, semantics live in models, and
evaluation is a single walk over that DAG.

It is for people who build on logic rather than reason about one fixed logic:
if you need to construct many formulas, evaluate them over finite Kripke
models, swap the truth algebra without rewriting the evaluator, or hand modal
interpretations to a learner, this is the layer underneath that work.

Here is the whole shape of the package: a signature, a pool, a formula, a
frame, a model, and a check.

```jldoctest index
using Aletheia

signature = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
formula = parse(pool, "⟨R⟩p ∧ [R]q")

base_frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(base_frame, BOOLEAN,
    Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))

println(syntaxstring(formula))
println(check(formula, model, :w₁))

# output

⟨R⟩p ∧ [R]q
true
```

The vocabulary follows the modal-logic distinction between a similarity type,
its formulas, frames, models, and satisfaction. See Blackburn, de Rijke, and
Venema, §§1.2–1.3 (pp. 9–26) [blackburn2001; §§1.2–1.3, pp. 9–26](@cite).

## Relationship to SoleLogics

[SoleLogics.jl](https://github.com/aclai-lab/SoleLogics.jl) is the established
Julia package for symbolic and modal logic, and the foundation of the Sole
ecosystem (SoleData, SoleModels, SoleReasoners, SolePostHoc). Aletheia covers
much of the same ground with a different representation: formulas are interned
handles into an explicit pool rather than recursively typed trees, and truth
algebras are values rather than types. Because the two packages answer the same
questions, this site measures Aletheia against SoleLogics throughout — the
[measured results](results.md) chapter reports the wins and the losses — and
ships an opt-in [compatibility layer](compatibility.md) so an existing
SoleLogics consumer can be tried against Aletheia by changing one import line.

## Choose a path

- **[Quick start](quickstart.md)** — how do I install this and build my first
  formula, frame, model, and check? Every code example in the guide is a
  Documenter doctest.
- **[Syntax and design](design.md)** — why are truth values not formulas, why is
  formula identity pool-local, and why is `Box` a primitive rather than a
  negation/`Diamond` trick?
- **[Semantics and evaluation](semantics.md)** — how does a formula get a truth
  value, in Boolean, Gödel, and Łukasiewicz models?
- **[Many models, one formula](families.md)** — how do I evaluate one formula
  across a whole dataset of models?
- **[Finite FLew-algebras](algebras.md)** — what if my truth values are not a
  chain?
- **[Relations, frames, and frame classes](relations.md)** — how do I use Allen,
  RCC, or my own relation as modal accessibility, and check frame conditions?
- **[Theory utilities](theory.md)** — how do I translate to first-order logic,
  contract a model by bisimulation, or normalise a classical formula?
- **[Learning from interpretations](learning.md)** — why is a Kripke model
  already an ILP interpretation example?
- **[Measured results](results.md)** — is it fast, and where is it slower? A
  measurement report against SoleLogics, wins and losses.
- **[Development and validation](development.md)** — how do I run the tests,
  docs, benchmarks, and differential checks?
- **[Migration from SoleLogics](compatibility.md)** — which SoleLogics names
  work under Aletheia, and which have no faithful equivalent?

## Scope and limits

Aletheia supplies syntax, semantic structures, finite evaluation, a small
first-order target syntax/evaluator, theory utilities, and ILP foundations. It
does **not** ship a modal theorem prover, a first-order prover, a learner, an
RCC composition table (the relations themselves are available; composing two of
them into a disjunction of possible relations is not), or SoleLogics'
many-valued tableau engines. The [theory](theory.md) and
[learning](learning.md) chapters call these boundaries out where they matter.

The benchmark is run by hand rather than in CI, because shared-runner timings
are too noisy to publish. Its differential correctness suite lives outside the
package tests so that Aletheia never takes SoleLogics as a dependency. The
[measured results](results.md) chapter reports the full protocol, including the
workloads where Aletheia is slower.
