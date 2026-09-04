"""Reduced ordered decision diagrams over finite choice variables.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> isdefined(AletheiaCircuits, Symbol("AbstractEvent"))
true
```
"""
abstract type AbstractEvent end
"""
The abstract supertype for event circuits.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractEventCircuit isa Type
true
```
"""
abstract type AbstractEventCircuit end
"""
The abstract supertype for circuit nodes.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> CircuitNode isa Type
true
```
"""
abstract type CircuitNode end

"""One node in a reduced ordered (possibly multi-outcome) choice diagram.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> BDDNode(1, 1, 2)
BDDNode(1, 1, 2, (1, 2))
```
"""
struct BDDNode <: CircuitNode
    var::Int
    low::Int
    high::Int
    branches::Tuple
end
function BDDNode(var::Integer, low::Integer, high::Integer)
    return BDDNode(Int(var), Int(low), Int(high), (Int(low), Int(high)))
end
function BDDNode(var::Integer, branches::Tuple)
    isempty(branches) &&
        throw(InvalidCircuitError(:branches, "a decision node needs branches"))
    return BDDNode(
        Int(var),
        first(branches),
        length(branches) > 1 ? branches[2] : first(branches),
        tuple((Int(x) for x in branches)...),
    )
end
BDDNode(var::Integer, branches::AbstractVector) = BDDNode(var, tuple(branches...))

"""An uncertified raw BDD.  It must be passed through `validate` before evaluation.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> BDD([BDDNode(0, 0, 0, ()), BDDNode(0, 0, 0, ())], (2,))
BDD(BDDNode[BDDNode(0, 0, 0, ()), BDDNode(0, 0, 0, ())], (2,), (), ())
```
"""
struct BDD <: AbstractEventCircuit
    nodes::Vector{BDDNode}
    roots::Tuple
    variables::Tuple
    alternatives::Tuple
end
function BDD(nodes, roots; variables=(), alternatives=())
    return BDD(
        _boundary_copy(Vector{BDDNode}(nodes)),
        _boundary_copy(roots isa Tuple ? roots : tuple(roots...)),
        _boundary_copy(variables isa Tuple ? variables : tuple(variables...)),
        _boundary_copy(alternatives isa Tuple ? alternatives : tuple(alternatives...)),
    )
end

"""Certificate for a circuit's support, order, decomposition, determinism, and smoothness.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> CircuitCertificate(Dict(), (), Dict(), true, true)
CircuitCertificate(AletheiaCore.FrozenDict{Any, Any}(), (), AletheiaCore.FrozenDict{Any, Any}(), true, true, AletheiaCore.FrozenDict{Int64, Any}())
```
"""
struct CircuitCertificate
    support::Any
    variable_order::Any
    decomposition::Any
    determinism::Bool
    smoothness::Bool
    provenance::Any
    function CircuitCertificate(
        support, variable_order, decomposition, determinism, smoothness, provenance
    )
        return new(
            _immutable_copy(support),
            _immutable_copy(variable_order),
            _immutable_copy(decomposition),
            determinism,
            smoothness,
            _immutable_copy(provenance),
        )
    end
end
function CircuitCertificate(support, variable_order, decomposition, determinism, smoothness)
    return CircuitCertificate(
        support, variable_order, decomposition, determinism, smoothness, Dict{Int,Any}()
    )
end

"""A circuit together with a certificate that can be checked independently.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> cert = CircuitCertificate(Dict(), (), Dict(), true, true);

julia> CertifiedCircuit(BDDNode[], (1,), cert) isa CertifiedCircuit
true
```
"""
struct CertifiedCircuit{N,R,C<:CircuitCertificate} <: AbstractEventCircuit
    nodes::N
    roots::R
    certificate::C
    variables::Tuple
    alternatives::Tuple
    function CertifiedCircuit(
        nodes, roots, certificate::C, variables::Tuple, alternatives::Tuple
    ) where {C<:CircuitCertificate}
        owned_nodes = _immutable_copy(nodes)
        owned_roots = _immutable_copy(roots)
        owned_certificate = _immutable_copy(certificate)
        owned_variables = _immutable_copy(variables)
        owned_alternatives = _immutable_copy(alternatives)
        return new{typeof(owned_nodes),typeof(owned_roots),typeof(owned_certificate)}(
            owned_nodes, owned_roots, owned_certificate, owned_variables, owned_alternatives
        )
    end
