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

function _fusion_extension(algebra::TruthAlgebra, left::Vector{T}, right::Vector{T})::Vector{T} where T
    result = Vector{T}(undef, length(left))
    for i in eachindex(left)
        result[i] = fusion(algebra, left[i], right[i])::T
    end
    result
end

function _fusion_extension(::BooleanAlgebra, left::BitVector, right::BitVector)::BitVector
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

# Box is universal quantification, so it folds successor values with the
# lattice meet (infimum), not monoid fusion.
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
    elseif connective isa Fusion
        return _fusion_extension(model.algebra, values[node.children[1]], values[node.children[2]])
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

# Build one dependency-ordered evaluator for all roots.  Formula ids are local
# to a pool, so the pool's ids are the natural union-DAG key.
function _batch_evaluation_nodes(formulas::AbstractVector{<:Formula})
    formula_pool = pool(first(formulas))
    ids = Int[]
    for formula in formulas
        append!(ids, subterms(formula))
    end
    sort!(unique!(ids))
    positions = Dict(id => slot for (slot, id) in enumerate(ids))
    nodes = Vector{_EvaluationNode}(undef, length(ids))
    for (slot, node_id) in enumerate(ids)
        node = dag(formula_pool, node_id)
        children = ntuple(i -> positions[node.children[i]], length(node.children))
        nodes[slot] = _EvaluationNode(node.id, node.kind, node.payload, children)
    end
    nodes, positions
end

function _batch_evaluate(formulas::AbstractVector{<:Formula}, model::Model, ::Type{E})::Vector{E} where E
    nodes, positions = _batch_evaluation_nodes(formulas)
    _batch_evaluate(formulas, nodes, positions, model, E)
end

# The family evaluator reuses the union-DAG plan across instances.  Formula
# roots are still copied so repeated roots remain independent to callers.
function _batch_evaluate(formulas::AbstractVector{<:Formula}, nodes::Vector{_EvaluationNode},
        positions::Dict{Int,Int}, model::Model{Bool}, plan::_EvaluationPlan)::Vector{BitVector}
    _batch_evaluate(formulas, nodes, positions, model, plan, BitVector)
end

function _batch_evaluate(formulas::AbstractVector{<:Formula}, nodes::Vector{_EvaluationNode},
        positions::Dict{Int,Int}, model::Model{T}, plan::_EvaluationPlan)::Vector{Vector{T}} where T
    _batch_evaluate(formulas, nodes, positions, model, plan, Vector{T})
end

function _batch_evaluate(formulas::AbstractVector{<:Formula}, nodes::Vector{_EvaluationNode},
        positions::Dict{Int,Int}, model::Model, ::Type{E})::Vector{E} where E
    plan = _evaluation_plan(nodes, model)
    _batch_evaluate(formulas, nodes, positions, model, plan, E)
end

function _batch_evaluate(formulas::AbstractVector{<:Formula}, nodes::Vector{_EvaluationNode},
        positions::Dict{Int,Int}, model::Model, plan::_EvaluationPlan, ::Type{E})::Vector{E} where E
    values = Vector{E}(undef, length(nodes))
    root_slots = [positions[id(formula)] for formula in formulas]
    for (slot, node) in enumerate(nodes)
        values[slot] = _node_extension(node, first(formulas), model, values, plan, E)
    end
    [deepcopy(values[slot]) for slot in root_slots]
end

"""
    EvaluationCache(model)

An explicit cache for extensions evaluated against `model`.  Pass it as the
`cache` keyword to [`extension`](@ref) or [`check`](@ref) to reuse a formula's
extension on later calls.  Formula ids are used as keys because formulas are
hash-consed; the cache also records the formula pool on first use so ids from a
different pool cannot collide.

The cache is tied to the exact model object passed to this constructor.  It is
correct only while that model's valuation, frame, and algebra (including any
mutable objects reachable through them) remain unchanged.  The cache does not
inspect or snapshot those objects, so call [`clear!`](@ref) after changing one.
Cached `extension` and `check` calls return deep copies, so changing a returned
vector or mutable carrier value does not change the retained result.  `clear!(cache)`
removes all retained extensions and permits the cache to be used with a new
formula pool, while retaining its model binding.  If a model is mutated, discard
the cache; `clear!` cannot repair relation adjacency already cached by its
`Frame`.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("EvaluationCache"))
true
```
"""
mutable struct EvaluationCache
    model::Model
    pool::Union{Nothing,FormulaPool}
    values::Dict{Int,Any}
    lock::ReentrantLock
