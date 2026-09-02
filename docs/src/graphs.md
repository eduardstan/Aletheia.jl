# Knowledge graphs as relational structures

A knowledge graph is a collection of typed entities and directed, typed edges. `[`AletheiaGraphs`](graphs.md)` keeps the source record for every edge, then maps entities to worlds and relation schemas to named relations in an Aletheia frame. This makes graph traversal and modal evaluation two views of the same finite relational structure, following the standard relational-frame reading of modal logic [blackburn2001](@cite).

```@example graphs
using Aletheia, AletheiaGraphs
people = [KGEntity(:alice; kind=:person), KGEntity(:bob; kind=:person)]
knows = KGRelation(:knows; domain=:person, range=:person)
graph = KnowledgeGraph(people, [knows], [KGEdge(people[1], knows, people[2], KGProvenance(:directory; locator="row-1"))])
length(paths(graph, :alice; max_hops=1))
```

The path record contains entities, relation schemas, and edge provenance. `path_valid` checks replay against the graph snapshot. It does not turn path presence into a proof of ontology entailment. Provenance identifies the source; it is a separate field from validity. A numeric or neural confidence, when supplied by an application, remains a score and never a proof.

## A fuzzy-KG reading

The bridge reuses Aletheia's existing `ValuationCallback`. A concept can therefore be crisp or many-valued without adding graph-specific semantics. For example, a classifier can provide degrees of membership while modal operators still use the selected algebra's operations.

```@example graphs
using AletheiaCore
concept = atom(:trusted)
values = concept_extension(concept, graph; algebra=GodelAlgebra(3),
    concept_valuation=(name, entity) -> entity.id == :alice ? 1.0 : 0.5)
values
```

`KnowledgeGraph` is a graph/path adapter, not a description-logic implementation. ALC, OWL entailment, and subsumption require a separately declared and verified profile; no such API is provided here.
