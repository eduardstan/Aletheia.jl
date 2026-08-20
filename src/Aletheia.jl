"""
    Aletheia

Aletheia provides syntax-first foundations for logical languages.  It contains
similarity types, immutable hash-consed formulas, connective traits, a
precedence-aware parser/printer, truth algebras, relational frames, models,
and atom interpretation, plus type-stable compound-formula evaluation.
"""
module Aletheia

include("syntax.jl")
include("parse.jl")
include("semantics.jl")
include("relations.jl")
include("dimensional.jl")
include("frameclasses.jl")
include("evaluation.jl")

export Signature, Formula, FormulaPool, Atom, Branch, DAGNode
export atom, branch, children, nchildren, value, operator, head, pool, id
export isatom, isbranch, dag, subterms, nsubterms, signature, connectives
export arity, dual, hasconnective, hasdual, precedence, associativity, commutative
export iscommutative, modality, ismodality, notation, relation, syntaxstring
export Negation, Conjunction, Disjunction, Implication, Diamond, Box
export NEGATION, CONJUNCTION, DISJUNCTION, IMPLICATION
export NOT, AND, OR, IMPLIES, ¬, ∧, ∨, →
export TruthAlgebra, BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export RelationFamily, IntervalRelation, PointRelation, RCCRelation, RectangleRelation
export relation_holds, inverse, converse, rectangle_relation
export Interval, Rectangle, Interval2D, Point, interval_frame, rectangle_frame, point_frame
export FullDimensionalFrame, Full1DFrame, Full2DFrame, Full1DPointFrame, Full2DPointFrame
export BEFORE, MEETS, OVERLAPS, STARTS, DURING, FINISHES, EQUALS
export AFTER, MET_BY, OVERLAPPED_BY, STARTED_BY, CONTAINS, FINISHED_BY
export before, meets, overlaps, starts, during, finishes, equals, after, met_by
export overlapped_by, started_by, contains, finished_by, ALLEN_RELATIONS, IARelations, IntervalRelations
export IA_BEFORE, IA_MEETS, IA_OVERLAPS, IA_STARTS, IA_DURING, IA_FINISHES, IA_EQUALS
export IA_AFTER, IA_MET_BY, IA_OVERLAPPED_BY, IA_STARTED_BY, IA_CONTAINS, IA_FINISHED_BY
export IA_A, IA_L, IA_B, IA_E, IA_D, IA_O, IA_Ai, IA_Li, IA_Bi, IA_Ei, IA_Di, IA_Oi
export IDENTITY, ID, MINIMUM, MAXIMUM, MIN, MAX, SUCCESSOR, PREDECESSOR, GREATER, LESSER
export POINT_RELATIONS, PointRelations
export DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ, RCC8_RELATIONS, RCC8Relations, RCC8_BASICS, Topo_DC, Topo_EC, Topo_PO, Topo_TPP, Topo_TPPi, Topo_NTPP, Topo_NTPPi
export DISCONNECTED, EXTERNALLY_CONNECTED, PARTIALLY_OVERLAPPING
export TANGENTIAL_PROPER_PART, TANGENTIAL_PROPER_PART_INVERSE
export NON_TANGENTIAL_PROPER_PART, NON_TANGENTIAL_PROPER_PART_INVERSE
export FrameClass, K, T, S4, S5, REFLEXIVE, TRANSITIVE, SYMMETRIC, SERIAL
export REFLEXIVITY, TRANSITIVITY, SYMMETRY, SERIALITY
export isreflexive, istransitive, issymmetric, isserial, reflexive, transitive, symmetric, serial
export satisfies, checkclass, validclass, axioms, axiom, validates
export GodelChain, LukasiewiczChain, GödelAlgebra, ŁukasiewiczAlgebra
export BOOLEAN, truth_type, truthtype, carrier, top, bottom, bot, meet, join
export domain
export implication, negation, implies, negate, levels, isfinitechain
export Frame, worlds, relations, world_index, hasworldindex, world_position, accessible
export check, extension
export Valuation, Model, frame, algebra, valuation, interpret

end