end

EvaluationCache(model::Model) = EvaluationCache(model, nothing, Dict{Int,Any}(), ReentrantLock())

"""Clear all extensions retained by an [`EvaluationCache`](@ref)."""
function clear!(cache::EvaluationCache)
    lock(cache.lock)
    try
        empty!(cache.values)
        cache.pool = nothing
    finally
        unlock(cache.lock)
    end
    cache
end

function _cached_evaluate(formula::Formula, model::Model, ::Type{E}, cache::EvaluationCache)::E where E
    cache.model === model || throw(ArgumentError("evaluation cache belongs to a different model"))
    lock(cache.lock)
    try
        formula_pool = pool(formula)
        if cache.pool === nothing
            cache.pool = formula_pool
        elseif cache.pool !== formula_pool
            throw(ArgumentError("evaluation cache cannot mix formula pools"))
        end
        key = id(formula)
        if haskey(cache.values, key)
            value = cache.values[key]
            value isa E || throw(ArgumentError("evaluation cache contains a result for a different carrier type"))
            return value::E
        end
        value = _evaluate(formula, model, E)
        cache.values[key] = value
        value
    finally
        unlock(cache.lock)
    end
end

function _evaluate_with_cache(formula::Formula, model::Model, ::Type{E}, ::Nothing)::E where E
    _evaluate(formula, model, E)
end
function _evaluate_with_cache(formula::Formula, model::Model, ::Type{E}, cache::EvaluationCache)::E where E
    _cached_evaluate(formula, model, E, cache)
end
function _evaluate_with_cache(formula::Formula, model::Model, ::Type{E}, cache)::E where E
    throw(ArgumentError("cache must be nothing or an EvaluationCache"))
end

"""
    Extension(values, worlds, algebra)
    Extension(values, model)

A display view wrapping an extension result vector, world tuple, and truth
algebra to provide a rich REPL display showing which worlds satisfy the
formula.  Graded truth values are shown as the algebra's elements rather than
as its carrier representation.
"""
struct Extension{T,V<:AbstractVector{T},W<:Tuple,A<:TruthAlgebra}
    values::V
    worlds::W
    algebra::A

    function Extension(values::V, worlds::W, algebra::A) where {T, V<:AbstractVector{T}, W<:Tuple, A<:TruthAlgebra}
        new{T, V, W, A}(values, worlds, algebra)
    end
end

Extension(values::AbstractVector, worlds, algebra) = Extension(values, Tuple(worlds), algebra)
Extension(values::AbstractVector, model::Model) = Extension(values, frame(model).worlds, algebra(model))

"""
    describe(extension_result, model)

Return an `Extension` view of `extension_result` over `model` for rich REPL printing.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("describe"))
true
```
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
`Extension` or [`describe`](@ref).
"""
function _batch_formulas(formulas::AbstractVector)
    normalized = Formula[]
    for (position, formula) in enumerate(formulas)
        formula isa Atom || formula isa Branch || throw(ArgumentError(
            "batch formulas[$position] must be an Aletheia Atom or Branch, got $(typeof(formula))"))
        push!(normalized, formula)
    end
    isempty(normalized) && return normalized
    formula_pool = pool(first(normalized))
    for (position, formula) in enumerate(normalized)
        pool(formula) === formula_pool || throw(ArgumentError(
            "batch formulas must belong to one FormulaPool (formulas[$position] does not)"))
    end
    normalized
end

function _batch_evaluate_with_cache(formulas::Vector{Formula}, model::Model, ::Type{E}, ::Nothing)::Vector{E} where E
    _batch_evaluate(formulas, model, E)
end

