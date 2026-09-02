"""
Typed knowledge graphs and their relational Kripke adapter.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e = KGEntity(:e1)
KGEntity{Symbol, Symbol, @NamedTuple{}}(:e1, :entity, NamedTuple())
```
"""
module AletheiaGraphs

using AletheiaCore
using Graphs
using MetaGraphsNext

"""
Abstract supertype for graph entities.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> KGEntity(:e1) isa AbstractKGEntity
true
```
"""
abstract type AbstractKGEntity end

"""
Abstract supertype for typed graph relations.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> KGRelation(:r1) isa AbstractKGRelation
true
```
"""
abstract type AbstractKGRelation end

"""
A typed graph entity with an identifier, kind, and immutable metadata.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e = KGEntity(:e1; kind=:person)
KGEntity{Symbol, Symbol, @NamedTuple{}}(:e1, :person, NamedTuple())
```
"""
struct KGEntity{I,K,M} <: AbstractKGEntity
    id::I
    kind::K
    metadata::M
end
KGEntity(id; kind=:entity, metadata=NamedTuple()) = KGEntity(id, kind, metadata)

"""
A named typed relation, with domain and range kind constraints.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> r = KGRelation(:knows; domain=:person, range=:person)
KGRelation{Symbol, Symbol, Symbol, @NamedTuple{}}(:knows, :person, :person, NamedTuple())
```
"""
struct KGRelation{I,D,R,M} <: AbstractKGRelation
    id::I
    domain::D
    range::R
    metadata::M
end
function KGRelation(id; domain=:Any, range=:Any, metadata=NamedTuple())
    return KGRelation(id, domain, range, metadata)
end

"""
Source information attached to a graph edge.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> p = KGProvenance(:source_doc)
KGProvenance{Symbol, Nothing, Nothing, Nothing}(:source_doc, nothing, nothing, nothing)
```
"""
struct KGProvenance{S,L,T,H}
    source::S
    locator::L
    timestamp::T
    content_hash::H
end
function KGProvenance(source; locator=nothing, timestamp=nothing, content_hash=nothing)
    return KGProvenance(source, locator, timestamp, content_hash)
end

"""
A directed, typed graph edge and its source provenance.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:rel);

julia> edge = KGEdge(e1, r, e2);

julia> edge.source.id
:e1
```
"""
struct KGEdge{E,R,P}
    source::E
    relation::R
    target::E
    provenance::P
end
function KGEdge(
    source::KGEntity,
    relation::KGRelation,
    target::KGEntity,
    provenance=KGProvenance(:unknown),
)
    return KGEdge{typeof(source),typeof(relation),typeof(provenance)}(
        source, relation, target, provenance
    )
end

"""
A validated collection of entities, relation schemas, edges, and graph provenance.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:rel);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> length(entities(g))
2
```
"""
struct KnowledgeGraph{E,R,G,P}
    entities::E
    relations::R
    edges::G
    provenance::P
end

"""
A replayable path. Provenance is kept per traversed edge.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:rel);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> p = paths(g, :e1; max_hops=1)[1];

julia> p isa KGPath
true
```
"""
struct KGPath{E,R,P}
    entities::E
    relations::R
    edge_provenance::P
end

"""
A bounded reachable subgraph returned by [`subgraphs`](@ref).

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:rel);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> sub = subgraphs(g, :e1; max_hops=1)[1];

julia> sub isa KGSubgraph
true
```
"""
struct KGSubgraph{E,G}
    entities::E
    edges::G
end

function _asvector(xs, name)
    result = try
        collect(xs)
    catch
        throw(ArgumentError("$name must be an iterable collection"))
    end
    isempty(result) &&
        name === :entities &&
        throw(ArgumentError("a knowledge graph must contain at least one entity"))
    return result
end

function KnowledgeGraph(entities, relations, edges; provenance=())
    es = _asvector(entities, :entities)
    rs = _asvector(relations, :relations)
    gs = try
        collect(edges)
    catch
        throw(ArgumentError("edges must be an iterable collection or KGEdge"))
    end
    all(e -> e isa KGEntity, es) || throw(ArgumentError("entities must be KGEntity values"))
    all(r -> r isa KGRelation, rs) ||
        throw(ArgumentError("relations must be KGRelation values"))
    ids = [e.id for e in es]
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("entity identifiers must be unique"))
    rids = [r.id for r in rs]
    length(unique(rids)) == length(rids) ||
        throw(ArgumentError("relation identifiers must be unique"))
    entity_by_id = Dict(e.id => e for e in es)
    relation_set = Set(rs)
    for edge in gs
        edge isa KGEdge || throw(ArgumentError("edges must be KGEdge values"))
        haskey(entity_by_id, edge.source.id) && haskey(entity_by_id, edge.target.id) ||
            throw(ArgumentError("every edge endpoint must belong to the graph"))
        edge.relation in relation_set ||
            throw(ArgumentError("every edge relation must belong to the graph"))
        _kind_matches(edge.relation.domain, edge.source.kind) ||
            throw(ArgumentError("edge source kind violates relation domain"))
        _kind_matches(edge.relation.range, edge.target.kind) ||
            throw(ArgumentError("edge target kind violates relation range"))
    end
    return KnowledgeGraph(es, rs, gs, provenance)
