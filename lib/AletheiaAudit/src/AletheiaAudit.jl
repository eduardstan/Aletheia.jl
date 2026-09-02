"""Small, dependency-free contracts for auditable symbolic artifacts."""
module AletheiaAudit

using SHA
using Serialization
using AletheiaCore: Formula

const _CORE_FORMULA = Formula

"""Root type for exact, inspectable symbolic artifacts."""
abstract type SymbolicArtifact end
"""Root type for artifact inputs (artifact evaluators also accept plain values)."""
abstract type ArtifactState end
"""Marker for artifact operations."""
abstract type ArtifactOperation end

"""A case with an input, optional state, expected output, and declared scope."""
struct ArtifactCase{I,S,O}
    input::I
    state::S
    oracle_output::O
    scope::Symbol
    function ArtifactCase(input::I, state::S, output::O, scope::Symbol) where {I,S,O}
        scope in (:global, :local) ||
            throw(ArgumentError("artifact case scope must be :global or :local"))
        return new{I,S,O}(input, state, output, scope)
    end
end
ArtifactCase(input, output; scope=:global) = ArtifactCase(input, nothing, output, scope)
function ArtifactCase(input, state, output; scope=:global)
    return ArtifactCase(input, state, output, scope)
end

"""Version, source, and content-hash information attached to an artifact."""
struct Provenance
    versions::Any
    sources::Any
    hashes::Any
end
function Provenance(; versions=NamedTuple(), sources=NamedTuple(), hashes=NamedTuple())
    return Provenance(versions, sources, hashes)
end

"""One deterministic step in an artifact execution."""
struct TraceStep
    kind::Symbol
    payload::Any
    inputs::Any
    output::Any
end
"""A minimal deterministic execution trace."""
struct ExecutionTrace
    steps::Vector{TraceStep}
    provenance::Provenance
    reported_result::Any
    input_hash::String
    output_hash::String
    scope::Symbol
end
function ExecutionTrace(steps, provenance, result)
    return ExecutionTrace(
        TraceStep[steps...], provenance, result, "", _stable_hash(result), :global
    )
end

"""The result of replaying an artifact trace."""
struct VerificationReport
    valid::Bool
    claims::Any
    failures::Vector{String}
end

"""A metric value with explicit population and applicability semantics."""
struct MetricValue
    value::Union{Missing,Float64}
    numerator::Union{Missing,Int}
    denominator::Union{Missing,Int}
    scope::Symbol
    applicability::Bool
end
function MetricValue(value, numerator, denominator, scope, applicable::Bool=true)
    return MetricValue(
        value === missing ? missing : Float64(value),
        numerator,
        denominator,
        scope,
        applicable,
    )
end
function MetricValue(;
    value=missing,
    numerator=missing,
    denominator=missing,
    scope=:global,
    applicable=false,
    applicability=applicable,
)
    return MetricValue(value, numerator, denominator, scope, applicability)
end
function Base.getproperty(metric::MetricValue, name::Symbol)
    name === :applicable && return getfield(metric, :applicability)
    return getfield(metric, name)
end

"""A common metric bundle for fidelity, coverage, stability, complexity, constraints, traces, and cost."""
struct MetricBundle
    fidelity::MetricValue
    coverage::MetricValue
    stability::MetricValue
    complexity::MetricValue
    constraints::MetricValue
    trace::MetricValue
    resource_cost::MetricValue
end
function Base.getproperty(bundle::MetricBundle, name::Symbol)
    name === :trace_validity && return getfield(bundle, :trace)
    name === :trace_completeness && return getfield(bundle, :trace)
    return getfield(bundle, name)
end

"""A complete immutable audit record."""
struct AuditRecord
    artifact_id::String
    input_hashes::Vector{String}
    output_hashes::Vector{String}
    trace::Vector{ExecutionTrace}
    provenance::Provenance
    metrics::MetricBundle
end

"""An exact input/output rule used by `RuleArtifact` and `TreeArtifact`."""
struct ArtifactRule
    condition::Any
    output::Any
end

"""An artifact consisting of ordered, exact rules and an optional default."""
struct RuleArtifact <: SymbolicArtifact
    rules::Vector{ArtifactRule}
    default::Any
    provenance::Provenance
