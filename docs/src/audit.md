# Audit artifacts

`[`AletheiaAudit`](audit.md)` gives symbolic artifacts one small, replayable protocol. A
`RuleArtifact` evaluates ordered exact rules; a `TreeArtifact` uses the same
protocol with typed tree nodes. Evaluations emit an `ExecutionTrace` by default; `trace=false` deliberately returns no trace.

```jldoctest audit
using AletheiaAudit
artifact = RuleArtifact([:yes => true])
output, trace = eval_artifact(artifact, :yes)
println(output)
println(replay(trace, :yes).valid)

# output

true
true
```

The trace records the selected artifact operation, deterministic input/output
hashes, provenance, and result. For an audit record, `input_hashes` identify the
declared case inputs; `state_hashes` identify the evaluated states and match each
trace's `input_hash`. `serialize_trace` and `deserialize_trace` let a
consumer retain and replay data-only traces. Callable rule conditions and outputs
are valid for in-memory replay but are rejected at serialization because Julia
closures are not portable across that boundary. `MetricValue` keeps its numerator, denominator,
scope, and applicability together, so an uncovered case is missing rather than
silently scored as a negative result. The metric vocabulary follows the
requirements for symbolic explanation evaluation in Stan et al. [stan2026](@cite).

## Traces and replay

`eval_artifact` returns both the artifact result and a deterministic trace.
Trace steps record the selected operation, input and output hashes, and the
artifact profile. Replay authenticates the attached artifact identity and
provenance and checks every step; a profile recorded in a step must be supplied
again. `serialize_trace` and `deserialize_trace` provide a serialization
boundary. Artifact-verdict replay requires the attached artifact; graph-path
replay requires the attached graph, its recorded graph hash, and a path that
passes `path_valid`. These checks make an execution inspectable without
treating a trace as a logical proof.

## Explicit metric scope

`MetricValue` keeps a value with its numerator, denominator, scope, and
applicability. `metric_bundle` reports fidelity over all selected cases, counting
uncovered cases as non-matches, while coverage reports the covered subset as a
separate number. An empty selected population is represented by `missing`, not
silently counted as a negative. It also reports stability, complexity,
constraints, trace validity, and resource cost as separate fields. Scope is restricted to
`:all`, `:global`, or `:local`; stability is computed from supplied perturbations
and is otherwise inapplicable. With perturbations, stability uses the artifact
output for the selected case whose evaluated-state hash is lexicographically
smallest as its order-independent baseline, then reports the fraction of supplied
perturbations with the same output. This separation follows the requirements for evaluating
symbolic explanations and their coverage and fidelity claims
[stan2026; pp. 1–60](@cite).

`verify_artifact` compares outputs with declared cases or an independent
oracle; expected but uncovered outputs are verification failures and retain their
expected values in the report. `audit` packages verification inputs, traces, provenance, and
metrics into one owned record. The record deep-copies nested material at
construction and when its retained sequences or provenance are accessed. The [API reference](api.md) lists the
exported artifact and metric types; [Neural-symbolic interface](nesy.md)
uses this audit boundary for exact extraction.
