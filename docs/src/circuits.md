# Distribution-semantics circuits

[`AletheiaCircuits`](circuits.md) is the focused package for a finite distribution-semantics
fragment. A probabilistic logic program describes a distribution over ordinary
(two-valued) worlds. Each independent choice selects one normalized outcome;
ground rules then close the selected facts under an acyclic dependency order.
For a query event `q`, weighted model counting sums the weights of worlds in
which `q` holds. Conditional probability is the ratio of the joint event to
the positive-mass evidence event. This is the finite distribution-semantics
view described by Riguzzi, chapters 2 and 8 [riguzzi2023](@cite).

## Supported fragment

[`AletheiaCircuits`](circuits.md) supports exactly finite, function-free programs with ground
rules, independent finite choices (with immutable scalar values), normalized nonnegative weights, and immutable certified representations.
acyclic rule dependency graph. Consequences are two-valued. Queries and
evidence can use atoms and explicit `Not`, `And`, and `Or` event expressions.
The front end enumerates the finite primitive choices to build a reduced
ordered choice decision diagram. Enumeration is a simple, auditable grounding
strategy for this fragment. A ground tuple is an atomic alternative when the
whole tuple is present in a world; a tuple not present in the world retains its
legacy conjunction syntax. Reduced circuit representations and their
tractable operations are the knowledge-compilation boundary described by
Darwiche and Marquis [darwiche2002](@cite). The resulting circuit certificate
records the choice order, every node's support, disjoint decision branches, and
source provenance.

A circuit must be certified before the semiring evaluator will enter it. The
probability evaluator is intentionally not a `TruthAlgebra`: truth values at a
world and a measure over worlds are different semantic objects
[riguzzi2023; chs. 2 and 8](@cite). WMC uses the closed nonnegative
`Float64Profile()` by default, or exact `RationalProfile()` (Float64 weights are
converted with `rationalize` using an eight-ulp tolerance, normalized as a tuple
with an unbounded exact carrier, and therefore retain unit mass), following the
semiring abstraction of algebraic model counting [kimmig2017](@cite).

```@example circuits
using AletheiaCircuits
rain = ProbabilisticFact(:rain, 3 // 10)
program = DSProgram([rain], [GroundRule(:wet, (:rain,))])
query = compile_event(program, :wet)
evidence = compile_event(program, :rain)
wmc(query; semiring=RationalProfile())
```

```@example circuits
conditional_probability(query, evidence; semiring=RationalProfile())
```

The package rejects function symbols, variables, native opaque values, infinite
domains, invalid rule heads, cycles, unnormalized choices, unsupported circuit
backends, and zero-mass evidence with typed exceptions. Boolean values are reserved
for event constants and cannot be choice alternatives.
It does not claim support for continuous variables, infinite grounding,
cyclic or general locally stratified programs, modal probabilistic semantics,
gradients, reverse evaluation, EM, or arbitrary AMC backends. Those features
would require new contracts and separate validation. The semiring vocabulary
follows algebraic model counting, while the finite distribution-semantics
scope follows Riguzzi, chapters 2, 3, 8, and 12 [riguzzi2023](@cite).
