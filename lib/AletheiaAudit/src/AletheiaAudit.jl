"""Small, dependency-free contracts for auditable symbolic artifacts."""
module AletheiaAudit

using SHA
using Serialization
using AletheiaCore: Formula, _boundary_copy, _immutable_copy

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
        owned_input = _immutable_copy(input)
        owned_state = _immutable_copy(state)
        owned_output = _immutable_copy(output)
        return new{typeof(owned_input),typeof(owned_state),typeof(owned_output)}(
            owned_input, owned_state, owned_output, scope
        )
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
    function Provenance(versions, sources, hashes)
        return new(
            _boundary_copy(versions), _boundary_copy(sources), _boundary_copy(hashes)
        )
    end
end
function Provenance(; versions=NamedTuple(), sources=NamedTuple(), hashes=NamedTuple())
    return Provenance(
        _boundary_copy(versions), _boundary_copy(sources), _boundary_copy(hashes)
    )
end
function Base.:(==)(left::Provenance, right::Provenance)
    return left.versions == right.versions &&
           left.sources == right.sources &&
           left.hashes == right.hashes
end
Base.isequal(left::Provenance, right::Provenance) = left == right
function Base.getproperty(provenance::Provenance, name::Symbol)
    name in (:versions, :sources, :hashes) &&
        return _boundary_copy(getfield(provenance, name))
    return getfield(provenance, name)
end

"""One deterministic step in an artifact execution."""
struct TraceStep
    kind::Symbol
    payload::Any
    inputs::Any
    output::Any
    function TraceStep(kind::Symbol, payload, inputs, output)
        return new(
            kind, _immutable_copy(payload), _immutable_copy(inputs), _immutable_copy(output)
        )
    end
end
"""A minimal deterministic execution trace."""
struct ExecutionTrace
    steps::Tuple
    provenance::Provenance
    reported_result::Any
    input_hash::String
    output_hash::String
    scope::Symbol
    artifact::Any
    function ExecutionTrace(
        steps::Tuple,
        provenance::Provenance,
        result,
        input_hash::String,
        output_hash::String,
        scope::Symbol,
        artifact,
    )
        scope in (:global, :local) ||
            throw(ArgumentError("trace scope must be :global or :local"))
        return new(
            _immutable_copy(steps),
            _immutable_copy(provenance),
            _immutable_copy(result),
            input_hash,
            output_hash,
            scope,
            _boundary_copy(artifact),
        )
    end
end
function ExecutionTrace(
    steps,
    provenance,
    result,
    input_hash::String,
    output_hash::String,
    scope::Symbol;
    artifact=nothing,
)
    owned_steps, owned_provenance, owned_result, owned_artifact = _boundary_copy((
        tuple(steps...), provenance, result, artifact
    ))
    return ExecutionTrace(
        owned_steps,
        owned_provenance,
        owned_result,
        input_hash,
        output_hash,
        scope,
        owned_artifact,
    )
