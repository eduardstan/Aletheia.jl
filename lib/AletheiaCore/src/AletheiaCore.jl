"""Dependency-free syntax and semantic foundations for Aletheia."""
module AletheiaCore

# Every public boundary uses this one defensive-copy mechanism. `deepcopy`
# preserves nested ownership; callable values retain their executable identity.
_boundary_copy(value) = value isa Function ? value : deepcopy(value)

include("syntax.jl")
include("parse.jl")
include("display.jl")
include("semantics.jl")
include("algebras.jl")
include("relations.jl")
include("dimensional.jl")
include("frameclasses.jl")
include("evaluation.jl")
include("firstorder.jl")
include("normalforms.jl")
include("bisimulation.jl")
include("prover.jl")

export Signature, Formula, FormulaPool, Atom, Branch, DEFAULT_SIGNATURE, DEFAULT_POOL, atom, branch, children, nchildren, value
export operator, head, pool, id, isatom, isbranch, dag, subterms, nsubterms, signature, connectives, arity
export dual, hasconnective, hasdual, precedence, associativity, iscommutative, ismodal, isunary, isdiamond, isbox, isgrounded, notation
export relation, syntaxstring, AbstractRelationalConnective, Negation, Conjunction, Fusion, Disjunction, Implication, Diamond, Box, NEGATION, CONJUNCTION
export FUSION, DISJUNCTION, IMPLICATION, ¬, ∧, ⊗, ∨, →, TruthAlgebra, BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export FiniteTruth, FiniteFLewAlgebra, BooleanFLewAlgebra, G3, G4, G5, G6, Ł3, Ł4, H4, H6, H6_1
export H6_2, H6_3, H9, RelationFamily, IntervalRelation, PointRelation, RCCRelation, RectangleRelation, relation_holds, relation_successors, inverse, converse
export rectangle_relation, globalrel, identityrel, GlobalRelation, IdentityRelation, AtWorldRelation, ToCenterRelation, tocenterrel, centralworld, emptyworld, isgrounding, Interval
export Rectangle, Point, interval_frame, rectangle_frame, point_frame, BEFORE, MEETS, OVERLAPS, STARTS, DURING, FINISHES, EQUALS
export AFTER, MET_BY, OVERLAPPED_BY, STARTED_BY, CONTAINS, FINISHED_BY, ALLEN_RELATIONS, IDENTITY, MINIMUM, MAXIMUM, SUCCESSOR, PREDECESSOR
export GREATER, LESSER, POINT_RELATIONS, DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ, RCC8_RELATIONS
export RCC8_BASICS, DR, PP, PPi, RCC5_RELATIONS, RCC5Relation, FrameClass, K, T, S4, S5, REFLEXIVE
export TRANSITIVE, SYMMETRIC, SERIAL, isreflexive, istransitive, issymmetric, isserial, reflexive, transitive, symmetric, serial, satisfies
export axioms, axiom, validates, BOOLEAN, truth_type, carrier, top, bottom, bot, meet, join, fusion
export domain, implication, negation, levels, isfinitechain, precedeq, precedes, succeedeq, succeeds, maximalmembers, minimalmembers, AbstractFrame
export AbstractUniModalFrame, AbstractMultiModalFrame, AbstractWorld, AbstractWorlds, AnyWorld, Frame, worlds, relations, hasworldindex, world_position, accessible, collateworlds
export check, extension, describe, EvaluationCache, clear!, Valuation, Model, frame, algebra, valuation, interpret, FirstOrderTerm
export FirstOrderFormula, Variable, Constant, FunctionTerm, Predicate, Equality, FONegation, FOConjunction, FODisjunction, FOImplication, Exists, Forall
export FirstOrderInterpretation, evaluate, standard_translation, first_order_interpretation, iscnf, isdnf, to_cnf, to_dnf, bisimilar, BisimulationClass, BisimulationContraction, QuotientModel
export bisimulation_contraction, contraction_world, model, classes, world_map, AbstractProver, ProverResult, PropositionalProver, FiniteModelProver, BoundedFiniteProver, prove, prove_valid
export prove_entails, issatisfiable, isvalid, entails


@doc """Return whether the left finite truth value succeeds or equals the right value.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("succeedeq"))
true
```
""" succeedeq

@doc """Clear all extensions retained by an [`EvaluationCache`](@ref).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("clear!"))
true
```
""" clear!

@doc """The prefix negation connective (`¬`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ¬
¬
```
""" var"¬"

@doc """The conjunction connective (`∧`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ∧
∧
```
""" var"∧"

@doc """The fusion connective (`⊗`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ⊗
⊗
```
""" var"⊗"

@doc """The disjunction connective (`∨`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> ∨
∨
```
""" var"∨"

@doc """The implication connective (`→`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> →
→
```
""" var"→"
end
