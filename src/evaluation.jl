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
    Atom(pool(formula), node.id, node.payload)
end

function _atom_extension(node::_EvaluationNode, formula::Formula, model::Model{T}, positions, ::Type{Vector{T}})::Vector{T} where T
    values = Vector{T}(undef, length(frame(model)))
    atom_formula = _node_atom(formula, node)
    for world in worlds(frame(model))
        values[positions[world]] = interpret(atom_formula, model, world)
    end
    values
end

function _atom_extension(node::_EvaluationNode, formula::Formula, model::Model{Bool,A}, positions, ::Type{BitVector})::BitVector where {A<:BooleanAlgebra}
    values = falses(length(frame(model)))
    atom_formula = _node_atom(formula, node)
    for world in worlds(frame(model))
        values[positions[world]] = interpret(atom_formula, model, world)
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
a rich REPL display showing which worlds satisfy the formula.
"""
struct Extension{T,V<:AbstractVector{T},W<:Tuple}
    values::V
    worlds::W

    function Extension(values::V, worlds::W) where {T, V<:AbstractVector{T}, W<:Tuple}
        new{T, V, W}(values, worlds)
    end
end

Extension(values::AbstractVector, worlds) = Extension(values, Tuple(worlds))
Extension(values::AbstractVector, model::Model) = Extension(values, frame(model).worlds)

"""
    describe(extension_result, model)

Return an [`Extension`](@ref) view of `extension_result` over `model` for rich REPL printing.
"""
describe(ext::AbstractVector, model::Model) = Extension(ext, model)
describe(io::IO, ext::AbstractVector, model::Model) = show(io, MIME("text/plain"), Extension(ext, model))

Base.show(io::IO, ext::Extension) = print(io, "Extension(", ext.values, ")")

function Base.show(io::IO, ::MIME"text/plain", ext::Extension{Bool})
    n_tot = length(ext.worlds)
    n_sat = count(ext.values)
    print(io, "Extension ($n_sat of $n_tot world$(n_tot == 1 ? "" : "s") satisfy)")
    sat_worlds = [ext.worlds[i] for i in 1:n_tot if ext.values[i]]
    unsat_worlds = [ext.worlds[i] for i in 1:n_tot if !ext.values[i]]

    if n_tot <= 15
        sat_str = isempty(sat_worlds) ? "(none)" : join(repr.(sat_worlds), ", ")
        unsat_str = isempty(unsat_worlds) ? "(none)" : join(repr.(unsat_worlds), ", ")
        print(io, "\n  Satisfied at: ", sat_str)
        print(io, "\n  Unsatisfied at: ", unsat_str)
    else
        if !isempty(sat_worlds)
            shown = join(repr.(sat_worlds[1:min(5, length(sat_worlds))]), ", ")
            elided = length(sat_worlds) > 5 ? ", … ($(length(sat_worlds)-5) elided)" : ""
            print(io, "\n  Satisfied at: ", shown, elided)
        else
            print(io, "\n  Satisfied at: (none)")
        end
    end
end

function Base.show(io::IO, ::MIME"text/plain", ext::Extension{T}) where T
    n_tot = length(ext.worlds)
    print(io, "Extension ($n_tot world$(n_tot == 1 ? "" : "s"))")
    if n_tot <= 15
        for i in 1:n_tot
            print(io, "\n  ", repr(ext.worlds[i]), " => ", ext.values[i])
        end
    else
        for i in 1:5
            print(io, "\n  ", repr(ext.worlds[i]), " => ", ext.values[i])
        end
        print(io, "\n  … ($(n_tot - 5) elided)")
    end
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

