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

## Validated neural leaves

`neural_valuation(network, encoder; algebra=...)` returns a
`ValuationCallback`. A scalar call and its batch counterpart apply the same
network path, then validate the result against the algebra's truth carrier.
Invalid outputs raise `InvalidNeuralValueError`; this keeps a model's semantic
carrier explicit rather than coercing arbitrary network output into a truth
value. Fuzzy grounding and tensor-valued logic are surveyed by Serafini and
d'Avila Garcez [serafini2021](@cite), while this callback contract is finite
and explicit.

`neural_choice_labels` is separate from `neural_valuation`. It normalizes a
finite nonnegative label vector for a distribution-semantics consumer and
never returns it as a `TruthAlgebra` value. The distinction between labels over
possible worlds and truth at one world follows Riguzzi's distribution-semantics
account [riguzzi2023; chs. 2 and 8](@cite).

## Exact extraction round trip

`ske_roundtrip` enumerates a declared finite case set, extracts an exact
`RuleArtifact` or `TreeArtifact`, verifies the artifact against the callable,
and returns its verification report, metrics, and audit record. Unknown cases
remain uncovered. This is an exact finite-case contract, not a claim about
unbounded neural behavior; symbolic explanation evaluation requires such
coverage and fidelity boundaries to remain visible [stan2026; pp. 1–60](@cite).

`semantic_loss` is intentionally disabled until a gradient-soundness profile is
provided. Semantic-loss methods are a probabilistic training construction
[xu2018](@cite), whereas this interface currently promises forward validation
and exact extraction only. See [Audit artifacts](audit.md) and the [API
reference](api.md) for the public boundary.
