# Quick start

```@meta
CurrentModule = Aletheia
```

## Install

Aletheia requires Julia 1.10 or later and is currently developed from its
repository. In the Julia package manager, use the repository URL (or
`] dev /path/to/Aletheia.jl` for a local checkout):

```text
pkg> add https://github.com/eduardstan/Aletheia.jl.git
```

The package has no runtime dependencies.

## Build a formula

A formula starts with a `Signature`: the connectives and their arities
are explicit. A `FormulaPool` then interns atoms and branches. The
pool is intentionally explicit: it prevents formulas from unrelated languages
being confused and gives every distinct subformula a stable integer identity.

```jldoctest quickstart
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

# output

⟨R⟩p ∧ [R]q
5
```

Parsing uses the same pool and signature, and printing is canonical and
parseable:

```jldoctest quickstart
parsed = parse(pool, "⟨R⟩p ∧ [R]q")
println(parsed == formula)
println(syntaxstring(parsed))

# output

true
⟨R⟩p ∧ [R]q
```

## Build a frame and model

A [`Frame`](@ref) contains nonempty, ordered worlds and named accessibility
relations. A [`Model`](@ref) adds a valuation and a [`TruthAlgebra`](@ref).
This is the frame/model split used in Blackburn et al., Definitions 1.19–1.20
(pp. 16–18) [blackburn2001; Definitions 1.19–1.20, pp. 16–18](@cite).

```jldoctest quickstart
base_frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))

println(collect(accessible(base_frame, :w₁, :R)))
println(interpret(p, model, :w₂))
println(check(formula, model, :w₁))
show(stdout, MIME"text/plain"(), model)
println()
describe(stdout, extension(formula, model), model)
println()

# output

[:w₂]
true
true
Model (2 worlds, 1 relation, BooleanAlgebra())
  Worlds (2): :w₁, :w₂
  Relations:
    :R: :w₁ → :w₂; :w₂ → :w₂
  Valuation:
    p: {:w₂}
    q: {:w₁, :w₂}
Extension (2 of 2 worlds satisfy)
  Satisfied at: :w₁, :w₂
  Unsatisfied at: (none)
```

For a labelled view of that extension in the REPL, use `describe`:

```jldoctest quickstart
describe(stdout, extension(formula, model), model)

# output

Extension (2 of 2 worlds satisfy)
  Satisfied at: :w₁, :w₂
  Unsatisfied at: (none)
```

`interpret` is intentionally an atom-only operation. Compound formulas go
through [`check`](@ref) (one world) or [`extension`](@ref) (all worlds). A
Boolean extension is a `BitVector`; the order is the frame's explicit index
(or its enumeration order when no index is supplied).

## A many-valued model, same formula

Changing the algebra changes the carrier and operations, not the syntax or the
evaluator. The same `formula` can be checked in a Gödel model:

```jldoctest quickstart
many = Model(base_frame, GodelAlgebra(), Dict(
    "p" => Dict(:w₁ => 0.0, :w₂ => 0.7),
    "q" => Dict(:w₁ => 0.4, :w₂ => 0.9)))
println(check(formula, many, :w₁))
describe(stdout, extension(formula, many), many)
println()

# output

0.7
Extension (2 worlds)
  :w₁ => 0.7
  :w₂ => 0.7
```

The example above used `GodelAlgebra()`, the full unit interval, so any value
in `[0, 1]` is legal. A finite chain such as `GodelAlgebra(3)` admits only its
own levels — `0.0`, `0.5`, `1.0` — and rejects anything else.

Each idea in this guide also exists as a runnable script under
[`examples/`](https://github.com/eduardstan/Aletheia.jl/tree/main/examples); run
one with `julia --project=. examples/quickstart.jl`.
