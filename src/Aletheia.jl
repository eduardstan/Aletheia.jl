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
include("algebras.jl")
include("relations.jl")
include("dimensional.jl")
include("frameclasses.jl")
include("evaluation.jl")
include("dataset.jl")
include("firstorder.jl")
include("ilp.jl")
include("normalforms.jl")
include("bisimulation.jl")
include("prover.jl")
include("compatibility.jl")

export Signature, Formula, FormulaPool, Atom, Branch, DAGNode
export atom, branch, children, nchildren, value, operator, head, pool, id
export isatom, isbranch, dag, subterms, nsubterms, signature, connectives
export arity, dual, hasconnective, hasdual, precedence, associativity, commutative
export iscommutative, modality, ismodality, ismodal, isunary, isdiamond, isbox
export isgrounded, notation, relation, syntaxstring, AbstractRelationalConnective
export Negation, Conjunction, Disjunction, Implication, Diamond, Box
export NEGATION, CONJUNCTION, DISJUNCTION, IMPLICATION
export NOT, AND, OR, IMPLIES, ¬, ∧, ∨, →
export TruthAlgebra, BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export FiniteTruth, FiniteFLewAlgebra, BooleanFLewAlgebra
export G3, G4, G5, G6, Ł3, Ł4, L3, L4, H4, H6, H6_1, H6_2, H6_3, H9
export RelationFamily, IntervalRelation, PointRelation, RCCRelation, RectangleRelation
export relation_holds, relation_successors, inverse, converse, rectangle_relation
export globalrel, identityrel, GlobalRelation, GlobalRel, IdentityRelation, IdentityRel
export AtWorldRelation, ToCenterRelation, ToCenterRel, tocenterrel
export centralworld, emptyworld
export isgrounding
export Interval, Rectangle, Interval2D, Point, interval_frame, rectangle_frame, point_frame
export FullDimensionalFrame, Full1DFrame, Full2DFrame, Full1DPointFrame, Full2DPointFrame
export BEFORE, MEETS, OVERLAPS, STARTS, DURING, FINISHES, EQUALS
export AFTER, MET_BY, OVERLAPPED_BY, STARTED_BY, CONTAINS, FINISHED_BY
export before, meets, overlaps, starts, during, finishes, equals, after, met_by
export overlapped_by, started_by, contains, finished_by, ALLEN_RELATIONS, IARelations, IntervalRelations
export IA_BEFORE, IA_MEETS, IA_OVERLAPS, IA_STARTS, IA_DURING, IA_FINISHES, IA_EQUALS
export IA_AFTER, IA_MET_BY, IA_OVERLAPPED_BY, IA_STARTED_BY, IA_CONTAINS, IA_FINISHED_BY
export IA_A, IA_L, IA_B, IA_E, IA_D, IA_O, IA_Ai, IA_Li, IA_Bi, IA_Ei, IA_Di, IA_Oi
export IA_AorO, IA_DorBorE, IA_AiorOi, IA_DiorBiorEi, IA_I
export IA7Relations, IA3Relations, IA7Relation, IA3Relation, IA72IARelations, IA32IARelations
export IDENTITY, ID, MINIMUM, MAXIMUM, MIN, MAX, SUCCESSOR, PREDECESSOR, GREATER, LESSER
export POINT_RELATIONS, PointRelations
export DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ, RCC8_RELATIONS, RCC8Relations, RCC8_BASICS, Topo_DC, Topo_EC, Topo_PO, Topo_TPP, Topo_TPPi, Topo_NTPP, Topo_NTPPi
export Topo_DR, Topo_PP, Topo_PPi, RCC5_RELATIONS, RCC5Relations, RCC5Relation
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
export lattice_meet, latticemeet, latticejoin, lattice_join, lmeet, join_table, lattice_meet_table, monoid_table, implication_table
export product, tnorm, monoid, monoid_product, monoid_operation, residuum
export precedeq, precedes, succeedeq, succeedes, maximalmembers, minimalmembers
export AbstractFrame, AbstractUniModalFrame, AbstractMultiModalFrame
export AbstractWorld, AbstractWorlds, AnyWorld
export Frame, worlds, relations, world_index, hasworldindex, world_position, accessible, accessibles
export collateworlds
export check, extension, Extension, describe
export Valuation, ValuationCallback, atom_values, Model, frame, algebra, valuation, interpret
export AbstractModelFamily, ModelFamily, instance_count, eachinstance, instance_model
export instance_frame, uniform_frame, isuniform

