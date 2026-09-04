using Aqua
using JET
using Test
using Serialization
using AletheiaGraphs
using AletheiaCore
using AletheiaAudit

alice = KGEntity(:alice; kind=:person)
bob = KGEntity(:bob; kind=:person)
carol = KGEntity(:carol; kind=:place)
knows = KGRelation(:knows; domain=:person, range=:person)
visits = KGRelation(:visits; domain=:person, range=:place)
p1 = KGProvenance(:directory; locator="row-1", content_hash="abc")
p2 = KGProvenance(:calendar; locator="row-2")
g = KnowledgeGraph(
    [alice, bob, carol],
    [knows, visits],
    [KGEdge(alice, knows, bob, p1), KGEdge(bob, visits, carol, p2)],
)

mutable struct MutableGraphMetadata
    value::Int
end

@testset "graph constructors reject mutable opaque metadata" begin
    payload = MutableGraphMetadata(1)
    @test_throws OwnershipError KGEntity(:payload; metadata=Dict(:payload => payload))
end

@testset "typed graph and replayable paths" begin
    ps = paths(g, :alice; max_hops=2, simple=true)
    @test length(ps) == 2
    @test ps[2].entities == (alice, bob, carol)
    @test path_valid(ps[2], g)
    @test path_validity(ps[2], g)
    @test path_provenance(ps[2]) == (p1, p2)
    io = IOBuffer()
    serialize(io, ps[2])
    seekstart(io)
    @test path_valid(deserialize(io), g)
    @test length(paths(g, :alice; relation=:visits, max_hops=2)) == 0
    @test_throws ArgumentError paths(g, :alice; max_hops=-1)
    @test_throws KeyError paths(g, :missing; max_hops=1)
    @test length(paths(g, :alice; relation=knows, max_hops=1)) == 1
    @test length(subgraphs(g, :alice; max_hops=1)) == 1
    @test length(subgraphs(g, :alice; max_hops=1)[1].edges) == 1
end

@testset "frame and semantic correspondence" begin
    f = AletheiaGraphs.frame(g; relation_map=r -> r.id)
    @test worlds(f) == (alice, bob, carol)
    @test collect(accessible(f, alice, :knows)) == [bob]
    @test collect(accessible(f, bob, :visits)) == [carol]
    mapped = AletheiaGraphs.frame(g; relation_map=Dict(knows => :knows, visits => :visits))
    @test collect(accessible(mapped, alice, :knows)) == [bob]
    pool = FormulaPool(Signature([Diamond(:knows)]))
    formula = branch(pool, Diamond(:knows), atom(pool, :trusted))
    valuation = (name, entity) -> name == :trusted && entity.id == :bob
    m = AletheiaGraphs.model(g; relation_map=r -> r.id, concept_valuation=valuation)
    @test AletheiaCore.extension(formula, m) == BitVector([true, false, false])
    @test concept_extension(atom(:trusted), g; concept_valuation=valuation) ==
        BitVector([false, true, false])
    fuzzy = concept_extension(
        atom(:trusted),
        g;
        algebra=GodelAlgebra(3),
        concept_valuation=(n, e)->e.id == :alice ? 1.0 : 0.5,
    )
    @test fuzzy == [1.0, 0.5, 0.5]
end

@testset "contracts" begin
    @test_throws ArgumentError KnowledgeGraph(
        [alice, alice], [knows], KGEdge(alice, knows, bob)
    )
    bad = KGRelation(:bad; domain=:place, range=:person)
    @test_throws ArgumentError KnowledgeGraph([alice, bob], [bad], KGEdge(alice, bad, bob))
    @test_throws ArgumentError concept_atoms(g; vocabulary=[])
    @test length(concept_atoms(g; vocabulary=Dict(:trusted => :unused))) == 1
    @test concept_extension(
        atom(:trusted),
        g;
        concept_valuation=Dict(
            (:trusted, alice) => true, (:trusted, bob) => false, (:trusted, carol) => false
        ),
    ) == BitVector([true, false, false])
    @test concept_extension(
        atom(:trusted),
        g;
        concept_valuation=Dict(
            (alice, :trusted) => true, (bob, :trusted) => false, (carol, :trusted) => false
        ),
    ) == BitVector([true, false, false])
    @test concept_extension(
        atom(:trusted), g; concept_valuation=Dict(:trusted => Set([alice]))
    ) == BitVector([true, false, false])
    @test concept_extension(
        atom(:trusted),
        g;
        concept_valuation=Dict(
            alice => Dict(:trusted => true),
            bob => Dict(:trusted => false),
            carol => Dict(:trusted => false),
        ),
    ) == BitVector([true, false, false])
    @test_throws KeyError concept_extension(
        atom(:trusted), g; concept_valuation=Dict(:other => Set([alice]))
    )
