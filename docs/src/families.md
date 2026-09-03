# Many models, one formula

```@meta
CurrentModule = Aletheia
```

`[`AletheiaData`](families.md)` is the data-facing layer over `[`AletheiaCore`](api.md)`. It represents a
dataset as a family of finite models—one model per instance, often over the
same frame. [`AbstractModelFamily`](@ref) is the dependency-free protocol for
that shape, so the core does not need to know about a particular dataset
package.

An implementation supplies [`instance_count`](@ref) and
[`instance_model`](@ref); [`eachinstance`](@ref) and
[`instance_frame`](@ref) have defaults derived from those two.
[`ModelFamily`](@ref) is the concrete family over an indexable collection of
models, useful when the models are already materialized. Its models must carry
the same truth algebra; construction rejects mixed-algebra families with
`MixedAlgebraError`.

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
instance. Extension results are not cached across instances; relation adjacency
on a shared `Frame` may be cached and reused.

## When instances share a frame

Instances frequently differ only in their valuation. [`uniform_frame`](@ref)
returns a representative frame when every instance's frame is semantically
equal, and `nothing` otherwise; [`isuniform`](@ref) is the predicate form.
Equality is checked on the frames themselves; `ModelFamily` canonicalizes equal
frames so uniform models share one adjacency cache.

```jldoctest families
println(isuniform(family))
println(uniform_frame(family) === shared)

# output

true
true
```

This matters for cost, not just for description: relation adjacency is cached
on the `Frame`, so uniform `ModelFamily` instances reuse one adjacency index. External adapters
that provide equal but distinct frames should not assume identity-level sharing.

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

An optional package extension can adapt an external modal dataset to this
model-family protocol, preserving its world order, accessibility relation, and
atom callback. The following runnable example exercises that boundary:

```jldoctest families
using Aletheia, SoleData

worlds = SoleData.World.(1:2)
frame = SoleData.SimpleModalFrame(
    worlds,
    SoleData.SoleLogics.SimpleDiGraph([SoleData.SoleLogics.Edge(1, 2)]),
)
feature = SoleData.Feature("p")
dataset = SoleData.ExplicitModalLogiset([
    (Dict(worlds[1] => Dict(feature => 0.0), worlds[2] => Dict(feature => 1.0)), frame),
    (Dict(worlds[1] => Dict(feature => 0.0), worlds[2] => Dict(feature => 0.0)), frame),
])
condition = SoleData.ScalarCondition(feature, >, 0.5)
pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.Diamond(:R),)))
formula = Aletheia.branch(
    pool, Aletheia.Diamond(:R), Aletheia.atom(pool, condition),
)
family = Aletheia.SoleDataFamily(dataset)

println(Aletheia.instance_count(family))
for i in Aletheia.eachinstance(family)
    println("instance $i at world 1: ", Aletheia.check(formula, family, i, worlds[1]))
end

# output

2
instance 1 at world 1: true
instance 2 at world 1: false
```

The optional adapter leaves source-dataset feature, representative, and memo
interfaces under the source package's control; this page documents only the
model-family boundary. The [measured results](results.md) chapter reports the
scope and cost of the measured adapter path.

For the compatibility boundary and migration guidance, use the [Coming from
SoleLogics](compatibility.md) on-ramp.