export FirstOrderTerm, FirstOrderFormula, FOTerm, FOFormula
export Variable, Constant, FunctionTerm, CompoundTerm, FOFunction, Predicate, Equality, FONegation, FOConjunction, FODisjunction, FOImplication
export Exists, Forall, FOVariable, FOConstant, FOAtom, FOPredicate, FOEquality
export FONot, FOAnd, FOOr, FOImplies, FOExists, FOForall
export FirstOrderInterpretation, FOInterpretation, FOModel, evaluate, standard_translation, standardtranslate, translate
export first_order_interpretation, firstorder
export Literal, literal, positive_literal, negative_literal, atoms, literals, clauses, Clause, HornClause, ClauseSet, BackgroundKnowledge
export Substitution, substitute, subsumes, theta_subsumes, more_general, more_specific, equivalent_under_subsumption, ishorn
export downward_refinements, upward_refinements, downward_refinement, upward_refinement, specializations, generalizations
export ILPExample, EntailmentExample, InterpretationExample, ProofExample
export learning_from_entailment, learning_from_interpretations, learning_from_proofs, interpretation_example, model_example
export iscnf, isdnf, to_cnf, to_dnf, cnf, dnf, conjunctive_normal_form, disjunctive_normal_form
export bisimilar, BisimulationClass, BisimulationContraction, QuotientModel, bisimulation_contraction, contraction_world
export model, classes, world_map, contract, contraction
export AbstractProver, ProverResult, PropositionalProver, TruthTableProver, prove, prove_valid
export issatisfiable, isvalid, entails

# Public bindings not attached to a more specific declaration above.