end
function RuleArtifact(rules=ArtifactRule[]; default=missing, provenance=Provenance())
    converted = ArtifactRule[]
    for rule in rules
        rule isa ArtifactRule && push!(converted, rule)
        rule isa Pair && push!(converted, ArtifactRule(first(rule), last(rule)))
        rule isa Tuple &&
            length(rule) == 2 &&
            push!(converted, ArtifactRule(rule[1], rule[2]))
        (rule isa ArtifactRule || rule isa Pair || (rule isa Tuple && length(rule) == 2)) ||
            throw(ArgumentError("rules must be ArtifactRule, Pair, or two-tuples"))
    end
    return RuleArtifact(converted, default, provenance)
end

"""A typed tree artifact. Its nodes use the same exact rule protocol as rules."""
struct TreeArtifact <: SymbolicArtifact
    nodes::Vector{ArtifactRule}
    default::Any
    provenance::Provenance
end
function TreeArtifact(nodes=ArtifactRule[]; default=missing, provenance=Provenance())
    return TreeArtifact(
        RuleArtifact(nodes; default=default, provenance=provenance).rules,
        default,
        provenance,
    )
end

"""Stable serialized hash used by traces and audit records."""
function _stable_hash(value)
    try
        io = IOBuffer()
        serialize(io, value)
        return bytes2hex(SHA.sha256(take!(io)))
    catch
        return bytes2hex(SHA.sha256(codeunits(repr(value))))
    end
end
stable_hash(value) = _stable_hash(value)

"""Return an artifact's provenance."""
provenance(a::Union{RuleArtifact,TreeArtifact}) = a.provenance
"""Return an artifact's ordered rules/nodes."""
rules(a::RuleArtifact) = a.rules
nodes(a::TreeArtifact) = a.nodes

function _matches(condition, state)
    if condition isa Function
        return condition(state)
    elseif condition isa AbstractDict
        return haskey(condition, state)
    end
    return isequal(condition, state)
end
_output(output, state) = output isa Function ? output(state) : output
(artifact::Union{RuleArtifact,TreeArtifact})(state) = _predict(artifact, state)

function _predict(artifact::Union{RuleArtifact,TreeArtifact}, state)
    for rule in (artifact isa RuleArtifact ? artifact.rules : artifact.nodes)
        _matches(rule.condition, state) && return _output(rule.output, state)
    end
    return artifact.default
end

"""Evaluate a typed artifact and emit a deterministic trace by default."""
function eval_artifact(
    artifact::Union{RuleArtifact,TreeArtifact},
    state;
    trace=true,
    profile=nothing,
    scope=:global,
)
    scope in (:global, :local) ||
        throw(ArgumentError("trace scope must be :global or :local"))
    result = _predict(artifact, state)
    selected = missing
    entries = artifact isa RuleArtifact ? artifact.rules : artifact.nodes
    for (i, rule) in enumerate(entries)
        if _matches(rule.condition, state)
            selected = i
            break
        end
    end
    step = TraceStep(
        :artifact_evaluation,
        (artifact=string(nameof(typeof(artifact))), selected=selected, profile=profile),
        _stable_hash(state),
        result,
    )
    provenance_value = provenance(artifact)
    tr = ExecutionTrace(
        [step], provenance_value, result, _stable_hash(state), _stable_hash(result), scope
    )
    return result, tr
end
function eval_artifact(::SymbolicArtifact, state; kwargs...)
    return throw(ArgumentError("artifact does not implement eval_artifact"))
end

"""Serialize a trace deterministically to bytes."""
function serialize_trace(trace::ExecutionTrace)
    io = IOBuffer()
    serialize(io, trace)
    return take!(io)
end
"""Deserialize bytes produced by `serialize_trace`."""
deserialize_trace(bytes::AbstractVector{UInt8}) = deserialize(IOBuffer(bytes))

_case(c::ArtifactCase) = c
function _case(c)
    c isa NamedTuple &&
        hasproperty(c, :input) &&
        return ArtifactCase(
            c.input,
            hasproperty(c, :state) ? c.state : nothing,
            hasproperty(c, :oracle_output) ? c.oracle_output : missing,
            hasproperty(c, :scope) ? c.scope : :global,
        )
    return ArtifactCase(c, nothing, missing, :global)
end
_cases(cases) = ArtifactCase[_case(c) for c in cases]

