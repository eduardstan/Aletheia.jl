# Bottom-up evaluation over the formula pool's dependency-ordered DAG.
# The walk is shared by Boolean and many-valued models; only the extension
# operations specialize on the algebra and their storage type.

struct _EvaluationPlan{P,A}
    positions::P
    adjacency::A
end

struct _EvaluationNode
    id::Int
    kind::Symbol
    payload::Any
    children::Tuple{Vararg{Int}}
end

function _evaluation_nodes(formula::Formula)
    dag_nodes = dag(formula)
    ids = [node.id for node in dag_nodes]
    nodes = Vector{_EvaluationNode}(undef, length(dag_nodes))
    for (slot, node) in enumerate(dag_nodes)
        child_slots = ntuple(i -> searchsortedfirst(ids, node.children[i]), length(node.children))
        nodes[slot] = _EvaluationNode(node.id, node.kind, node.payload, child_slots)
    end
    nodes
end

function _relation_names(nodes::Vector{_EvaluationNode})
    names = Set{Any}()
    for node in nodes
        if node.kind === :branch
            connective = node.payload
            if connective isa Diamond || connective isa Box
                push!(names, relation(connective))
            end
        end
    end
    names
end

function _cache_relation(frame::Frame, relation_name)
    stored = frame.relations
    (stored isa Function || stored isa _RelationProvider) && return false
    haskey(stored, relation_name) || return true
    !(stored[relation_name] isa Function)
end

function _relation_adjacency(frame::Frame, relation_name, positions)
    if frame.relations isa _IntervalRelationMap
        specialized = _interval_relation_adjacency(frame, frame.relations, relation_name, positions)
        specialized !== nothing && return specialized
    end
    world_count = length(frame)
    rows = Vector{Vector{Int}}(undef, world_count)
    columns = [falses(world_count) for _ in 1:world_count]
    seen = Set{Int}()
    for source in worlds(frame)
        source_position = get(positions, source, 0)
        1 <= source_position <= world_count || throw(KeyError(source))
        targets = Int[]
        empty!(seen)
        for target in accessible(frame, source, relation_name)
            target_position = get(positions, target, 0)
            1 <= target_position <= world_count || throw(KeyError(target))
            target_position in seen && continue
            push!(seen, target_position)
            push!(targets, target_position)
            columns[target_position][source_position] = true
        end
        rows[source_position] = targets
    end
    _RelationAdjacency(rows, columns)
end

function _evaluation_plan(nodes::Vector{_EvaluationNode}, model::Model)
    frame = model.frame
    cache = model.cache
    adjacency = Dict{Any,_RelationAdjacency}()
    for relation_name in _relation_names(nodes)
        if !_cache_relation(frame, relation_name)
            adjacency[relation_name] = _relation_adjacency(frame, relation_name, cache.positions)
            continue
        end
        lock(cache.lock)
        try
            if !haskey(cache.adjacency, relation_name)
                cache.adjacency[relation_name] = _relation_adjacency(frame, relation_name, cache.positions)
            end
            adjacency[relation_name] = cache.adjacency[relation_name]
        finally
            unlock(cache.lock)
        end
    end
    _EvaluationPlan(cache.positions, adjacency)
end

@inline function _node_atom(formula::Formula, node::_EvaluationNode)
    Atom(pool(formula), node.id, node.payload, _trusted_formula_handle)
end

function _atom_extension(node::_EvaluationNode, formula::Formula, model::Model{T}, positions, ::Type{Vector{T}})::Vector{T} where T
    values = Vector{T}(undef, length(frame(model)))
    atom_formula = _node_atom(formula, node)
    if model.valuation isa ValuationCallback && model.valuation.vectorized !== nothing
        raw_values = atom_values(model.valuation, atom_formula, worlds(frame(model)))
        length(raw_values) == length(values) || throw(ArgumentError("valuation callback returned $(length(raw_values)) values for $(length(values)) worlds"))
        for (slot, world) in enumerate(worlds(frame(model)))
            raw = raw_values[slot]
            raw isa T || throw(ArgumentError("valuation returned $(typeof(raw)); expected $T"))
            values[positions[world]] = _validate_atom_value(model.algebra, raw)
        end
    else
        for world in worlds(frame(model))
            values[positions[world]] = interpret(atom_formula, model, world)
        end
    end
    values
end

