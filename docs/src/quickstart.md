# Quick start

```@meta
CurrentModule = Aletheia
```


## Install

Aletheia is currently developed from its repository. In the Julia package
manager, use the repository URL (or `] dev /path/to/Aletheia.jl` for a local
checkout):

```text
pkg> add https://github.com/eduardstan/Aletheia.jl.git
```

The package has no runtime dependencies. The test, documentation, benchmark,
and coverage environments are separate Julia projects.

## Build a formula

A formula starts with a `Signature`: the connectives and their arities
are explicit. A `FormulaPool` then interns atoms and branches. The
pool is intentionally explicit: it prevents formulas from unrelated languages
being confused and gives every distinct subformula a stable integer identity.

```@example quickstart
using Aletheia

signature = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
q = atom(pool, "q")
formula = branch(pool, ∧,
    branch(pool, Diamond(:R), p),
    branch(pool, Box(:R), q))

println(syntaxstring(formula))
println(nsubterms(formula))
```

The output is:

```text
⟨R⟩p ∧ [R]q
5
```

Parsing uses the same pool and signature, and printing is canonical and
parseable:

```@example quickstart
parsed = parse(pool, "⟨R⟩p ∧ [R]q")
println(parsed == formula)
println(syntaxstring(parsed))
```

```text
true
⟨R⟩p ∧ [R]q
```

## Build a frame and model

A [`Frame`](@ref) contains nonempty, ordered worlds and named accessibility
relations. A [`Model`](@ref) adds a valuation and a [`TruthAlgebra`](@ref).
This is the frame/model split used in Blackburn et al., Definitions 1.19–1.20
(pp. 16–18) [blackburn2001; Definitions 1.19–1.20, pp. 16–18](@cite).

```@example quickstart
frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(frame, BOOLEAN, Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))

println(collect(accessible(frame, :w₁, :R)))
println(interpret(p, model, :w₂))
println(check(formula, model, :w₁))
println(extension(formula, model))
```

```text
[:w₂]
true
true
Extension(Bool[1, 1])
```

`interpret` is intentionally an atom-only operation. Compound formulas go
through [`check`](@ref) (one world) or [`extension`](@ref) (all worlds). A
Boolean extension is a `BitVector`; the order is the frame's explicit index
(or its enumeration order when no index is supplied).

## A many-valued model, same formula

Changing the algebra changes the carrier and operations, not the syntax or the
evaluator. The same `formula` can be checked in a Gödel model:

```@example quickstart
many = Model(frame, GodelAlgebra(), Dict(
    "p" => Dict(:w₁ => 0.0, :w₂ => 0.7),
    "q" => Dict(:w₁ => 0.4, :w₂ => 0.9)))
println(check(formula, many, :w₁))
println(extension(formula, many))
```

```text
0.7
[0.7, 0.7]
```

For finite Gödel or Łukasiewicz chains, valuations must use one of the exact
chain levels, for example `GodelAlgebra(3)` has `0.0`, `0.5`, and `1.0`.
