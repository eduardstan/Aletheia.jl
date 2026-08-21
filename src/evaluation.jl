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
    stored isa Function && return false
    haskey(stored, relation_name) || return true
    !(stored[relation_name] isa Function)
end

function _relation_adjacency(frame::Frame, relation_name, positions)
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
    extension(φ, model)

Return the extension of `φ` over the model's worlds, in world-index order (or enumeration order when no index is present).  A
Boolean model returns a `BitVector`; every other algebra returns a vector whose
element type is exactly the algebra's carrier type.  The formula DAG is
walked bottom-up and each reachable subterm is evaluated once.
"""
function extension(formula::Formula, model::Model{Bool,A})::BitVector where {A<:BooleanAlgebra}
    _evaluate(formula, model, BitVector)
end

function extension(formula::Formula, model::Model{T})::Vector{T} where T
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
