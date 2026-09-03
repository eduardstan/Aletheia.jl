# Scalar data evaluation

Aletheia can prepare scalar features once and use those values in pooled
formula evaluation. A scalar condition is an immutable payload stored in an
ordinary `Atom`; no additional syntax node is needed.

```jldoctest scalar-data
using Aletheia

frame = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => Int[])); index=true)
values = Dict(1 => Dict(1 => 1, 2 => 4))
feature = (data, instance, world) -> data[instance][world]
data = prepare_scalar(values; features=[feature], frames=[frame], instances=[1])
condition = ThresholdCondition(feature, >=, 2)

pool = FormulaPool(Signature((Diamond(:R),)))
formula = branch(pool, Diamond(:R), atom(pool, condition))
println(feature_value(data, 1, 2, feature))
println(batch_apply([formula], data)[1][1])

# output

4
Bool[1, 0]
```

`prepare_scalar` stores values in world × instance × feature order. An explicit
`worlds` list must exactly match every supplied frame domain and otherwise raises
`ScalarWorldDomainError` during preparation. Feature
lookup and aggregate memos are separate from formula caches. Global
`minimum`/`maximum` aggregates can be prepared eagerly; relation-specific
aggregates are filled lazily. Empty successor sets return `nothing` from
`aggregate_value`; modal threshold evaluation applies the usual existential
false and universal true identities.

A source can implement `feature_value(source, instance, world, feature)` and
optionally `data_version(source)`. A version change makes prepared data reject
stale reads, so callers must prepare it again. SoleData remains optional: when
installed, `AletheiaSoleDataExt` maps its modal logisets through this protocol.

The complete API reference is available in the [API reference](api.md).
