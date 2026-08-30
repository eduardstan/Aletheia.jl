# Many models, one formula

```@meta
CurrentModule = Aletheia
```

A dataset is usually not one Kripke model but many: one model per instance,
often over the same frame. [`AbstractModelFamily`](@ref) is the protocol for
that shape, and it is dependency-free — Aletheia does not know about any
particular dataset package.

An implementation supplies [`instance_count`](@ref) and
[`instance_model`](@ref); [`eachinstance`](@ref) and
[`instance_frame`](@ref) have defaults derived from those two.
[`ModelFamily`](@ref) is the concrete family over an indexable collection of
models, useful when the models are already materialized.

```jldoctest families
using Aletheia

pool = FormulaPool(Signature((¬, ∧, Diamond(:R))))
formula = branch(pool, Diamond(:R), atom(pool, "p"))

shared = Frame((:w₁, :w₂), Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
family = ModelFamily([
    Model(shared, BOOLEAN, Dict("p" => Set([:w₂]))),
    Model(shared, BOOLEAN, Dict("p" => Set{Symbol}())),
])

println(instance_count(family))
for i in 1:instance_count(family)
    println("Instance $i:")
    instance = instance_model(family, i)
    describe(stdout, extension(formula, instance), instance)
    println()
end
println(check(formula, family, 1, :w₁))

# output

2
Instance 1:
Extension (2 of 2 worlds satisfy)
  Satisfied at: :w₁, :w₂
  Unsatisfied at: (none)
Instance 2:
Extension (0 of 2 worlds satisfy)
  Satisfied at: (none)
  Unsatisfied at: :w₁, :w₂
true
```

`extension(φ, family)` returns one extension per instance, in instance order;
`extension(φ, family, i)` and `check(φ, family, i, world)` address a single
instance. Nothing is cached across instances by these calls.

## When instances share a frame

Instances frequently differ only in their valuation. [`uniform_frame`](@ref)
returns the shared frame when every instance's frame is equal, and `nothing`
otherwise; [`isuniform`](@ref) is the predicate form. Equality is checked on
the frames themselves rather than assumed from the family type.

```jldoctest families
println(isuniform(family))
println(uniform_frame(family) === shared)

# output

true
true
```

This matters for cost, not just for description: relation adjacency is cached
on the `Frame`, so instances that reuse one frame value also reuse one
adjacency index. Instances with their own frames each build their own.

## Adapting an external dataset

A consumer with its own dataset type implements the two required methods and
gets the rest:

```julia
struct MyDataset <: Aletheia.AbstractModelFamily
    rows::Vector{MyRow}
end

Aletheia.instance_count(d::MyDataset) = length(d.rows)
Aletheia.instance_model(d::MyDataset, i) = Model(frame_for(d.rows[i]), BOOLEAN, valuation_for(d.rows[i]))
```

SoleData is supported through an optional package extension. With SoleData
loaded, `Aletheia.SoleDataFamily(dataset)` adapts any
`SoleData.AbstractModalLogiset`; it builds one Aletheia `Model` per instance,
uses `SoleData.frame(dataset, i)` for its worlds and accessibility, and supplies
`SoleData.checkcondition` as the atom valuation callback. The converted frame
exposes the selected SoleData relation as `:R`, so an Aletheia formula can use
`Diamond(:R)` or `Box(:R)`. Pass `relation=...` for a multimodal SoleData frame;
leave it as `nothing` for a unimodal frame. The optional `vectorized=false`
selects the scalar callback instead of the default batch callback.

The extension does not cross SoleData's feature/channel, representative,
one-step aggregation, or memo interfaces. Those hooks remain available to
SoleData's own optimized `check` path. The [measured results](results.md)
chapter reports the differential agreement and the cost of this boundary.
