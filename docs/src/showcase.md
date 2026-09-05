# One-dataset showcase

This page follows one small, synthetic dataset through the same ordered
journey as the runnable bundle in
[`examples/showcase/`](https://github.com/eduardstan/Aletheia.jl/tree/main/examples/showcase).
The four records are committed in `records.csv`; the example has no run-time
download and uses the pinned seed `0x5EED_2025`.

The reader starts with a crisp decision list and then changes only the semantic
boundary. Each section reports a result and a cross-check. The focused package
boundaries are [`AletheiaCore`](api.md), [`AletheiaData`](families.md),
[`AletheiaCircuits`](circuits.md), [`AletheiaGraphs`](graphs.md),
[`AletheiaAudit`](audit.md), and [`AletheiaNeSy`](nesy.md).

## Crisp decision list

The first reading uses two ordered rules, `hot ∧ dry → alert` and `cool → calm`,
with `review` as the default. A Boolean model assigns each atom a truth value
at each world, and `extension` and `check` are the corresponding finite-model
queries [blackburn2001; §§1.2–1.3, pp. 9–20](@cite). The scalar-data layer
materialises the three columns before the conditions are evaluated, so this
example also cross-checks the plain model against `batch_apply`.

The result is:

```text
crisp labels: [:alert, :review, :calm, :calm]
extension/check cross-check: true; scalar-data cross-check: true
```

## Many-valued decision list

The same pooled conditions are evaluated in the validated five-value Gödel FLew
chain `G5`. In this reading, conjunction is the algebraic meet, so the list
exposes graded rule verdicts rather than only `true` or `false`; the algebra
source on the reference shelf is Hájek, with the FLew contract described by
Galatos et al. [hajek1998; cignoli2000; galatos2007](@cite).

```text
G5 graded (alert, calm): [(:r1, "⊤", "⊥"), (:r2, "α", "α"), (:r3, "α", "⊤"), (:r4, "α", "γ")]
algebra cross-check: validated finite FLew chain = true
```

## Probabilistic decision list

Probability is kept separate from `TruthAlgebra`: distribution semantics assigns
mass to two-valued program worlds, and weighted model counting is a semiring
operation [riguzzi2023; kimmig2017](@cite). The bundle declares the finite,
function-free, ground, acyclic fragment and compiles each alert/calm query to a
certified reduced ordered choice diagram, following the knowledge-compilation
boundary [darwiche2002](@cite).

```text
compiled (alert, calm) probabilities: Tuple{Symbol, Rational{Int64}, Rational{Int64}}[(:r1, 1, 0), (:r2, 3//16, 1//4), (:r3, 1//16, 1), (:r4, 3//16, 3//4)]
certified-circuit/total-choice cross-check: true
declared fragment: finite, function-free, ground, acyclic
refused: function symbols, opaque values, infinite domains, invalid rule heads, cycles, unnormalized choices, and zero-mass evidence
```

The declared fragment covers this finite program and its exact rational WMC.
It refuses function symbols, opaque values, infinite domains, invalid rule heads, cyclic rules, unnormalized choices, and
zero-mass evidence rather than silently widening the contract [riguzzi2023;
kimmig2017](@cite). Gradients, EM, and general probabilistic inference are not
claims of this showcase; the implemented scope is the circuit boundary above
[riguzzi2023; kimmig2017; darwiche2002](@cite).

## Concepts as a typed graph

The records' threshold concepts become typed entities and provenance-bearing
edges. A Kripke frame is a set of worlds with accessibility relations, so the
graph adapter can expose the graph to the shared modal evaluator without
turning path membership into logical entailment [blackburn2001; §1.3, pp. 16–20](@cite).

```text
typed paths: r1→alert=1, r1→r2=1
concept(:alert) extension: Bool[1, 0, 0, 0, 0, 0, 0, 0, 0]
graph/path-oracle cross-check: true; provenance trace replay: true
```

The two typed path queries are checked by the graph oracle. The path trace
retains the CSV locator and content hash, and replay checks the serialized
trace result.

## Fixed neural model and exact extraction

The last reading uses a fixed three-input linear callable with no deep-learning
dependency. The neural-symbolic boundary validates leaf values at the valuation
callback, then extracts an exact rule artifact on the declared finite cases;
keeping learned predicates and symbolic rules as separate paths is consistent
with neural-probabilistic and provenance-aware neuro-symbolic interfaces
[manhaeve2021; li2023; serafini2021](@cite).

```text
neural leaves/direct outputs: Bool[1, 1, 0, 1]
exact extraction rules: 4
round-trip verification: true; trace replay after serialization: true
```

The full metric bundle records fidelity, coverage, stability, complexity,
constraints, trace validity, and resource cost. The unseen fifth input is
uncovered: coverage is applicable at `4/5`, while fidelity is applicable at
`4/5`; the constraint metric is explicitly not applicable rather than being
reported as zero. This separation follows the audit metric contract for
symbolic explanations [stan2026; pp. 1–60](@cite).

```text
fidelity: value=0.8, population=4/5, applicable=true, scope=all
coverage: value=0.8, population=4/5, applicable=true, scope=all
stability: value=missing, population=missing/missing, applicable=false, scope=all
complexity: value=4.0, population=4/1, applicable=true, scope=all
constraints: value=missing, population=missing/missing, applicable=false, scope=all
trace: value=1.0, population=5/5, applicable=true, scope=all
resource_cost: value=5.0, population=5/1, applicable=true, scope=all
audit hashes: artifact length=64, inputs=4, outputs=4
direct-network/neural-leaf cross-check: true; semantic extension cross-check: true
```

The artifact hash and the four input/output hashes are included in the audit
record. The serialized trace is replayed before the result is reported.

## Reproduce the complete output

From the repository root, resolve the local showcase environment once and run
the committed script:

```sh
julia --project=examples/showcase -e 'using Pkg; Pkg.instantiate()'
julia --project=examples/showcase examples/showcase/showcase.jl
```

The complete output is also exercised by the end-to-end umbrella test. The
bundle is a correctness and contract showcase, not a performance claim;
performance statements and their measurement protocol live on the
[Measured results](results.md) page.

The runnable page below executes the same script and checks its printed output
through Documenter's doctest harness.

```jldoctest showcase
include(normpath(joinpath(@__DIR__, "..", "examples", "showcase", "showcase.jl")))

AletheiaShowcase.run_showcase(); nothing
# output

one-dataset showcase (seed=0x5EED_2025)
dataset: 4 records; source=records.csv
prepared scalar store: (4, 1, 3) (world × instance × feature)
a. crisp decision list: [:alert, :review, :calm, :calm]
   formulas: [hot ∧ dry, cool]
   extension/check cross-check: true; scalar-data cross-check: true
b. G5 graded (alert, calm): [(:r1, "⊤", "⊥"), (:r2, "α", "α"), (:r3, "α", "⊤"), (:r4, "α", "γ")]
   algebra cross-check: validated finite FLew chain = true
   theory: finite many-valued conjunction uses the algebra meet [hajek1998; cignoli2000; galatos2007].
c. compiled (alert, calm) probabilities: Tuple{Symbol, Rational{Int64}, Rational{Int64}}[(:r1, 1, 0), (:r2, 3//16, 1//4), (:r3, 1//16, 1), (:r4, 3//16, 3//4)]
   certified-circuit/total-choice cross-check: true
   declared fragment: finite, function-free, ground, acyclic
   refused: function symbols, cycles, unnormalized choices, and zero-mass evidence
   theory: distribution semantics assigns mass to two-valued program worlds and WMC uses a semiring [riguzzi2023; kimmig2017; darwiche2002].
d. typed paths: r1→alert=1, r1→r2=1
   concept(:alert) extension: Bool[1, 0, 0, 0, 0, 0, 0, 0, 0]
   graph/path-oracle cross-check: true; provenance trace replay: true
   theory: a Kripke frame supplies worlds and accessibility for modal evaluation [blackburn2001].
e. neural leaves/direct outputs: Bool[1, 1, 0, 1]
   exact extraction rules: 4
   round-trip verification: true; trace replay after serialization: true
   metric bundle:
  fidelity: value=0.8, population=4/5, applicable=true, scope=all
  coverage: value=0.8, population=4/5, applicable=true, scope=all
  stability: value=missing, population=missing/missing, applicable=false, scope=all
  complexity: value=4.0, population=4/1, applicable=true, scope=all
  constraints: value=missing, population=missing/missing, applicable=false, scope=all
  trace: value=1.0, population=5/5, applicable=true, scope=all
  resource_cost: value=5.0, population=5/1, applicable=true, scope=all
   audit hashes: artifact length=64, inputs=4, outputs=4
   direct-network/neural-leaf cross-check: true; semantic extension cross-check: true
   theory: exact extraction on declared finite cases keeps learned predicates and symbolic rules as separate paths [manhaeve2021; li2023; serafini2021; stan2026].
```