end
function KnowledgeGraph(entities, relations, edge::KGEdge; provenance=())
    return KnowledgeGraph(entities, relations, [edge]; provenance=provenance)
end

function _kind_matches(expected, actual)
    return expected === nothing ||
           expected === :Any ||
           expected === Any ||
           isequal(expected, actual) ||
           (expected isa Type && actual isa expected)
end

"""
Return the entities in stable graph order.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); r = KGRelation(:rel);

julia> g = KnowledgeGraph([e1], [r], KGEdge[]);

julia> [e.id for e in entities(g)]
1-element Vector{Symbol}:
 :e1
```
"""
entities(graph::KnowledgeGraph) = graph.entities

"""
Return the relation schemas in stable graph order.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1], [r], KGEdge[]);

julia> [r.id for r in relations(g)]
1-element Vector{Symbol}:
 :r1
```
"""
relations(graph::KnowledgeGraph) = graph.relations

"""
Return the graph edges in stable insertion order.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> length(edges(g))
1
```
"""
edges(graph::KnowledgeGraph) = graph.edges

"""
Return graph-level provenance.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1], [r], KGEdge[]; provenance=:doc1);

julia> provenance(g)
:doc1
```
"""
provenance(graph::KnowledgeGraph) = graph.provenance

"""
Return a path's edge provenance, without interpreting it as a proof.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> p = paths(g, :e1; max_hops=1)[1];

julia> path_provenance(p)
(KGProvenance{Symbol, Nothing, Nothing, Nothing}(:unknown, nothing, nothing, nothing),)
```
"""
path_provenance(path::KGPath) = path.edge_provenance

function _entity(graph, x)
    x isa KGEntity && any(isequal(x), graph.entities) && return x
    for e in graph.entities
        isequal(e.id, x) && return e
    end
    return throw(KeyError(x))
end

function _relation_name(mapping, relation)
    result = if mapping isa AbstractDict
        (
            if haskey(mapping, relation)
                mapping[relation]
            else
                (
                    if haskey(mapping, relation.id)
                        mapping[relation.id]
                    else
                        throw(KeyError(relation))
                    end
                )
            end
        )
    else
        mapping(relation)
    end
    try
        hash(result)
    catch
        throw(ArgumentError("relation_map must return a hashable frame relation name"))
    end
    return result
end

function _edge_match(edge, source, relation)
    return isequal(edge.source, source) &&
           (relation === nothing || isequal(edge.relation, relation))
end

"""
    paths(graph, source; relation=nothing, target=nothing, max_hops, simple=true)

Enumerate directed typed paths from `source` up to `max_hops`. Paths are
returned in deterministic depth-first order and retain entities, relations, and
edge provenance, so they can be replayed with [`path_valid`](@ref). `simple`
prevents repeated entities when true. Path validity is graph membership only;
it is not logical entailment. The traversal uses Graphs.jl's directed graph
model and the typed edge metadata retained by this package.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> ps = paths(g, :e1; max_hops=1);

julia> length(ps)
1
```
"""
function paths(
    graph::KnowledgeGraph, source; relation=nothing, target=nothing, max_hops, simple=true
)
    max_hops isa Integer && max_hops >= 0 ||
        throw(ArgumentError("max_hops must be a non-negative integer"))
    simple isa Bool || throw(ArgumentError("simple must be a Bool"))
    start = _entity(graph, source)
    wanted_target = target === nothing ? nothing : _entity(graph, target)
    relation_filter = if relation === nothing
        nothing
    elseif relation isa KGRelation
        relation
    else
        position = findfirst(r -> isequal(r.id, relation), graph.relations)
        position === nothing ? nothing : graph.relations[position]
    end
    relation !== nothing && relation_filter === nothing && throw(KeyError(relation))
    result = KGPath[]
    function visit(current, es, rs, ps)
        if !isempty(rs) && (wanted_target === nothing || isequal(current, wanted_target))
            push!(result, KGPath(tuple(es...), tuple(rs...), tuple(ps...)))
        end
        length(rs) == max_hops && return nothing
        for edge in graph.edges
            _edge_match(edge, current, relation_filter) || continue
            simple && any(isequal(edge.target), es) && continue
            visit(
                edge.target,
                (es..., edge.target),
                (rs..., edge.relation),
                (ps..., edge.provenance),
            )
        end
    end
    visit(start, (start,), (), ())
    return result
