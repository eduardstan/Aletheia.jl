# Audit artifacts

`[`AletheiaAudit`](audit.md)` gives symbolic artifacts one small, replayable protocol. A
`RuleArtifact` evaluates ordered exact rules; a `TreeArtifact` uses the same
protocol with typed tree nodes. Every evaluation emits an `ExecutionTrace`.

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
hashes, provenance, and result. `serialize_trace` and `deserialize_trace` let a
consumer retain and replay it. `MetricValue` keeps its numerator, denominator,
scope, and applicability together, so an uncovered case is missing rather than
silently scored as a negative result. The metric vocabulary follows the
requirements for symbolic explanation evaluation in Stan et al. [stan2026](@cite).

## Traces and replay

`eval_artifact` returns both the artifact result and a deterministic trace.
Trace steps record the selected operation, input and output hashes, and the
artifact profile. `serialize_trace` and `deserialize_trace` provide a
serialization boundary, while `replay` checks the recorded result against a
later input. These fields make an execution inspectable without treating a
trace as a logical proof.

## Explicit metric scope

`MetricValue` keeps a value with its numerator, denominator, scope, and
applicability. An uncovered or otherwise inapplicable case is represented by
`missing`, not silently counted as a negative. `metric_bundle` reports fidelity,
coverage, stability, complexity, constraints, trace validity, and resource cost
as separate fields. This separation follows the requirements for evaluating
symbolic explanations and their coverage and fidelity claims
[stan2026; pp. 1–60](@cite).

`verify_artifact` compares outputs with declared cases or an independent
oracle, and `audit` packages verification inputs, traces, provenance, and
metrics into one immutable record. The [API reference](api.md) lists the
exported artifact and metric types; [Neural-symbolic interface](nesy.md)
uses this audit boundary for exact extraction.