function _atom_extension(node::_EvaluationNode, formula::Formula, model::Model{Bool,A}, positions, ::Type{BitVector})::BitVector where {A<:BooleanAlgebra}
    values = falses(length(frame(model)))
    atom_formula = _node_atom(formula, node)
    if model.valuation isa ValuationCallback && model.valuation.vectorized !== nothing
        raw_values = atom_values(model.valuation, atom_formula, worlds(frame(model)))
        length(raw_values) == length(values) || throw(ArgumentError("valuation callback returned $(length(raw_values)) values for $(length(values)) worlds"))
        for (slot, world) in enumerate(worlds(frame(model)))
            raw = raw_values[slot]
            raw isa Bool || throw(ArgumentError("valuation returned $(typeof(raw)); expected Bool"))
            values[positions[world]] = raw
        end
    else
        for world in worlds(frame(model))
            values[positions[world]] = interpret(atom_formula, model, world)
        end
    end
    values
end

function _negation_extension(algebra::TruthAlgebra, values::Vector{T})::Vector{T} where T
    result = Vector{T}(undef, length(values))
    for i in eachindex(values)
        result[i] = negation(algebra, values[i])::T
    end
    result
end

function _negation_extension(::BooleanAlgebra, values::BitVector)::BitVector
    .~values
end

function _meet_extension(algebra::TruthAlgebra, left::Vector{T}, right::Vector{T})::Vector{T} where T
    result = Vector{T}(undef, length(left))
    for i in eachindex(left)
        result[i] = meet(algebra, left[i], right[i])::T
    end
    result
end

function _meet_extension(::BooleanAlgebra, left::BitVector, right::BitVector)::BitVector
    left .& right
end

function _join_extension(algebra::TruthAlgebra, left::Vector{T}, right::Vector{T})::Vector{T} where T
    result = Vector{T}(undef, length(left))
    for i in eachindex(left)
        result[i] = join(algebra, left[i], right[i])::T
    end
    result
end

function _join_extension(::BooleanAlgebra, left::BitVector, right::BitVector)::BitVector
    left .| right
end

function _implication_extension(algebra::TruthAlgebra, left::Vector{T}, right::Vector{T})::Vector{T} where T
    result = Vector{T}(undef, length(left))
    for i in eachindex(left)
        result[i] = implication(algebra, left[i], right[i])::T
    end
    result
end

function _implication_extension(::BooleanAlgebra, left::BitVector, right::BitVector)::BitVector
    (.~left) .| right
end

function _diamond_extension(algebra::TruthAlgebra, child::Vector{T}, adjacency::_RelationAdjacency)::Vector{T} where T
    rows = adjacency.rows
    result = Vector{T}(undef, length(rows))
    for source in eachindex(rows)
        value = bottom(algebra)::T
        for target in rows[source]
            value = join(algebra, value, child[target])::T
        end
        result[source] = value
    end
    result
end

function _diamond_extension(::BooleanAlgebra, child::BitVector, adjacency::_RelationAdjacency)::BitVector
    result = falses(length(child))
    for target in eachindex(child)
        child[target] && (result .|= adjacency.columns[target])
    end
    result
end

function _box_extension(algebra::TruthAlgebra, child::Vector{T}, adjacency::_RelationAdjacency)::Vector{T} where T
    rows = adjacency.rows
    result = Vector{T}(undef, length(rows))
    for source in eachindex(rows)
        value = top(algebra)::T
        for target in rows[source]
            value = meet(algebra, value, child[target])::T
        end
        result[source] = value
    end
    result
end

function _box_extension(::BooleanAlgebra, child::BitVector, adjacency::_RelationAdjacency)::BitVector
    .~_diamond_extension(BOOLEAN, .~child, adjacency)
end

function _branch_extension(node::_EvaluationNode, values::Vector{E}, model::Model, plan::_EvaluationPlan, ::Type{E})::E where E
    connective = node.payload
    if connective isa Negation
        return _negation_extension(model.algebra, values[node.children[1]])
    elseif connective isa Conjunction
        return _meet_extension(model.algebra, values[node.children[1]], values[node.children[2]])
    elseif connective isa Disjunction
        return _join_extension(model.algebra, values[node.children[1]], values[node.children[2]])
    elseif connective isa Implication
        return _implication_extension(model.algebra, values[node.children[1]], values[node.children[2]])
    elseif connective isa Diamond
        return _diamond_extension(model.algebra, values[node.children[1]], plan.adjacency[relation(connective)])
    elseif connective isa Box
        return _box_extension(model.algebra, values[node.children[1]], plan.adjacency[relation(connective)])
    end
    throw(ArgumentError("no evaluator for connective $(repr(connective))"))
end

function _node_extension(node::_EvaluationNode, formula::Formula, model::Model, values::Vector{E}, plan::_EvaluationPlan, ::Type{E})::E where E
    node.kind === :atom && return _atom_extension(node, formula, model, plan.positions, E)
    _branch_extension(node, values, model, plan, E)
end