end

@testset "graph endpoints require full entity identity" begin
    canonical = KGEntity(:same; kind=:person, metadata=(source=:canonical,))
    foreign = KGEntity(:same; kind=:person, metadata=(source=:foreign,))
    other = KGEntity(:other; kind=:person, metadata=(source=:canonical,))
    relation = KGRelation(:knows; domain=:person, range=:person)
    @test_throws ArgumentError KnowledgeGraph(
        [canonical, other], [relation], [KGEdge(foreign, relation, other)]
    )
end

@testset "AletheiaGraphs quality" begin
    Aqua.test_all(AletheiaGraphs)
    if pkgversion(JET) < v"0.11"
        JET.test_package(AletheiaGraphs; target_defined_modules=true)
    else
        JET.test_package(
            AletheiaGraphs; target_modules=(AletheiaGraphs,), analyze_from_definitions=true
        )
    end
end

@testset "graph path traces require graph context" begin
    path = paths(g, :alice; target=:bob, max_hops=1)[1]
    trace = ExecutionTrace([TraceStep(:graph_path, (path=path,), :alice, path.entities)],
        Provenance(; hashes=(graph=stable_hash(g),)), path.entities,
        stable_hash(:alice), stable_hash(path.entities), :global; artifact=g)
    @test replay(trace, :alice).valid
    forged = TraceStep(:graph_path, (path=KGPath((alice, bob), (visits,), (p2,)),), :alice, (alice, bob))
    forged_trace = ExecutionTrace([forged], trace.provenance, (alice, bob), stable_hash(:alice), stable_hash((alice, bob)), :global; artifact=g)
    @test !replay(forged_trace, :alice).valid
    @test !replay(ExecutionTrace([TraceStep(:graph_path, (path=path,), :alice, path.entities)], Provenance(), path.entities, stable_hash(:alice), stable_hash(path.entities), :global), :alice).valid
end

@testset "graph replay authenticates graph context" begin
    local_graph = KnowledgeGraph(
        [alice, bob, carol], [knows, visits],
        [KGEdge(alice, knows, bob, p1), KGEdge(bob, visits, carol, p2)],
    )
    path = paths(local_graph, :alice; target=:bob, max_hops=1)[1]
    trace = ExecutionTrace([TraceStep(:graph_path, (path=path,), :alice, path.entities)],
        Provenance(; hashes=(graph=stable_hash(local_graph),)), path.entities,
        stable_hash(:alice), stable_hash(path.entities), :global; artifact=local_graph)
    @test replay(trace, :alice).valid
    tampered_graph = KnowledgeGraph(
        [alice, bob, carol], [knows, visits],
        [KGEdge(alice, visits, carol, p2)],
    )
    tampered_trace = ExecutionTrace(
        trace.steps,
        trace.provenance,
        trace.reported_result,
        trace.input_hash,
        trace.output_hash,
        trace.scope;
        artifact=tampered_graph,
    )
    @test !replay(tampered_trace, :alice).valid
end

@testset "graph metadata is owned" begin
    metadata = Dict(:source => "before")
    entity = KGEntity(:owned; metadata=metadata)
    metadata[:source] = "after"
    @test entity.metadata[:source] == "before"
    positional_metadata = Dict(:source => "before")
    positional_entity = KGEntity(:positional, :entity, positional_metadata)
    positional_metadata[:source] = "after"
    @test positional_entity.metadata[:source] == "before"
    relation_metadata = Dict(:source => "before")
    relation = KGRelation(:owned; metadata=relation_metadata)
    relation_metadata[:source] = "after"
    @test relation.metadata[:source] == "before"
    positional_relation_metadata = Dict(:source => "before")
    positional_relation = KGRelation(:positional, :Any, :Any, positional_relation_metadata)
    positional_relation_metadata[:source] = "after"
    @test positional_relation.metadata[:source] == "before"
end

@testset "default concept metadata representations are symmetric" begin
    tagged = KGEntity(:tagged; metadata=(concepts=Set([:trusted]),))
    graph = KnowledgeGraph([tagged], KGRelation[], KGEdge[])
    @test concept_extension(atom(:trusted), graph) == [true]
end