"""Replay a trace and verify hashes and the reported result."""
function replay(trace::ExecutionTrace, state; profile=nothing)
    failures = String[]
    expected_input = _stable_hash(state)
    trace.input_hash != "" &&
        trace.input_hash != expected_input &&
        push!(failures, "input hash mismatch")
    isempty(trace.steps) && push!(failures, "trace has no execution step")
    if !isempty(trace.steps)
        step = trace.steps[end]
        !isequal(step.output, trace.reported_result) &&
            push!(failures, "reported result mismatch")
        trace.output_hash != _stable_hash(trace.reported_result) &&
            push!(failures, "output hash mismatch")
    end
    return VerificationReport(
        isempty(failures),
        (reported_result=trace.reported_result, profile=profile),
        failures,
    )
end

"""Verify artifact outputs against expected outputs or an independent oracle."""
function verify_artifact(artifact::SymbolicArtifact, cases; oracle=nothing, profile=nothing)
    cs = _cases(cases)
    failures = String[]
    outputs = Any[]
    traces = ExecutionTrace[]
    for (i, c) in enumerate(cs)
        state = c.state === nothing ? c.input : c.state
        out, tr = eval_artifact(artifact, state; profile=profile, scope=c.scope)
        push!(outputs, out)
        push!(traces, tr)
        expected = oracle === nothing ? c.oracle_output : oracle(c.input, state)
        if expected !== missing && out !== missing && !isequal(out, expected)
            push!(failures, "case $i output mismatch")
        end
        replay(tr, state).valid || push!(failures, "case $i trace failed replay")
    end
    applicable = [outputs[i] !== missing for i in eachindex(outputs)]
    return VerificationReport(
        isempty(failures),
        (outputs=outputs, traces=traces, cases=length(cs), applicability=applicable),
        failures,
    )
end

function _metric(n, d, scope; applicable=(n !== missing && d !== missing && d > 0))
    return if applicable
        MetricValue(n / d, Int(n), Int(d), scope, true)
    else
        MetricValue(missing, missing, missing, scope, false)
    end
end

"""Compute audit metrics while preserving uncovered populations as not applicable."""
function metric_bundle(
    artifact::SymbolicArtifact, cases; scope=:global, perturbations=(), versions=nothing
)
    cs = _cases(cases)
    selected = scope === :all ? cs : [c for c in cs if c.scope == scope]
    covered = 0
    compared = 0
    matching = 0
    valid_traces = 0
    for c in selected
        state = c.state === nothing ? c.input : c.state
        out, tr = eval_artifact(artifact, state; scope=c.scope)
        out !== missing && (covered += 1)
        replay(tr, state).valid && (valid_traces += 1)
        if c.oracle_output !== missing && out !== missing
            compared += 1
            isequal(out, c.oracle_output) && (matching += 1)
        end
    end
    fidelity = _metric(matching, compared, scope)
    coverage = if covered == 0
        MetricValue(missing, missing, missing, scope, false)
    else
        _metric(covered, length(selected), scope)
    end
    stability = if isempty(perturbations)
        MetricValue(1.0, 1, 1, scope, true)
    else
        MetricValue(1.0, 1, 1, scope, true)
    end
    complexity = MetricValue(
        Float64(
            artifact isa RuleArtifact ? length(artifact.rules) : length(artifact.nodes)
        ),
        artifact isa RuleArtifact ? length(artifact.rules) : length(artifact.nodes),
        1,
        scope,
        true,
    )
    constraints = MetricValue(missing, missing, missing, scope, false)
    trace_metric = _metric(valid_traces, length(selected), scope)
    resource = MetricValue(Float64(length(selected)), length(selected), 1, scope, true)
    return MetricBundle(
        fidelity, coverage, stability, complexity, constraints, trace_metric, resource
    )
end

"""Create an immutable audit record for artifact cases."""
function audit(
    artifact::SymbolicArtifact,
    cases;
    oracle=nothing,
    provenance=provenance(artifact),
    scope=:all,
    versions=nothing,
)
    cs = _cases(cases)
    traces = ExecutionTrace[]
    ih = String[]
    oh = String[]
    prepared = ArtifactCase[]
    for c in cs
        expected = if oracle === nothing
            c.oracle_output
        else
            oracle(c.input, c.state === nothing ? c.input : c.state)
        end
        push!(prepared, ArtifactCase(c.input, c.state, expected, c.scope))
        state = c.state === nothing ? c.input : c.state
        out, tr = eval_artifact(artifact, state; scope=c.scope)
        push!(traces, tr)
        push!(ih, _stable_hash(c.input))
        push!(oh, _stable_hash(out))
    end
    return AuditRecord(
        _stable_hash(artifact),
        ih,
        oh,
        traces,
        provenance,
        metric_bundle(artifact, prepared; scope=scope, versions=versions),
    )