@doc "Allen interval relation: the first interval begins after the second ends." AFTER
@doc "Tuple containing the thirteen Allen interval relation values." ALLEN_RELATIONS
@doc "Alias for [`CONJUNCTION`](@ref)." AND
@doc "Relation family targeting one designated world." AtWorldRelation
@doc "Allen interval relation: the first interval ends before the second begins." BEFORE
@doc "The singleton Boolean algebra value; its carrier is `Bool` and it supplies Boolean truth operations." BOOLEAN
@doc "Alias for [`ClauseSet`](@ref)." BackgroundKnowledge
@doc "A model quotient produced by identifying bisimilar worlds." BisimulationContraction
@doc "The finite two-element FLew algebra, with one-based `UInt8` carrier values and derived lattice, monoid, and implication tables." BooleanFLewAlgebra
@doc "Compass relation for the closest east point." CL_E
@doc "Compass relation for the closest north point." CL_N
@doc "Compass relation for the closest north-east point." CL_NE
@doc "Compass relation for the closest north-west point." CL_NW
@doc "Compass relation for the closest south point." CL_S
@doc "Compass relation for the closest south-east point." CL_SE
@doc "Compass relation for the closest south-west point." CL_SW
@doc "Compass relation for the closest west point." CL_W
@doc "Canonical connective value for conjunction." CONJUNCTION
@doc "Allen interval relation: the first interval strictly contains the second." CONTAINS
@doc "Alias for [`FunctionTerm`](@ref)." CompoundTerm
@doc "Stateless syntax marker type for conjunction." Conjunction
@doc "First-order constant carrying a value symbol." Constant
@doc "RCC8 relation: the regions are disconnected." DC
@doc "Alias for the RCC8 disconnected relation [`DC`](@ref)." DISCONNECTED
@doc "Canonical connective value for disjunction." DISJUNCTION
@doc "Allen interval relation: the first interval is strictly inside the second." DURING
@doc "Stateless syntax marker type for disjunction." Disjunction
@doc "RCC8 relation: the regions are externally connected but do not overlap interiors." EC
@doc "Allen interval relation: both intervals have the same endpoints." EQUALS
@doc "Alias for [`EC`](@ref)." EXTERNALLY_CONNECTED
@doc "First-order formula asserting equality of two terms." Equality
@doc "First-order existential quantifier formula." Exists
@doc "Allen interval relation: both intervals end together, and the first starts earlier." FINISHED_BY
@doc "Allen interval relation: both intervals end together, and the first starts later." FINISHES
@doc "Alias for [`FOConjunction`](@ref)." FOAnd
@doc "Alias for [`Predicate`](@ref)." FOAtom
@doc "First-order conjunction formula." FOConjunction
@doc "Alias for [`Constant`](@ref)." FOConstant
@doc "First-order disjunction formula." FODisjunction
@doc "Alias for [`Equality`](@ref)." FOEquality
@doc "Alias for [`Exists`](@ref)." FOExists
@doc "Alias for [`Forall`](@ref)." FOForall
@doc "Alias for [`FirstOrderFormula`](@ref)." FOFormula
@doc "Alias for [`FunctionTerm`](@ref)." FOFunction
@doc "First-order implication formula." FOImplication
@doc "Alias for [`FOImplication`](@ref)." FOImplies
@doc "Alias for [`FirstOrderInterpretation`](@ref)." FOInterpretation
@doc "Alias for [`FirstOrderInterpretation`](@ref)." FOModel
@doc "First-order negation formula." FONegation
@doc "Alias for [`FONegation`](@ref)." FONot
@doc "Alias for [`FODisjunction`](@ref)." FOOr
@doc "Alias for [`Predicate`](@ref)." FOPredicate
@doc "Alias for [`FirstOrderTerm`](@ref)." FOTerm
@doc "Alias for [`Variable`](@ref)." FOVariable
@doc "Abstract supertype for first-order atomic and compound formulas." FirstOrderFormula
@doc "Abstract supertype for first-order variables, constants, and function terms." FirstOrderTerm
@doc "First-order universal quantifier formula." Forall
@doc "Convenience constructor for a one-dimensional interval frame." Full1DFrame
@doc "Convenience constructor for a one-dimensional point frame." Full1DPointFrame
@doc "Convenience constructor for a two-dimensional rectangle frame." Full2DFrame
@doc "Convenience constructor for a two-dimensional point frame." Full2DPointFrame
@doc "Named three-element Gödel FLew algebra." G3
@doc "Named four-element Gödel FLew algebra." G4
@doc "Named five-element Gödel FLew algebra." G5
@doc "Named six-element Gödel FLew algebra." G6
@doc "Point relation selecting greater points." GREATER
@doc "Alias for [`GlobalRelation`](@ref)." GlobalRel
@doc "Relation family that relates every source endpoint to every target endpoint." GlobalRelation
@doc "Alias for [`GodelAlgebra`](@ref)." GodelChain
@doc "Unicode alias for [`GodelAlgebra`](@ref)." GödelAlgebra
@doc "Named four-element finite FLew algebra." H4
@doc "Named six-element finite FLew algebra." H6
@doc "Named six-element finite FLew algebra H6.1." H6_1
@doc "Named six-element finite FLew algebra H6.2." H6_2
@doc "Named six-element finite FLew algebra H6.3." H6_3
@doc "Named nine-element finite FLew algebra." H9
@doc "Return the constituent IA relations represented by an IA3 value." IA32IARelations
@doc "Union type of IA3 relation values." IA3Relation
@doc "Tuple of the three IA3 interval relation values." IA3Relations
@doc "Return the constituent IA relations represented by an IA7 value." IA72IARelations
@doc "Union type of IA7 relation values." IA7Relation
@doc "Tuple of the six IA7 interval relation values." IA7Relations
@doc "Alias for [`ALLEN_RELATIONS`](@ref)." IARelations
@doc "IA shorthand relation for Allen `MEETS`." IA_A
@doc "Allen interval relation alias for [`AFTER`](@ref)." IA_AFTER
@doc "IA shorthand relation for the inverse of `MEETS` (`MET_BY`)." IA_Ai
@doc "IA7 inverse relation combining `MET_BY` and `OVERLAPPED_BY`." IA_AiorOi
@doc "IA7 relation combining `MEETS` and `OVERLAPS`." IA_AorO
@doc "IA shorthand relation for Allen `STARTED_BY`." IA_B
@doc "Allen interval relation alias for [`BEFORE`](@ref)." IA_BEFORE
@doc "IA shorthand relation for Allen `STARTS`." IA_Bi
@doc "Allen interval relation alias for [`CONTAINS`](@ref)." IA_CONTAINS
@doc "IA shorthand relation for Allen `CONTAINS`." IA_D
@doc "Allen interval relation alias for [`DURING`](@ref)." IA_DURING
@doc "IA shorthand relation for Allen `DURING`." IA_Di
@doc "IA7 inverse relation combining `DURING`, `STARTS`, and `FINISHES`." IA_DiorBiorEi
@doc "IA7 relation combining `CONTAINS`, `STARTED_BY`, and `FINISHED_BY`." IA_DorBorE
@doc "IA shorthand relation for Allen `FINISHED_BY`." IA_E
@doc "Allen interval relation alias for [`EQUALS`](@ref)." IA_EQUALS
@doc "IA shorthand relation for Allen `FINISHES`." IA_Ei
@doc "Allen interval relation alias for [`FINISHED_BY`](@ref)." IA_FINISHED_BY
@doc "Allen interval relation alias for [`FINISHES`](@ref)." IA_FINISHES
@doc "IA3 relation combining the six non-inverse interior Allen relations." IA_I
@doc "IA shorthand relation for Allen `BEFORE`." IA_L
@doc "IA shorthand relation for Allen `AFTER`." IA_Li
@doc "Allen interval relation alias for [`MEETS`](@ref)." IA_MEETS
@doc "Allen interval relation alias for [`MET_BY`](@ref)." IA_MET_BY
@doc "IA shorthand relation for Allen `OVERLAPS`." IA_O
@doc "Allen interval relation alias for [`OVERLAPPED_BY`](@ref)." IA_OVERLAPPED_BY
@doc "Allen interval relation alias for [`OVERLAPS`](@ref)." IA_OVERLAPS
@doc "IA shorthand relation for Allen `OVERLAPPED_BY`." IA_Oi
@doc "Allen interval relation alias for [`STARTED_BY`](@ref)." IA_STARTED_BY
@doc "Allen interval relation alias for [`STARTS`](@ref)." IA_STARTS
@doc "Alias for [`IDENTITY`](@ref)." ID
@doc "Identity relation value; it relates each world only to itself." IDENTITY
@doc "Abstract supertype for learning-setting examples." ILPExample
@doc "Canonical connective value for implication." IMPLICATION
@doc "Alias for [`IMPLICATION`](@ref)." IMPLIES
@doc "Alias for [`IdentityRelation`](@ref)." IdentityRel
@doc "Relation family whose relation holds exactly when its two endpoints are equal." IdentityRelation
@doc "Stateless syntax marker type for implication." Implication
@doc "Alias for [`Rectangle`](@ref)." Interval2D
@doc "Alias for [`ALLEN_RELATIONS`](@ref)." IntervalRelations
@doc "Frame class with no additional constraints." K
@doc "ASCII alias for [`Ł3`](@ref)." L3
@doc "ASCII alias for [`Ł4`](@ref)." L4
@doc "Point relation selecting lesser points." LESSER
@doc "Alias for [`LukasiewiczAlgebra`](@ref)." LukasiewiczChain
@doc "Alias for [`MAXIMUM`](@ref)." MAX
@doc "Point relation selecting the last point in the ordered domain." MAXIMUM
@doc "Allen interval relation: the first interval ends exactly when the second begins." MEETS
@doc "Allen interval relation: the first begins exactly when the second ends." MET_BY
@doc "Alias for [`MINIMUM`](@ref)." MIN
@doc "Point relation selecting the first point in the ordered domain." MINIMUM
@doc "Canonical zero-ary value identifying the negation connective." NEGATION
@doc "Alias for [`NTPP`](@ref)." NON_TANGENTIAL_PROPER_PART
@doc "Alias for [`NTPPi`](@ref)." NON_TANGENTIAL_PROPER_PART_INVERSE
@doc "Alias for [`NEGATION`](@ref)." NOT
@doc "RCC8 relation: the first region is a non-tangential proper part of the second." NTPP
@doc "RCC8 inverse relation: the first region contains the second as a non-tangential proper part." NTPPi
@doc "Stateless syntax marker type for negation." Negation
@doc "Alias for [`DISJUNCTION`](@ref)." OR
@doc "Allen interval relation: the first starts within and ends after the second." OVERLAPPED_BY
@doc "Allen interval relation: the first starts before the second and ends within it." OVERLAPS
@doc "Alias for [`PO`](@ref)." PARTIALLY_OVERLAPPING
@doc "RCC8 relation: the regions partially overlap." PO
@doc "Tuple containing the eight compass point relation values." POINT2D_RELATIONS
@doc "Tuple containing the one-dimensional point relation values." POINT_RELATIONS
@doc "Point relation selecting immediate predecessors." PREDECESSOR
@doc "Alias for [`POINT2D_RELATIONS`](@ref)." Point2DRelations
@doc "Alias for [`POINT_RELATIONS`](@ref)." PointRelations
@doc "First-order atomic formula with a predicate name and terms." Predicate
@doc "Alias for [`BisimulationContraction`](@ref)." QuotientModel
@doc "Union type of RCC5 relation values." RCC5Relation
@doc "Alias for [`RCC5_RELATIONS`](@ref)." RCC5Relations
@doc "Tuple containing all RCC5 relation values." RCC5_RELATIONS
@doc "Alias for [`RCC8_RELATIONS`](@ref)." RCC8Relations
@doc "Tuple containing the seven non-equality RCC8 values." RCC8_BASICS
@doc "Tuple containing all eight RCC8 relation values." RCC8_RELATIONS
@doc "RCC8 relation: the regions are equal." RCC_EQ
@doc "Frame-class value requiring reflexivity." REFLEXIVE
@doc "Alias for [`REFLEXIVE`](@ref)." REFLEXIVITY
@doc "Relation family combining two axis relations for rectangles." RectangleRelation
@doc "Reflexive and transitive frame class." S4
@doc "Reflexive, transitive, and symmetric frame class." S5
@doc "Frame-class value requiring seriality." SERIAL
@doc "Alias for [`SERIAL`](@ref)." SERIALITY
@doc "Allen interval relation: both intervals start together, and the first ends later." STARTED_BY
@doc "Allen interval relation: both intervals start together, and the first ends earlier." STARTS
@doc "Point relation selecting immediate successors." SUCCESSOR
@doc "Frame-class value requiring symmetry." SYMMETRIC
@doc "Alias for [`SYMMETRIC`](@ref)." SYMMETRY
@doc "Reflexive frame class." T
@doc "Alias for [`TPP`](@ref)." TANGENTIAL_PROPER_PART
@doc "Alias for [`TPPi`](@ref)." TANGENTIAL_PROPER_PART_INVERSE
@doc "RCC8 relation: the first region is a tangential proper part of the second." TPP
@doc "RCC8 inverse relation: the first region contains the second as a tangential proper part." TPPi
@doc "Frame-class value requiring transitivity." TRANSITIVE
@doc "Alias for [`TRANSITIVE`](@ref)." TRANSITIVITY
@doc "Alias for [`ToCenterRelation`](@ref)." ToCenterRel
@doc "Relation family targeting the frame center." ToCenterRelation
@doc "Topological alias for [`DC`](@ref)." Topo_DC
@doc "RCC5 relation: the regions are disconnected (DC or EC)." Topo_DR
@doc "Topological alias for [`EC`](@ref)." Topo_EC
@doc "Topological relation alias for [`NTPPi`](@ref)." Topo_NTPP
@doc "Topological relation alias for [`NTPP`](@ref)." Topo_NTPPi
@doc "Topological alias for [`PO`](@ref)." Topo_PO
@doc "RCC5 relation: the first region is a proper part of the second." Topo_PP
@doc "RCC5 inverse relation: the first region contains the second as a proper part." Topo_PPi
@doc "Topological relation alias for [`TPPi`](@ref)." Topo_TPP
@doc "Topological relation alias for [`TPP`](@ref)." Topo_TPPi
@doc "Alias for [`PropositionalProver`](@ref)." TruthTableProver
@doc "First-order variable identified by a symbol." Variable
@doc "Lowercase alias for [`AFTER`](@ref)." after
@doc "Construct the characteristic axiom formula for a frame class." axiom
@doc "Construct the characteristic axiom formulas for a frame class." axioms
@doc "Lowercase alias for [`BEFORE`](@ref)." before
@doc "Return the central world of a frame." centralworld
@doc "Check whether a frame satisfies a frame class." checkclass
@doc "Return the bisimulation classes in a contraction." classes
@doc "Return the clauses contained in clause-set knowledge." clauses
@doc "Alias for [`to_cnf`](@ref)." cnf
@doc "Alias for [`to_cnf`](@ref)." conjunctive_normal_form
@doc "Lowercase alias for [`CONTAINS`](@ref)." contains
@doc "Alias for [`bisimulation_contraction`](@ref)." contract
@doc "Alias for [`bisimulation_contraction`](@ref)." contraction
@doc "Return the quotient world corresponding to a world." contraction_world
@doc "Alias for [`inverse`](@ref)." converse
@doc "Alias for [`to_dnf`](@ref)." disjunctive_normal_form
@doc "Alias for [`to_dnf`](@ref)." dnf
@doc "Alias for [`downward_refinements`](@ref)." downward_refinement
@doc "Lowercase alias for [`DURING`](@ref)." during
@doc "Return the empty world of a frame." emptyworld
@doc "Lowercase alias for [`EQUALS`](@ref)." equals
@doc "Test whether two clauses subsume each other." equivalent_under_subsumption
@doc "Lowercase alias for [`FINISHED_BY`](@ref)." finished_by
@doc "Lowercase alias for [`FINISHES`](@ref)." finishes
@doc "Alias for [`first_order_interpretation`](@ref)." firstorder
@doc "Alias for [`upward_refinements`](@ref)." generalizations
@doc "Singleton global relation value, equivalent to [`GlobalRelation`](@ref)." globalrel
@doc "Singleton identity relation value, equivalent to [`IDENTITY`](@ref)." identityrel
@doc "Return the residual implication table of a finite FLew algebra." implication_table
@doc "Test whether a connective is a box modality." isbox
@doc "Test whether a connective is a diamond modality." isdiamond
@doc "Test whether a connective is modal." ismodal
@doc "Test whether a connective has arity one." isunary
@doc "Test validity using a propositional prover." isvalid
@doc "Return the lattice join table of a finite FLew algebra." join_table
@doc "Compute lattice join in an algebra." lattice_join
@doc "Return the lattice meet table of a finite FLew algebra." lattice_meet_table
@doc "Alias for [`lattice_join`](@ref)." latticejoin
@doc "Compute lattice meet in an algebra." latticemeet
@doc "Construct an ILP literal from a predicate or equality." literal
@doc "Return the literals contained in a clause or Horn clause." literals
@doc "Alias for [`latticemeet`](@ref)." lmeet
@doc "Lowercase alias for [`MEETS`](@ref)." meets
@doc "Lowercase alias for [`MET_BY`](@ref)." met_by
@doc "Return the model represented by a bisimulation contraction." model
@doc "Build an interpretation-learning example from a model." model_example
@doc "Compute the monoid operation in an algebra." monoid
@doc "Compute the monoid operation in an algebra." monoid_operation
@doc "Alias for the monoid product operation." monoid_product
@doc "Return the monoid operation table of a finite FLew algebra." monoid_table
@doc "Return whether the first clause is more specific under θ-subsumption." more_specific
@doc "Construct or test a negative ILP literal." negative_literal
@doc "Lowercase alias for [`OVERLAPPED_BY`](@ref)." overlapped_by
@doc "Lowercase alias for [`OVERLAPS`](@ref)." overlaps
@doc "Construct or test a positive ILP literal." positive_literal
@doc "Test strict order precedence of finite truth values." precedes
@doc "Construct a relation on rectangles from two axis relations." rectangle_relation
@doc "Test whether a frame relation is reflexive." reflexive
@doc "Alias for the residual implication operation." residuum
@doc "Test whether a frame relation is serial." serial
@doc "Alias for [`downward_refinements`](@ref)." specializations
@doc "Alias for [`standard_translation`](@ref)." standardtranslate
@doc "Lowercase alias for [`STARTED_BY`](@ref)." started_by
@doc "Lowercase alias for [`STARTS`](@ref)." starts
@doc "Test non-strict successor order of finite truth values." succeedeq
@doc "Test strict successor order of finite truth values." succeedes
@doc "Test whether a frame relation is symmetric." symmetric
@doc "Alias for [`subsumes`](@ref)." theta_subsumes
@doc "Alias for the monoid product operation." tnorm
@doc "Alias for [`ToCenterRelation`](@ref)." tocenterrel
@doc "Test whether a frame relation is transitive." transitive
@doc "Alias for [`standard_translation`](@ref)." translate
@doc "Return the common frame when every model-family instance shares one." uniform_frame
@doc "Alias for [`upward_refinements`](@ref)." upward_refinement
@doc "Alias for [`checkclass`](@ref)." validclass
@doc "Return the original-world to quotient-world map." world_map
@doc "Mathematical alias for [`NEGATION`](@ref)." (¬)
@doc "Named three-element Łukasiewicz FLew algebra." Ł3
@doc "Named four-element Łukasiewicz FLew algebra." Ł4
@doc "Unicode alias for [`LukasiewiczAlgebra`](@ref)." ŁukasiewiczAlgebra
@doc "Mathematical alias for [`IMPLICATION`](@ref)." (→)
@doc "Mathematical alias for [`CONJUNCTION`](@ref)." (∧)
@doc "Mathematical alias for [`DISJUNCTION`](@ref)." (∨)

end