end
function CertifiedCircuit(
    nodes, roots, certificate::CircuitCertificate; variables=(), alternatives=()
)
    owned_nodes = _immutable_copy(nodes)
    owned_roots = _immutable_copy(roots isa Tuple ? roots : tuple(roots...))
    owned_certificate = _immutable_copy(certificate)
    owned_variables = _immutable_copy(variables isa Tuple ? variables : tuple(variables...))
    owned_alternatives = _immutable_copy(
        alternatives isa Tuple ? alternatives : tuple(alternatives...)
    )
    return CertifiedCircuit(
        owned_nodes, owned_roots, owned_certificate, owned_variables, owned_alternatives
    )
end

"""
Return the node table of a circuit.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> nodes(ev.circuit) isa Vector{BDDNode}
true
```
"""
nodes(circuit::AbstractEventCircuit) = _boundary_copy(circuit.nodes)
"""
Return root node indices of a circuit.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> roots(ev.circuit)
(3,)
```
"""
roots(circuit::AbstractEventCircuit) = _boundary_copy(circuit.roots)
"""
Return the variable order recorded by a certificate.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> variable_order(ev.circuit)
(:c1,)
```
"""
function variable_order(circuit::CertifiedCircuit)
    return _boundary_copy(circuit.certificate.variable_order)
end
variable_order(circuit::BDD) = _boundary_copy(circuit.variables)

function _node_index(circuit, node::Integer)
    1 <= node <= length(circuit.nodes) || throw(
        InvalidCircuitError(:node_reference, "node index $(node) is outside the circuit"),
    )
    return Int(node)
end
function _node_index(circuit, node::BDDNode)
    found = findfirst(isequal(node), circuit.nodes)
    found === nothing &&
        throw(InvalidCircuitError(:node_reference, "node is not part of the circuit"))
    return found
end

function _support_map(circuit)
    result = Dict{Int,Tuple}()
    function visit(index)
        haskey(result, index) && return result[index]
        node = circuit.nodes[index]
        if node.var == 0
            result[index] = ()
        else
            children = reduce(
                union, (Set(visit(child)) for child in node.branches); init=Set{Any}()
            )
            push!(children, circuit.variables[node.var])
            order = sort(
                collect(children); by=x -> findfirst(y -> isequal(x, y), circuit.variables)
            )
            result[index] = tuple(order...)
        end
        return result[index]
    end
    for i in eachindex(circuit.nodes)
        visit(i)
    end
    return result
end

"""Return the certified choice support of a node.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> support(ev.circuit)
(:c1,)
```
"""
function support(circuit::CertifiedCircuit, node::Union{Integer,BDDNode})
    validate(circuit)
    index = _node_index(circuit, node)
    haskey(circuit.certificate.support, index) || throw(
        InvalidCircuitError(:support_certificate, "support is missing for node $(index)"),
    )
    return _boundary_copy(circuit.certificate.support[index])
end
support(circuit::CertifiedCircuit) = support(circuit, circuit.roots[1])
function support(circuit::BDD, node)
    return throw(UncertifiedCircuitError("raw BDDs have no trusted support certificate"))
end
function support(::BDD)
    return throw(UncertifiedCircuitError("raw BDDs have no trusted support certificate"))
end

"""Return source-level provenance attached to a certified node.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> source_provenance(ev.circuit) !== nothing
true
```
"""
function source_provenance(circuit::CertifiedCircuit, node::Union{Integer,BDDNode})
    validate(circuit)
    index = _node_index(circuit, node)
    return _boundary_copy(get(circuit.certificate.provenance, index, nothing))
end
source_provenance(circuit::CertifiedCircuit) = source_provenance(circuit, circuit.roots[1])
function source_provenance(circuit::BDD, node)
    return throw(UncertifiedCircuitError("raw BDDs have no trusted provenance"))
end
function source_provenance(::BDD)
    return throw(UncertifiedCircuitError("raw BDDs have no trusted provenance"))
end

