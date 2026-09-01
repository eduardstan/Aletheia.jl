# AletheiaCircuits

`AletheiaCircuits` implements a deliberately small distribution-semantics
core. Programs are finite, function-free, ground, acyclic, and built from
independent normalized finite choices. Their two-valued query and evidence
events are compiled into a reduced ordered choice decision diagram with a
certificate. Only certified circuits can be evaluated.

The circuit evaluator is separate from AletheiaCore's `TruthAlgebra`. It uses
a closed nonnegative probability carrier. `Float64Profile()` is convenient for
numerical work; `RationalProfile()` gives exact finite-world answers. Use
`wmc` for a weighted model count and `conditional_probability` only when the
evidence has positive mass.

Function symbols, variables, cycles, unnormalized choices, unsupported
backends, and zero-mass evidence are rejected with typed exceptions. The
package does not claim general probabilistic logic programming, continuous
variables, modal probabilistic semantics, gradient inference, EM, or a
replacement for arbitrary AMC backends.