end

"""
Check that every step and provenance item of a path is an edge in `graph`.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> p = paths(g, :e1; max_hops=1)[1];

julia> path_valid(p, g)
true
```
"""
function path_valid(path::KGPath, graph::KnowledgeGraph)
    length(path.entities) == length(path.relations) + 1 || return false
    length(path.relations) == length(path.edge_provenance) || return false
    all(e -> any(isequal(e), graph.entities), path.entities) || return false
    for i in eachindex(path.relations)
        any(
            edge ->
                isequal(edge.source, path.entities[i]) &&
                    isequal(edge.target, path.entities[i + 1]) &&
                    isequal(edge.relation, path.relations[i]) &&
                    isequal(edge.provenance, path.edge_provenance[i]),
            graph.edges,
        ) || return false
    end
    return true
end

"""
Alias for [`path_valid`](@ref), naming the graph-membership field explicitly.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> p = paths(g, :e1; max_hops=1)[1];

julia> path_validity(p, g)
true
```
"""
path_validity(path::KGPath, graph::KnowledgeGraph) = path_valid(path, graph)

"""
Enumerate one bounded reachable subgraph from `source`, retaining traversed edges.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> subs = subgraphs(g, :e1; max_hops=1);

julia> length(subs)
1
```
"""
function subgraphs(graph::KnowledgeGraph, source; max_hops)
    max_hops isa Integer && max_hops >= 0 ||
        throw(ArgumentError("max_hops must be a non-negative integer"))
    start = _entity(graph, source)
    seen_entities = KGEntity[start]
    seen_edges = KGEdge[]
    frontier = KGEntity[start]
    for _ in 1:max_hops
        next_frontier = KGEntity[]
        for current in frontier, edge in graph.edges
            isequal(edge.source, current) || continue
            any(isequal(edge), seen_edges) || push!(seen_edges, edge)
            any(isequal(edge.target), seen_entities) ||
                (push!(seen_entities, edge.target); push!(next_frontier, edge.target))
        end
        frontier = next_frontier
        isempty(frontier) && break
    end
    return [KGSubgraph(tuple(seen_entities...), tuple(seen_edges...))]
end

function _metagraph(graph::KnowledgeGraph)
    # MetaGraphsNext is the canonical labelled representation used at this
    # boundary; relation multiplicity remains in `graph.edges` because a
    # MetaGraph edge is keyed by an endpoint pair.
    backend = MetaGraphsNext.MetaGraph(
        Graphs.SimpleDiGraph(); label_type=Any, vertex_data_type=Any, edge_data_type=Any
    )
    for entity in graph.entities
        Graphs.add_vertex!(backend, entity.id, entity)
    end
    bypair = Dict{Tuple{Any,Any},Vector{KGEdge}}()
    for edge in graph.edges
        key = (edge.source.id, edge.target.id)
        push!(get!(bypair, key, KGEdge[]), edge)
    end
    for ((source, target), values) in bypair
        MetaGraphsNext.add_edge!(backend, source, target, values)
    end
    return backend
end

"""
Build an Aletheia frame whose worlds are graph entities.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> f = frame(g);

julia> f isa AletheiaGraphs.AletheiaCore.AbstractFrame
true
```
"""
function frame(graph::KnowledgeGraph; relation_map=identity, index=true)
    _metagraph(graph)
    names = Dict{Any,Any}()
    for relation_schema in graph.relations
        name = _relation_name(relation_map, relation_schema)
        haskey(names, name) && throw(
            ArgumentError("relation_map maps multiple typed relations to $(repr(name))")
        )
        names[name] = relation_schema
    end
    adjacency = Dict{Any,Dict{Any,Tuple}}(
        name => Dict(entity => () for entity in graph.entities) for (name, _) in names
    )
    for edge in graph.edges
        name = _relation_name(relation_map, edge.relation)
        row = adjacency[name][edge.source]
        edge.target in row || (adjacency[name][edge.source] = (row..., edge.target))
    end
    return AletheiaCore.Frame(tuple(graph.entities...), adjacency; index=index)