function _validate_shape(nodes, roots, variables, alternatives)
    length(nodes) >= 2 ||
        throw(InvalidCircuitError(:terminals, "a BDD needs false and true terminals"))
    isempty(roots) &&
        throw(InvalidCircuitError(:roots, "a circuit needs at least one root"))
    nodes[1].var == 0 && isempty(nodes[1].branches) ||
        throw(InvalidCircuitError(:false_terminal, "node 1 must be the false terminal"))
    nodes[2].var == 0 && isempty(nodes[2].branches) ||
        throw(InvalidCircuitError(:true_terminal, "node 2 must be the true terminal"))
    length(unique(variables)) == length(variables) ||
        throw(InvalidCircuitError(:variable_order, "decision variables must be unique"))
    length(variables) == length(alternatives) || throw(
        InvalidCircuitError(:variable_metadata, "each variable needs alternative metadata"),
    )
    for root in roots
        root isa Integer || throw(
            InvalidCircuitError(:root_reference, "roots must be integer node indices")
        )
        1 <= root <= length(nodes) ||
            throw(InvalidCircuitError(:root_reference, "root is outside the node table"))
    end
    for index in 3:length(nodes)
        node = nodes[index]
        node.var in eachindex(variables) || throw(
            InvalidCircuitError(
                :variable_order, "node $(index) refers to decision level $(node.var)"
            ),
        )
        expected = alternatives[node.var]
        length(node.branches) == length(expected) || throw(
            InvalidCircuitError(
                :outcome_arity,
                "node $(index) has $(length(node.branches)) branches for $(length(expected)) outcomes",
            ),
        )
        all(isequal(node.branches[1], child) for child in node.branches) && throw(
            InvalidCircuitError(
                :reduction, "a reduced node cannot have all branches identical"
            ),
        )
        for child in node.branches
            child isa Integer || throw(
                InvalidCircuitError(
                    :node_reference, "node $(index) has a non-integer child reference"
                ),
            )
            1 <= child < index || throw(
                InvalidCircuitError(
                    :acyclic_circuit, "node $(index) must point only to earlier nodes"
                ),
            )
            childnode = nodes[child]
            childnode.var == 0 ||
                childnode.var > node.var ||
                throw(
                    InvalidCircuitError(
                        :ordered_circuit, "decision levels must increase down every branch"
                    ),
                )
        end
    end
    return nothing
end

"""Validate a certificate and return it; evaluation only accepts this result.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> validate(ev.circuit) isa CircuitCertificate
true
```
"""
function validate(circuit::CertifiedCircuit)
    _validate_shape(circuit.nodes, circuit.roots, circuit.variables, circuit.alternatives)
    certificate = circuit.certificate
    certificate.support isa AbstractDict || throw(
        InvalidCircuitError(
            :support_certificate, "support must be a node-indexed dictionary"
        ),
    )
    certificate.decomposition isa AbstractDict || throw(
        InvalidCircuitError(
            :decomposition, "decomposition must be a node-indexed dictionary"
        ),
    )
    certificate.provenance isa AbstractDict || throw(
        InvalidCircuitError(:provenance, "provenance must be a node-indexed dictionary")
    )
    all(get(certificate.decomposition, i, false) for i in eachindex(circuit.nodes)) ||
        throw(
            InvalidCircuitError(
                :decomposition, "every node needs a decomposition certificate"
            ),
        )
    certificate.variable_order == circuit.variables || throw(
        InvalidCircuitError(
            :variable_order, "certificate order differs from circuit order"
        ),
    )
    certificate.determinism || throw(
        InvalidCircuitError(
            :determinism, "the event representation does not certify disjoint branches"
        ),
    )
    certificate.smoothness || throw(
        InvalidCircuitError(
            :smoothness, "the event representation does not account for skipped choices"
        ),
    )
    computed = _support_map(circuit)
    certificate.support == computed || throw(
        InvalidCircuitError(
            :support_certificate, "declared support differs from the circuit support"
        ),
    )
    for root in circuit.roots
        haskey(certificate.provenance, root) ||
            throw(InvalidCircuitError(:provenance, "root $(root) has no source provenance"))
    end
    return certificate
end
function validate(::BDD)
    return throw(
        UncertifiedCircuitError("a BDD must be wrapped in a valid CircuitCertificate")
    )
end
function validate(::AbstractEventCircuit)
    return throw(UncertifiedCircuitError("unknown event circuits are not certified"))
end

