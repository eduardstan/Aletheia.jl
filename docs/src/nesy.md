# Neural-symbolic interface

`AletheiaNeSy` accepts any callable as a network. `neural_valuation` wraps it in
a validated `ValuationCallback`; scalar and batch calls use the same direct
network path.

```jldoctest nesy
using AletheiaNeSy
using AletheiaCore
valuation = neural_valuation(x -> x > 0, identity; algebra=BOOLEAN)
println(valuation(:p, 2))
println(valuation.vectorized(:p, [-1, 2]))

# output

true
Bool[0, 1]
```

`neural_choice_labels` is a separate finite distribution-label path. It returns
normalized nonnegative labels and never interprets them as truth values. This
keeps distribution semantics distinct from `TruthAlgebra`, as in Riguzzi's
account of probabilistic logic programming [riguzzi2023](@cite).

`ske_roundtrip` performs exact enumerative extraction on a declared finite case
set, evaluates the artifact through the audit protocol, and returns its
verification, metrics, and audit record. Unknown cases remain uncovered. A
semantic-loss call is intentionally disabled and raises `SemanticLossError`
until a gradient-soundness profile is proven.