end

function _lookup_concept(callback, concept, world)
    callback isa AbstractDict && begin
        haskey(callback, (concept, world)) && return callback[(concept, world)]
        haskey(callback, (world, concept)) && return callback[(world, concept)]
        haskey(callback, concept) && return _nested_concept(callback[concept], world)
        haskey(callback, world) && return _nested_concept(callback[world], concept)
        throw(KeyError((concept, world)))
    end
    return callback(concept, world)
end
function _nested_concept(value, key)
    value isa AbstractSet && return key in value
    value isa AbstractDict &&
        return (haskey(value, key) ? value[key] : throw(KeyError(key)))
    value isa Function && return value(key)
    return value
end
function _default_concept(concept, world)
    kind = world.kind
    kind === concept && return true
    metadata = world.metadata
    if metadata isa AbstractDict && haskey(metadata, :concepts)
        concepts = metadata[:concepts]
        return concepts isa AbstractSet ? concept in concepts : concept in concepts
    end
    return false
end

"""
    model(graph; algebra=BOOLEAN, concept_valuation=nothing, relation_map=identity)

Map entities to worlds and typed relations to named frame relations. The
valuation callback receives a concept atom payload and a `KGEntity`, and may
return a Boolean or a value accepted by the selected Aletheia truth algebra.
This uses the existing `ValuationCallback` boundary; no graph-specific
semantics are introduced.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); e2 = KGEntity(:e2); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1, e2], [r], [KGEdge(e1, r, e2)]);

julia> m = model(g);

julia> m isa AletheiaGraphs.AletheiaCore.Model
true
```
"""
function model(
    graph::KnowledgeGraph; algebra=BOOLEAN, concept_valuation=nothing, relation_map=identity
)
    f = frame(graph; relation_map=relation_map)
    callback = concept_valuation === nothing ? _default_concept : concept_valuation
    valuation = AletheiaCore.ValuationCallback(
        (concept, world) -> _lookup_concept(callback, concept, world);
        vectorized=(concept, worldset) ->
            [_lookup_concept(callback, concept, world) for world in worldset],
    )
    return AletheiaCore.Model(f, algebra, valuation)
end

"""
    concept_atoms(graph; vocabulary)

Create pooled Aletheia atom formulas for a concept vocabulary. A dictionary
uses its keys as concept names; an iterable uses its values. The vocabulary is
syntax only: membership and confidence must be supplied separately through a
valuation callback.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1], [r], KGEdge[]);

julia> atoms = concept_atoms(g; vocabulary=[:person]);

julia> length(atoms)
1
```
"""
function concept_atoms(graph::KnowledgeGraph; vocabulary)
    names = vocabulary isa AbstractDict ? collect(keys(vocabulary)) : collect(vocabulary)
    isempty(names) && throw(ArgumentError("concept vocabulary must not be empty"))
    return [AletheiaCore.atom(name) for name in names]
end

"""
    concept_extension(concept, graph; algebra=BOOLEAN, concept_valuation=nothing,
                      relation_map=identity)

Evaluate a concept formula over graph entities and return one truth value per
entity in frame order. A present path is not an entailment proof, and a
numeric/neural confidence supplied by the callback remains a score rather than
proof metadata.

# Examples
```jldoctest
julia> using AletheiaGraphs

julia> e1 = KGEntity(:e1; kind=:person); r = KGRelation(:r1);

julia> g = KnowledgeGraph([e1], [r], KGEdge[]);

julia> atoms = concept_atoms(g; vocabulary=[:person]);

julia> concept_extension(atoms[1], g)
1-element BitVector:
 1
```
"""
function concept_extension(
    concept::AletheiaCore.Formula,
    graph::KnowledgeGraph;
    algebra=BOOLEAN,
    concept_valuation=nothing,
    relation_map=identity,
)
    return AletheiaCore.extension(
        concept,
        model(
            graph;
            algebra=algebra,
            concept_valuation=concept_valuation,
            relation_map=relation_map,
        ),
    )
end

export AbstractKGEntity,
    AbstractKGRelation,
    KGEntity,
    KGRelation,
    KGProvenance,
    KGEdge,
    KnowledgeGraph,
    KGPath,
    KGSubgraph
export entities,
    relations,
    edges,
    provenance,
    paths,
    subgraphs,
    path_valid,
    path_validity,
    path_provenance
export frame, model, concept_atoms, concept_extension

end