function _all_assignments(program::DSProgram)
    result = Tuple[]
    function visit(level, prefix)
        if level > length(program.choices)
            push!(result, tuple(prefix...))
            return nothing
        end
        for alternative in eachindex(program.choices[level].alternatives)
            push!(prefix, alternative)
            visit(level + 1, prefix)
            pop!(prefix)
        end
    end
    visit(1, Int[])
    return result
end

function _raw_bdd(program::DSProgram, assignments, truth)
    variables = tuple((choice.id for choice in program.choices)...)
    altmeta = tuple((choice.alternatives for choice in program.choices)...)
    index = Dict{Tuple,Int}(assignment => i for (i, assignment) in enumerate(assignments))
    ns = BDDNode[BDDNode(0, 0, 0, ()), BDDNode(0, 0, 0, ())]
    memo = Dict{Tuple{Int,Tuple},Int}()
    function build(level, prefix)
        if level > length(variables)
            return truth[index[tuple(prefix...)]] ? 2 : 1
        end
        key = (level, tuple(prefix...))
        haskey(memo, key) && return memo[key]
        children = Int[]
        for alternative in eachindex(altmeta[level])
            push!(prefix, alternative)
            push!(children, build(level + 1, prefix))
            pop!(prefix)
        end
        childtuple = tuple(children...)
        nodeid = if all(isequal(children[1], child) for child in children)
            children[1]
        else
            begin
            push!(ns, BDDNode(level, childtuple))
            length(ns)
        end
        end
        memo[key] = nodeid
        return nodeid
    end
    root = build(1, Int[])
    return BDD(ns, (root,); variables=variables, alternatives=altmeta)
end

function _certify(raw::BDD, provenance)
    # Compute shape and support before constructing the immutable certificate.
    _validate_shape(raw.nodes, raw.roots, raw.variables, raw.alternatives)
    provisional = CertifiedCircuit(
        raw.nodes,
        raw.roots,
        CircuitCertificate(
            Dict{Int,Tuple}(), raw.variables, Dict{Int,Bool}(), true, true, Dict{Int,Any}()
        );
        variables=raw.variables,
        alternatives=raw.alternatives,
    )
    supports = _support_map(provisional)
    decomposable = Dict{Int,Bool}(i => true for i in eachindex(raw.nodes))
    provenance_map = Dict{Int,Any}(
        i => (source=provenance, node=i) for i in eachindex(raw.nodes)
    )
    cert = CircuitCertificate(
        supports, raw.variables, decomposable, true, true, provenance_map
    )
    circuit = CertifiedCircuit(
        raw.nodes, raw.roots, cert; variables=raw.variables, alternatives=raw.alternatives
    )
    validate(circuit)
    return circuit
end

"""The event represented by a query and optional evidence.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> EventSpec(:a; evidence=:b)
EventSpec{Symbol, Symbol}(:a, :b)
```
"""
struct EventSpec{Q,E} <: AbstractEvent
    query::Q
    evidence::E
end
function EventSpec(query; evidence=nothing)
    return EventSpec{typeof(query),typeof(evidence)}(query, evidence)
end

"""A compiled event, with a certified BDD and replayable source metadata.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ev = compile_event(prog, :a);

julia> ev isa CompiledEvent
true
```
"""
struct CompiledEvent{E,C,P,PR,L,A,TQ,TE} <: AbstractEvent
    event::E
    circuit::C
    provenance::P
    program::PR
    labels::L
    assignments::A
    query_truth::TQ
    evidence_truth::TE
end

function _event_truths(program, assignments, query, evidence)
    if evidence === nothing
        qtruth = BitVector([
            _expression_value(query, world(program, assignment)) for
            assignment in assignments
        ])
        return qtruth, nothing
    end
    qtruth = BitVector(undef, length(assignments))
    etruth = BitVector(undef, length(assignments))
    for (i, assignment) in enumerate(assignments)
        atoms = world(program, assignment)
        qtruth[i] = _expression_value(query, atoms)
        etruth[i] = _expression_value(evidence, atoms)
    end
    return qtruth, etruth
end

function _default_labels(program)
    return Dict{Any,Any}(choice.id => choice.weights for choice in program.choices)
end

function _weighted_truth(program, assignments, truth, T)
    total = zero(T)
    for (assignment, included) in zip(assignments, truth)
        included || continue
        total += convert(T, choice_probability(program, assignment; T=T))
    end
    return total
end