function _batch_evaluate_with_cache(formulas::Vector{Formula}, model::Model, ::Type{E}, cache::EvaluationCache)::Vector{E} where E
    cache.model === model || throw(ArgumentError("evaluation cache belongs to a different model"))
    lock(cache.lock)
    try
        formula_pool = pool(first(formulas))
        if cache.pool === nothing
            cache.pool = formula_pool
        elseif cache.pool !== formula_pool
            throw(ArgumentError("evaluation cache cannot mix formula pools"))
        end
        results = Vector{E}(undef, length(formulas))
        missing_formulas = Formula[]
        missing_positions = Int[]
        for (position, formula) in enumerate(formulas)
            key = id(formula)
            if haskey(cache.values, key)
                value = cache.values[key]
                value isa E || throw(ArgumentError(
                    "evaluation cache contains a result for a different carrier type"))
                results[position] = deepcopy(value)
            else
                push!(missing_formulas, formula)
                push!(missing_positions, position)
            end
        end
        isempty(missing_formulas) && return results
        computed = _batch_evaluate(missing_formulas, model, E)
        for (computed_position, result_position) in enumerate(missing_positions)
            value = computed[computed_position]
            cache.values[id(formulas[result_position])] = value
            results[result_position] = deepcopy(value)
        end
        results
    finally
        unlock(cache.lock)
    end
end

function _batch_evaluate_with_cache(formulas::Vector{Formula}, model::Model, ::Type{E}, cache)::Vector{E} where E
    throw(ArgumentError("cache must be nothing or an EvaluationCache"))
end

"""
    extension(formulas, model)

Evaluate a vector of formulas in one shared pooled-DAG pass and return one
extension per formula, in input order.  All formulas must belong to the same
[`FormulaPool`](@ref).  A Boolean model returns `Vector{BitVector}`; a model
with carrier `T` returns `Vector{Vector{T}}`.  Repeated pooled subformulas,
including atoms, are evaluated once per model.  The `cache` keyword has the
same model and pool restrictions as the single-formula method.

For a model family, `extension(formulas, family)` returns one vector per
formula, each containing that formula's extensions in instance order.  The
shared pass is run once for each instance.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("extension"))
true
```
"""
function extension(formulas::AbstractVector, model::Model{Bool,A}; cache=nothing) where {A<:BooleanAlgebra}
    normalized = _batch_formulas(formulas)
    isempty(normalized) && return BitVector[]
    _batch_evaluate_with_cache(normalized, model, BitVector, cache)
end

function extension(formulas::AbstractVector, model::Model{T}; cache=nothing) where T
    normalized = _batch_formulas(formulas)
    isempty(normalized) && return Vector{T}[]
    _batch_evaluate_with_cache(normalized, model, Vector{T}, cache)
end

function extension(formula::Formula, model::Model{Bool,A}; cache=nothing) where {A<:BooleanAlgebra}
    values = _evaluate_with_cache(formula, model, BitVector, cache)
    cache === nothing ? values : deepcopy(values)
end

function extension(formula::Formula, model::Model{T}; cache=nothing) where T
    values = _evaluate_with_cache(formula, model, Vector{T}, cache)
    cache === nothing ? values : deepcopy(values)
end

"""
    check(φ, model, world)

Return the truth value of `φ` at `world`.  The result is exactly the carrier
type of the model's algebra.  Evaluation uses the same DAG walk as
[`extension`](@ref).


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("check"))
true
```
"""
function check(formula::Formula, model::Model{Bool,A}, world; cache=nothing)::Bool where {A<:BooleanAlgebra}
    position = world_position(frame(model), world)
    values = _evaluate_with_cache(formula, model, BitVector, cache)
    values[position]
end

function check(formula::Formula, model::Model{T}, world; cache=nothing)::T where T
    position = world_position(frame(model), world)
    values = _evaluate_with_cache(formula, model, Vector{T}, cache)
    cache === nothing ? values[position] : deepcopy(values[position])
end

"""Check whether a formula holds at some world via the SoleLogics marker."""
function check(formula::Formula, model::Model{Bool,A}, ::AnyWorld; cache=nothing)::Bool where {A<:BooleanAlgebra}
    any(extension(formula, model; cache=cache))
end
function check(formula::Formula, model::Model{T}, ::AnyWorld; cache=nothing)::Bool where T
    any(value -> value == top(algebra(model)), extension(formula, model; cache=cache))
end