function _evaluate(formula::Formula, model::Model, ::Type{E})::E where E
    nodes = _evaluation_nodes(formula)
    values = Vector{E}(undef, length(nodes))
    plan = _evaluation_plan(nodes, model)
    for (slot, node) in enumerate(nodes)
        values[slot] = _node_extension(node, formula, model, values, plan, E)
    end
    values[end]
end

"""
    Extension(values, worlds)
    Extension(values, model)

A display view wrapping an extension result vector and world tuple to provide
a rich REPL display showing which worlds satisfy the formula.  The model form
also keeps the model's algebra, so graded truth values are shown as the
algebra's elements rather than as its carrier representation.
"""
struct Extension{T,V<:AbstractVector{T},W<:Tuple,A}
    values::V
    worlds::W
    algebra::A

    function Extension(values::V, worlds::W, algebra::A=nothing) where {T, V<:AbstractVector{T}, W<:Tuple, A}
        new{T, V, W, A}(values, worlds, algebra)
    end
end

Extension(values::AbstractVector, worlds) = Extension(values, Tuple(worlds))
Extension(values::AbstractVector, model::Model) = Extension(values, frame(model).worlds, algebra(model))

"""
    describe(extension_result, model)

Return an [`Extension`](@ref) view of `extension_result` over `model` for rich REPL printing.
"""
describe(ext::AbstractVector, model::Model) = Extension(ext, model)
describe(io::IO, ext::AbstractVector, model::Model) = show(io, MIME("text/plain"), Extension(ext, model))

Base.show(io::IO, ext::Extension) = print(io, "Extension(", ext.values, ")")

"""Print one `Label: w1, w2, …` line of an extension, bounded by the IO context."""
function _display_worlds_line(io::IO, label::AbstractString, worlds)
    _display_label(io, 2, label)
    if isempty(worlds)
        print(io, "(none)")
        return
    end
    shown, elided = _display_bounded(io, worlds, DISPLAY_ITEMS)
    print(io, join(repr.(shown), ", "))
    _display_elision(io, elided)
end

function Base.show(io::IO, ::MIME"text/plain", ext::Extension{Bool})
    n_tot = length(ext.worlds)
    n_sat = count(ext.values)
    _display_header(io, "Extension", "$n_sat of $n_tot world$(n_tot == 1 ? "" : "s") satisfy")
    _display_worlds_line(io, "Satisfied at", [ext.worlds[i] for i in 1:n_tot if ext.values[i]])
    _display_worlds_line(io, "Unsatisfied at", [ext.worlds[i] for i in 1:n_tot if !ext.values[i]])
end

function Base.show(io::IO, ::MIME"text/plain", ext::Extension)
    n_tot = length(ext.worlds)
    _display_header(io, "Extension", "$n_tot world$(n_tot == 1 ? "" : "s")")
    shown, elided = _display_bounded(io, 1:n_tot, DISPLAY_ITEMS)
    for i in shown
        _display_label(io, 2, repr(ext.worlds[i]), " => ")
        print(io, _display_truth(ext.algebra, ext.values[i]))
    end
    _display_elision_line(io, 2, elided)
end

"""
    extension(φ, model)

Return the extension of `φ` over the model's worlds, in world-index order (or
enumeration order when no index is supplied). A Boolean model returns a `BitVector`;
every other algebra returns a vector whose element type is the algebra's carrier type.
To construct a rich display view of the extension, pass the result and model to
[`Extension`](@ref) or [`describe`](@ref).
"""
function extension(formula::Formula, model::Model{Bool,A}) where {A<:BooleanAlgebra}
    _evaluate(formula, model, BitVector)
end

function extension(formula::Formula, model::Model{T}) where T
    _evaluate(formula, model, Vector{T})
end

"""
    check(φ, model, world)

Return the truth value of `φ` at `world`.  The result is exactly the carrier
type of the model's algebra.  Evaluation uses the same DAG walk as
[`extension`](@ref).
"""
function check(formula::Formula, model::Model{Bool,A}, world)::Bool where {A<:BooleanAlgebra}
    position = world_position(frame(model), world)
    values = _evaluate(formula, model, BitVector)
    values[position]
end

function check(formula::Formula, model::Model{T}, world)::T where T
    position = world_position(frame(model), world)
    values = _evaluate(formula, model, Vector{T})
    values[position]
end

"""Check whether a formula holds at some world via the incumbent marker."""
function check(formula::Formula, model::Model{Bool,A}, ::AnyWorld)::Bool where {A<:BooleanAlgebra}
    any(extension(formula, model))
end
function check(formula::Formula, model::Model{T}, ::AnyWorld)::Bool where T
    any(value -> value == top(algebra(model)), extension(formula, model))
end