end
function ExecutionTrace(steps, provenance, result)
    return ExecutionTrace(
        tuple(steps...), provenance, result, "", _stable_hash(result), :global, nothing
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
    input_hashes::Tuple
    output_hashes::Tuple
    # Hashes of evaluated states; these correspond to trace input_hash.
    state_hashes::Tuple
    trace::Tuple
    provenance::Provenance
    metrics::MetricBundle
end
function AuditRecord(
    artifact_id::String,
    input_hashes,
    output_hashes,
    state_hashes,
    trace,
    provenance::Provenance,
    metrics::MetricBundle,
)
    return AuditRecord(
        _boundary_copy(artifact_id),
        _boundary_copy(tuple(input_hashes...)),
        _boundary_copy(tuple(output_hashes...)),
        _boundary_copy(tuple(state_hashes...)),
        _boundary_copy(tuple(trace...)),
        _boundary_copy(provenance),
        _boundary_copy(metrics),
    )
end
function Base.getproperty(record::AuditRecord, name::Symbol)
    name in (:input_hashes, :output_hashes, :state_hashes, :trace) &&
        return collect(_boundary_copy(getfield(record, name)))
    name === :provenance && return _boundary_copy(getfield(record, name))
    return getfield(record, name)
end

"""An exact input/output rule used by `RuleArtifact` and `TreeArtifact`."""
struct ArtifactRule
    condition::Any
    output::Any
    function ArtifactRule(condition, output)
        return new(_immutable_copy(condition), _immutable_copy(output))
    end
end
function Base.getproperty(rule::ArtifactRule, name::Symbol)
    name in (:condition, :output) && return _boundary_copy(getfield(rule, name))
    return getfield(rule, name)
end

"""An artifact consisting of ordered, exact rules and an optional default."""
struct RuleArtifact <: SymbolicArtifact
    rules::Tuple
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
    return RuleArtifact(
        tuple(converted...), _immutable_copy(default), _immutable_copy(provenance)
    )
end

"""A typed tree artifact. Its nodes use the same exact rule protocol as rules."""
struct TreeArtifact <: SymbolicArtifact
    nodes::Any
    default::Any
    provenance::Provenance
end
function TreeArtifact(nodes=ArtifactRule[]; default=missing, provenance=Provenance())
    prepared = RuleArtifact(nodes; default=default, provenance=provenance)
    return TreeArtifact(
        _immutable_copy(tuple(prepared.rules...)),
        _immutable_copy(default),
        _immutable_copy(provenance),
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
provenance(a::Union{RuleArtifact,TreeArtifact}) = _boundary_copy(a.provenance)
"""Return an artifact's ordered rules/nodes."""
rules(a::RuleArtifact) = [r for r in getfield(a, :rules)]
nodes(a::TreeArtifact) = [r for r in getfield(a, :nodes)]
function Base.getproperty(artifact::TreeArtifact, name::Symbol)
    name === :nodes && return nodes(artifact)
    name === :provenance && return _boundary_copy(getfield(artifact, :provenance))
    return getfield(artifact, name)
end
function Base.getproperty(artifact::RuleArtifact, name::Symbol)
    name === :rules && return rules(artifact)
    name === :nodes && return rules(artifact)
    name === :provenance && return _boundary_copy(getfield(artifact, :provenance))
    return getfield(artifact, name)
end

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
    provenance_value = _trace_provenance(artifact)
    tr = if trace
        ExecutionTrace(
        [step],
        provenance_value,
        result,
        _stable_hash(state),
        _stable_hash(result),
        scope;
        artifact=artifact,
    )
    else
        nothing
    end
    return result, tr
end
function eval_artifact(::SymbolicArtifact, state; kwargs...)
    return throw(ArgumentError("artifact does not implement eval_artifact"))
end

function _contains_callable(value, seen=IdDict{Any,Bool}())
    value isa Function && return true
    value isa Union{Nothing,Missing,Bool,Symbol,Char,AbstractString,Number} && return false
    value isa Type && return false
    traversable =
        value isa AbstractArray ||
        value isa AbstractDict ||
        value isa AbstractSet ||
        value isa Tuple ||
        value isa NamedTuple ||
        isstructtype(typeof(value))
    traversable || return false
    haskey(seen, value) && return false
    seen[value] = true
    try
        if value isa AbstractDict
            return any(
                _contains_callable(k, seen) || _contains_callable(v, seen) for
                (k, v) in value
            )
        elseif value isa AbstractArray ||
            value isa AbstractSet ||
            value isa Tuple ||
            value isa NamedTuple
            return any(_contains_callable(x, seen) for x in value)
        end
        return any(
            _contains_callable(getfield(value, field), seen) for
            field in 1:fieldcount(typeof(value))
        )
    finally
        delete!(seen, value)
    end
end

"""Serialize a trace deterministically to bytes.

Callable rule conditions and outputs are intentionally not serialization-portable.
They are rejected here, while the in-memory trace remains replayable.
"""
function serialize_trace(trace::ExecutionTrace)
    _contains_callable(trace) && throw(
        ArgumentError(
            "traces containing callable artifact conditions or outputs are not serialization-portable",
        ),
    )
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

"""Encode an input through the single neural/callable dispatch contract."""
function _encoded_input(encoder, atom, world)
    encoder === nothing && return world
    applicable(encoder, atom, world) && return encoder(atom, world)
    applicable(encoder, world) && return encoder(world)
    return throw(ArgumentError("encoder must accept (atom, world) or (world)"))
end

"""Validate a context-specific trace payload."""
_trace_context_valid(context, payload) = false

function _provenance_value(values, key::Symbol)
    values isa NamedTuple && hasproperty(values, key) && return getproperty(values, key)
    values isa AbstractDict && haskey(values, key) && return values[key]
    return nothing
end

function _trace_provenance(artifact)
    source = provenance(artifact)
    hashes = source.hashes
    traced = if hashes isa NamedTuple
        merge(hashes, (artifact_id=_stable_hash(artifact), provenance_id=_stable_hash(source)))
    elseif hashes isa AbstractDict
        Dict{Any,Any}(hashes)
    else
        (
            provided=hashes,
            artifact_id=_stable_hash(artifact),
            provenance_id=_stable_hash(source),
        )
    end
    if traced isa AbstractDict
        traced[:artifact_id] = _stable_hash(artifact)
        traced[:provenance_id] = _stable_hash(source)
    end
    return Provenance(source.versions, source.sources, traced)
end

"""Replay a trace and verify hashes, context, every step, and the reported result."""
function replay(trace::ExecutionTrace, state; profile=nothing)
    failures = String[]
    expected_input = _stable_hash(state)
    trace.input_hash != "" &&
        trace.input_hash != expected_input &&
        push!(failures, "input hash mismatch")
    isempty(trace.steps) && push!(failures, "trace has no execution step")
    for step in trace.steps
        step.kind in (:artifact_evaluation, :test, :graph_path) ||
            push!(failures, "step kind mismatch")
        if step.kind === :artifact_evaluation
            !isequal(step.inputs, expected_input) &&
                push!(failures, "step input metadata mismatch")
            trace.artifact === nothing &&
                push!(failures, "artifact is required to replay an artifact verdict")
            if !(step.payload isa NamedTuple) ||
               !hasproperty(step.payload, :artifact) ||
               !hasproperty(step.payload, :selected) ||
               !hasproperty(step.payload, :profile)
                push!(failures, "step payload metadata malformed")
            elseif trace.artifact !== nothing
                trace.artifact isa Union{RuleArtifact,TreeArtifact} ||
                    push!(failures, "artifact context has an unsupported type")
                if trace.artifact isa Union{RuleArtifact,TreeArtifact}
                    artifact_id = _provenance_value(trace.provenance.hashes, :artifact_id)
                    provenance_id = _provenance_value(
                        trace.provenance.hashes, :provenance_id
                    )
                    artifact_id === nothing &&
                        push!(failures, "artifact identity metadata missing")
                    provenance_id === nothing &&
                        push!(failures, "artifact provenance metadata missing")
                    artifact_id !== nothing &&
                        !isequal(artifact_id, _stable_hash(trace.artifact)) &&
                        push!(failures, "artifact identity mismatch")
                    provenance_id !== nothing &&
                        !isequal(provenance_id, _stable_hash(provenance(trace.artifact))) &&
                        push!(failures, "artifact provenance mismatch")
                    trace.provenance != _trace_provenance(trace.artifact) &&
                        push!(failures, "artifact provenance mismatch")
                    entries = if trace.artifact isa RuleArtifact
                        trace.artifact.rules
                    else
                        trace.artifact.nodes
                    end
                    selected = missing
                    for (i, rule) in enumerate(entries)
                        if _matches(rule.condition, state)
                            selected = i
                            break
                        end
                    end
                    !isequal(
                        step.payload.artifact, string(nameof(typeof(trace.artifact)))
                    ) && push!(failures, "step artifact metadata mismatch")
                    !isequal(step.payload.selected, selected) &&
                        push!(failures, "step selection metadata mismatch")
                    if step.payload.profile === nothing
                        profile !== nothing &&
                            push!(failures, "step profile metadata mismatch")
                    elseif profile === nothing || !isequal(step.payload.profile, profile)
                        push!(failures, "step profile metadata mismatch")
                    end
                    predicted = _predict(trace.artifact, state)
                    !isequal(step.output, predicted) &&
                        push!(failures, "step result mismatch")
                end
            end
        elseif step.kind === :graph_path
            graph_hash = _provenance_value(trace.provenance.hashes, :graph)
            (!isequal(step.inputs, state) && !isequal(step.inputs, expected_input)) &&
                push!(failures, "graph step input metadata mismatch")
            if trace.artifact === nothing ||
                graph_hash === nothing ||
                !(step.payload isa NamedTuple) ||
                !hasproperty(step.payload, :path)
                push!(failures, "graph trace context, hash, or path metadata missing")
            else
                !isequal(graph_hash, _stable_hash(trace.artifact)) &&
                    push!(failures, "graph context hash mismatch")
                !_trace_context_valid(trace.artifact, step.payload.path) &&
                    push!(failures, "graph path is not valid in the recorded graph")
            end
        elseif trace.artifact !== nothing
            push!(failures, "step kind mismatch")
        end
    end
    if !isempty(trace.steps)
        final = trace.steps[end]
        !isequal(final.output, trace.reported_result) &&
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
    expected_outputs = Any[]
    traces = ExecutionTrace[]
    for (i, c) in enumerate(cs)
        state = c.state === nothing ? c.input : c.state
        out, tr = eval_artifact(artifact, state; profile=profile, scope=c.scope)
        push!(outputs, out)
        push!(traces, tr)
        expected = oracle === nothing ? c.oracle_output : oracle(c.input, state)
        push!(expected_outputs, expected)
        if expected !== missing && out === missing
            push!(failures, "case $i output uncovered")
        elseif expected !== missing && !isequal(out, expected)
            push!(failures, "case $i output mismatch")
        end
        replay(tr, state; profile=profile).valid ||
            push!(failures, "case $i trace failed replay")
    end
    applicable = [outputs[i] !== missing for i in eachindex(outputs)]
    return VerificationReport(
        isempty(failures),
        (
            outputs=outputs,
            expected_outputs=expected_outputs,
            traces=traces,
            cases=length(cs),
            applicability=applicable,
        ),
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
    scope in (:all, :global, :local) ||
        throw(ArgumentError("metric scope must be :all, :global, or :local"))
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
    stability = if isempty(perturbations) || isempty(selected)
        MetricValue(missing, missing, missing, scope, false)
    else
        # Canonicalize the baseline by stable state hash, not caller order.
        baseline_case = first(
            sort(selected; by=c -> _stable_hash(c.state === nothing ? c.input : c.state)),
        )
        baseline = begin
            state = if baseline_case.state === nothing
                baseline_case.input
            else
                baseline_case.state
            end
            eval_artifact(artifact, state; scope=baseline_case.scope)[1]
        end
        if baseline === missing
            MetricValue(missing, missing, missing, scope, false)
        else
            matches = 0
            total = 0
            for perturbation in perturbations
                value = eval_artifact(
                    artifact, perturbation; scope=scope === :local ? :local : :global
                )[1]
                total += 1
                isequal(value, baseline) && (matches += 1)
            end
            _metric(matches, total, scope)
        end
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
    sh = String[]
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
        push!(sh, _stable_hash(state))
    end
    return AuditRecord(
        _stable_hash(artifact),
        ih,
        oh,
        sh,
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
    output_transform=identity,
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
        encoded = _encoded_input(encoder, c.input, state)
        output = _boundary_copy(output_transform(source(encoded)))
        push!(rs, ArtifactRule(_boundary_copy(state), output))
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