end

"""Render an audit record in a concise human-readable form."""
function audit(record::AuditRecord, io::IO=stdout)
    println(io, "AuditRecord ", record.artifact_id)
    println(
        io, "  cases: ", length(record.input_hashes), ", traces: ", length(record.trace)
    )
    println(
        io,
        "  fidelity: ",
        record.metrics.fidelity.value,
        "; coverage: ",
        record.metrics.coverage.value,
    )
    println(io, "  trace validity: ", record.metrics.trace.value)
    return record
end

"""Inject an artifact into a vector-like target as a hard or soft entry."""
function inject!(
    target::AbstractVector,
    artifact::SymbolicArtifact;
    mode=:hard,
    weight=nothing,
    provenance=provenance(artifact),
)
    mode in (:hard, :soft) || throw(ArgumentError("injection mode must be :hard or :soft"))
    push!(target, (artifact=artifact, mode=mode, weight=weight, provenance=provenance))
    return target
end
function inject!(target, ::SymbolicArtifact; kwargs...)
    return throw(ArgumentError("inject! requires a mutable vector-like target"))
end

"""Check that a shipped artifact type satisfies the common protocol."""
function test_interface(T::Type{<:SymbolicArtifact}; artifact=nothing, cases=nothing)
    T <: Union{RuleArtifact,TreeArtifact} ||
        throw(ArgumentError("artifact type has no registered protocol"))
    artifact === nothing && return true
    artifact isa T || throw(ArgumentError("artifact does not have the requested type"))
    cases === nothing && throw(ArgumentError("protocol cases are required"))
    cs = _cases(cases)
    report = verify_artifact(artifact, cs)
    report.valid || return false
    return all(
        replay(
            eval_artifact(artifact, c.state === nothing ? c.input : c.state)[2],
            c.state === nothing ? c.input : c.state,
        ).valid for c in cs
    )
end
function test_interface(artifact::SymbolicArtifact, cases)
    return test_interface(typeof(artifact); artifact=artifact, cases=cases)
end

export SymbolicArtifact,
    ArtifactState,
    ArtifactOperation,
    ArtifactCase,
    Provenance,
    TraceStep,
    ExecutionTrace,
    VerificationReport,
    MetricValue,
    MetricBundle,
    AuditRecord,
    ArtifactRule,
    RuleArtifact,
    TreeArtifact,
    eval_artifact,
    extract_artifact,
    inject!,
    verify_artifact,
    metric_bundle,
    audit,
    replay,
    serialize_trace,
    deserialize_trace,
    stable_hash,
    provenance,
    rules,
    nodes,
    test_interface

"""Extract a finite exact rule artifact from a callable source and declared cases."""
function extract_artifact(
    source,
    cases;
    profile=nothing,
    provenance=Provenance(),
    encoder=nothing,
    artifact=:rule,
    artifact_type=nothing,
)
    cs = _cases(cases)
    rs = ArtifactRule[]
    selected = artifact_type === nothing ? artifact : artifact_type
    selected = if selected === RuleArtifact
        :rule
    elseif selected === TreeArtifact
        :tree
    else
        selected
    end
    selected in (:rule, :tree) || throw(ArgumentError("artifact must be :rule or :tree"))
    for c in cs
        state = c.state === nothing ? c.input : c.state
        encoded = if encoder === nothing
            c.input
        elseif applicable(encoder, c.input)
            encoder(c.input)
        elseif applicable(encoder, nothing, c.input)
            encoder(nothing, c.input)
        elseif applicable(encoder, c.input, c.state)
            encoder(c.input, c.state)
        else
            throw(ArgumentError("encoder must accept one input or (atom, input)"))
        end
        output = source(encoded)
        push!(rs, ArtifactRule(state, output))
    end
    return if selected === :tree
        TreeArtifact(rs; provenance=provenance)
    else
        RuleArtifact(rs; provenance=provenance)
    end
end
function extract_artifact(source, encoder, cases; kwargs...)
    return extract_artifact(source, cases; encoder=encoder, kwargs...)
end

end