"""Compile a finite query (and, when supplied, its joint evidence event).

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> compile_event(prog, :a) isa CompiledEvent
true
```
"""
function compile_event(
    program::DSProgram,
    query;
    evidence=nothing,
    backend=:bdd,
    profile::DSProfile=DSProfile(),
)
    backend === :bdd || throw(
        UnsupportedFeatureError(
            Symbol(backend),
            "this package provides only the reduced ordered BDD backend",
        ),
    )
    ground(program, query; profile=profile)
    evidence === nothing || _validate_ground(evidence, "evidence")
    assignments = _all_assignments(program)
    qtruth, etruth = _event_truths(program, assignments, query, evidence)
    truth = evidence === nothing ? qtruth : qtruth .& etruth
    if evidence !== nothing
        weight_types = [
            typeof(weight) for choice in program.choices for weight in choice.weights
        ]
        target_type = isempty(weight_types) ? Float64 : promote_type(weight_types...)
        mass = _weighted_truth(program, assignments, etruth, target_type)
        mass > zero(mass) ||
            throw(ZeroMassEvidenceError("the evidence event has zero probability"))
    end
    raw = _raw_bdd(program, assignments, truth)
    provenance = (
        backend=:bdd,
        query=query,
        evidence=evidence,
        profile=profile,
        choices=tuple((choice.id for choice in program.choices)...),
    )
    certified = _certify(raw, provenance)
    event = EventSpec(query; evidence=evidence)
    return CompiledEvent{
        typeof(event),
        typeof(certified),
        typeof(provenance),
        typeof(program),
        typeof(_default_labels(program)),
        typeof(assignments),
        typeof(qtruth),
        typeof(etruth),
    }(
        event,
        certified,
        provenance,
        program,
        _default_labels(program),
        assignments,
        qtruth,
        etruth,
    )
end
"""
Compile a query event; this is the named front-end alias for `compile_event`.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> query_event(prog, :a) isa CompiledEvent
true
```
"""
function query_event(
    program::DSProgram,
    query;
    evidence=nothing,
    backend=:bdd,
    profile::DSProfile=DSProfile(),
)
    return compile_event(
        program, query; evidence=evidence, backend=backend, profile=profile
    )
end
function compile_event(
    program::DSProgram, query, evidence; backend=:bdd, profile::DSProfile=DSProfile()
)
    return compile_event(
        program, query; evidence=evidence, backend=backend, profile=profile
    )
end
function compile_event(
    program::DSProgram, request::DSQuery; backend=:bdd, profile::DSProfile=DSProfile()
)
    return compile_event(
        program, request.query; evidence=request.evidence, backend=backend, profile=profile
    )
end
function query_event(
    program::DSProgram, request::DSQuery; backend=:bdd, profile::DSProfile=DSProfile()
)
    return compile_event(program, request; backend=backend, profile=profile)
end

validate(event::CompiledEvent) = validate(event.circuit)

function query_event(program::AbstractDSProgram, query; kwargs...)
    return throw(
        ProgramValidationError(:program_type, "expected DSProgram, got $(typeof(program))")
    )
end
function compile_event(program::AbstractDSProgram, query; kwargs...)
    return throw(
        ProgramValidationError(:program_type, "expected DSProgram, got $(typeof(program))")
    )
end

function _same_program(left::CompiledEvent, right::CompiledEvent)
    return left.program == right.program
end

function _event_truth(event::CompiledEvent)
    return if event.evidence_truth === nothing
        event.query_truth
    else
        event.query_truth .& event.evidence_truth
    end
end

function _joint(left::CompiledEvent, right::CompiledEvent)
    _same_program(left, right) || throw(
        ProgramValidationError(
            :shared_program,
            "query and evidence circuits must come from the same primitive choices",
        ),
    )
    truth = _event_truth(left) .& _event_truth(right)
    raw = _raw_bdd(left.program, left.assignments, truth)
    provenance = (
        backend=:bdd,
        query=left.event.query,
        evidence=right.event.query,
        profile=left.provenance.profile,
        choices=left.provenance.choices,
        combined=true,
    )
    cert = _certify(raw, provenance)
    event = EventSpec(left.event.query; evidence=right.event.query)
    return CompiledEvent(
        event, cert, provenance, left.program, left.labels, left.assignments, truth, nothing
    )
end
