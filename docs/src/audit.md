# Audit artifacts

`AletheiaAudit` gives symbolic artifacts one small, replayable protocol. A
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
