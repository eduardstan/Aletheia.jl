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
include("display.jl")
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

export Signature, Formula, FormulaPool, Atom, Branch
export atom, branch, children, nchildren, value, operator, head, pool, id
export isatom, isbranch, dag, subterms, nsubterms, signature, connectives
export arity, dual, hasconnective, hasdual, precedence, associativity
export iscommutative, ismodal, isunary, isdiamond, isbox
export isgrounded, notation, relation, syntaxstring, AbstractRelationalConnective
export Negation, Conjunction, Fusion, Disjunction, Implication, Diamond, Box
export NEGATION, CONJUNCTION, FUSION, DISJUNCTION, IMPLICATION
export ¬, ∧, ⊗, ∨, →
export TruthAlgebra, BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export FiniteTruth, FiniteFLewAlgebra, BooleanFLewAlgebra
export G3, G4, G5, G6, Ł3, Ł4, H4, H6, H6_1, H6_2, H6_3, H9
export RelationFamily, IntervalRelation, PointRelation, RCCRelation, RectangleRelation
export relation_holds, relation_successors, inverse, converse, rectangle_relation
export globalrel, identityrel, GlobalRelation, IdentityRelation
export AtWorldRelation, ToCenterRelation, tocenterrel
export centralworld, emptyworld
export isgrounding
export Interval, Rectangle, Point, interval_frame, rectangle_frame, point_frame
export BEFORE, MEETS, OVERLAPS, STARTS, DURING, FINISHES, EQUALS
export AFTER, MET_BY, OVERLAPPED_BY, STARTED_BY, CONTAINS, FINISHED_BY
export ALLEN_RELATIONS
export IDENTITY, MINIMUM, MAXIMUM, SUCCESSOR, PREDECESSOR, GREATER, LESSER
export POINT_RELATIONS
export DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ, RCC8_RELATIONS, RCC8_BASICS
export DR, PP, PPi, RCC5_RELATIONS, RCC5Relation
export FrameClass, K, T, S4, S5, REFLEXIVE, TRANSITIVE, SYMMETRIC, SERIAL
export isreflexive, istransitive, issymmetric, isserial, reflexive, transitive, symmetric, serial
export satisfies, axioms, axiom, validates
export BOOLEAN, truth_type, carrier, top, bottom, bot, meet, join, fusion
export domain
export implication, negation, levels, isfinitechain
export precedeq, precedes, succeedeq, succeeds, maximalmembers, minimalmembers
export AbstractFrame, AbstractUniModalFrame, AbstractMultiModalFrame
export AbstractWorld, AbstractWorlds, AnyWorld
export Frame, worlds, relations, hasworldindex, world_position, accessible
export collateworlds
export check, extension, describe, EvaluationCache, clear!
export Valuation, Model, frame, algebra, valuation, interpret
export AbstractModelFamily, ModelFamily, instance_count, eachinstance, instance_model
export instance_frame, uniform_frame, isuniform

export FirstOrderTerm, FirstOrderFormula
export Variable, Constant, FunctionTerm, Predicate, Equality, FONegation, FOConjunction, FODisjunction, FOImplication
export Exists, Forall
export FirstOrderInterpretation, evaluate, standard_translation
export first_order_interpretation
export Literal, literal, positive_literal, negative_literal, atoms, literals, clauses, Clause, HornClause, ClauseSet
export Substitution, substitute, subsumes, more_general, more_specific, equivalent_under_subsumption, ishorn
export downward_refinements, upward_refinements, generalizations
export ILPExample, EntailmentExample, InterpretationExample, ProofExample
export learning_from_entailment, learning_from_interpretations, learning_from_proofs, interpretation_example, model_example
export iscnf, isdnf, to_cnf, to_dnf
export bisimilar, BisimulationClass, BisimulationContraction, QuotientModel, bisimulation_contraction, contraction_world
export model, classes, world_map
export AbstractProver, ProverResult, PropositionalProver, prove, prove_valid
export issatisfiable, isvalid, entails

# Public bindings not attached to a more specific declaration above.

@doc "Allen interval relation: the first interval begins after the second ends." AFTER
@doc "Tuple containing the thirteen Allen interval relation values." ALLEN_RELATIONS
@doc "Relation family targeting one designated world." AtWorldRelation
@doc "Allen interval relation: the first interval ends before the second begins." BEFORE
@doc "The singleton Boolean algebra value; its carrier is `Bool` and it supplies Boolean truth operations." BOOLEAN
@doc "A wrapper containing an original model and its bisimulation classes/world map." BisimulationContraction
@doc "The finite two-element FLew algebra, with one-based `UInt8` carrier values, explicit lattice and fusion tables, and a derived implication table." BooleanFLewAlgebra
@doc "Compass relation: `b` is strictly east of `a` on the same horizontal line (`_px(b) > _px(a)` and `_py(a) == _py(b)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_E
@doc "Compass relation: `b` is strictly north of `a` on the same vertical line (`_px(a) == _px(b)` and `_py(b) > _py(a)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_N
@doc "Compass relation: `b` is strictly north-east of `a` (`_px(b) > _px(a)` and `_py(b) > _py(a)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_NE
@doc "Compass relation: `b` is strictly north-west of `a` (`_px(b) < _px(a)` and `_py(b) > _py(a)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_NW
@doc "Compass relation: `b` is strictly south of `a` on the same vertical line (`_px(a) == _px(b)` and `_py(b) < _py(a)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_S
@doc "Compass relation: `b` is strictly south-east of `a` (`_px(b) > _px(a)` and `_py(b) < _py(a)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_SE
@doc "Compass relation: `b` is strictly south-west of `a` (`_px(b) < _px(a)` and `_py(b) < _py(a)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_SW
@doc "Compass relation: `b` is strictly west of `a` on the same horizontal line (`_px(b) < _px(a)` and `_py(a) == _py(b)`). The `Closest*` name is inherited for compatibility and does not mean nearest." CL_W
@doc "Canonical connective value for conjunction." CONJUNCTION
@doc "Canonical connective value for fusion." FUSION
@doc "Allen interval relation: the first interval strictly contains the second." CONTAINS
@doc "Stateless syntax marker type for conjunction." Conjunction
@doc "First-order constant carrying an arbitrary value." Constant
@doc "RCC8 relation: the regions are disconnected." DC
@doc "Canonical connective value for disjunction." DISJUNCTION
@doc "Allen interval relation: the first interval is strictly inside the second." DURING
@doc "Stateless syntax marker type for disjunction." Disjunction
@doc "RCC8 relation: the regions are externally connected but do not overlap interiors." EC
@doc "Allen interval relation: both intervals have the same endpoints." EQUALS
@doc "First-order formula asserting equality of two terms." Equality
@doc "First-order existential quantifier formula." Exists
@doc "Allen interval relation: both intervals end together, and the first starts earlier." FINISHED_BY
@doc "Allen interval relation: both intervals end together, and the first starts later." FINISHES
@doc "First-order conjunction formula." FOConjunction
@doc "First-order disjunction formula." FODisjunction
@doc "First-order implication formula." FOImplication
@doc "First-order negation formula." FONegation
@doc "Abstract supertype for first-order atomic and compound formulas." FirstOrderFormula
@doc "Abstract supertype for first-order variables, constants, and function terms." FirstOrderTerm
@doc "First-order universal quantifier formula." Forall
@doc "Named three-element Gödel FLew algebra." G3
@doc "Named four-element Gödel FLew algebra." G4
@doc "Named five-element Gödel FLew algebra." G5
@doc "Named six-element Gödel FLew algebra." G6
@doc "Point relation selecting greater points." GREATER
@doc "Relation family that relates every source endpoint to every target endpoint." GlobalRelation
@doc "Named four-element finite FLew algebra." H4
@doc "Named six-element finite FLew algebra." H6
@doc "Named six-element finite FLew algebra H6.1." H6_1
@doc "Named six-element finite FLew algebra H6.2." H6_2
@doc "Named six-element finite FLew algebra H6.3." H6_3
@doc "Named nine-element finite FLew algebra." H9
@doc "Tuple of the three interval relation values in the IA3 partition." IA3Relations
@doc "Tuple of the six interval relation values in the IA7 partition." IA7Relations
@doc "IA7 inverse relation combining `MET_BY` and `OVERLAPPED_BY`." IA_AiorOi
@doc "IA7 relation combining `MEETS` and `OVERLAPS`." IA_AorO
@doc "IA7 inverse relation combining `DURING`, `STARTS`, and `FINISHES`." IA_DiorBiorEi
@doc "IA7 relation combining `CONTAINS`, `STARTED_BY`, and `FINISHED_BY`." IA_DorBorE
@doc "IA3 relation combining the ten Allen relations other than `BEFORE`, `AFTER`, and `EQUALS`." IA_I
@doc "Identity relation value; it relates each world only to itself." IDENTITY
@doc "Abstract supertype for learning-setting examples." ILPExample
@doc "Canonical connective value for implication." IMPLICATION
@doc "Relation family whose relation holds exactly when its two endpoints are equal." IdentityRelation
@doc "Stateless syntax marker type for implication." Implication
@doc "Frame class with no additional constraints." K
@doc "Point relation selecting lesser points." LESSER
@doc """Point relation selecting the last point in the ordered domain.

Every source reaches the same point, so the converse relates that one point to
every world. That relation is not part of this vocabulary and [`inverse`](@ref)
therefore throws an `ArgumentError` for `MAXIMUM`.
""" MAXIMUM
@doc "Allen interval relation: the first interval ends exactly when the second begins." MEETS
@doc "Allen interval relation: the first begins exactly when the second ends." MET_BY
@doc """Point relation selecting the first point in the ordered domain.

Every source reaches the same point, so the converse relates that one point to
every world. That relation is not part of this vocabulary and [`inverse`](@ref)
therefore throws an `ArgumentError` for `MINIMUM`.
""" MINIMUM
@doc "Canonical connective value for negation." NEGATION
@doc "RCC8 relation: the first region is a non-tangential proper part of the second." NTPP
@doc "RCC8 inverse relation: the first region contains the second as a non-tangential proper part." NTPPi
@doc "Stateless syntax marker type for negation." Negation
@doc "Allen interval relation: the first starts within and ends after the second." OVERLAPPED_BY
@doc "Allen interval relation: the first starts before the second and ends within it." OVERLAPS
@doc "RCC8 relation: the regions partially overlap." PO
@doc "Tuple containing the eight compass point relation values." POINT2D_RELATIONS
@doc "Tuple containing the one-dimensional point relation values." POINT_RELATIONS
@doc "Point relation selecting immediate predecessors." PREDECESSOR
@doc "First-order atomic formula with a predicate name and terms." Predicate
@doc "Alias for [`BisimulationContraction`](@ref)." QuotientModel
@doc "Union type of RCC5 relation values." RCC5Relation
@doc "RCC5 relation: the first region is a proper part of the second." PP
@doc "RCC5 inverse relation: the first region contains the second as a proper part." PPi
@doc "RCC5 relation: the regions are disconnected (DC or EC)." DR
@doc "Tuple containing all RCC5 relation values." RCC5_RELATIONS
@doc "Tuple containing the seven non-equality RCC8 values." RCC8_BASICS
@doc "Tuple containing all eight RCC8 relation values." RCC8_RELATIONS
@doc "RCC8 relation: the regions are equal." RCC_EQ
@doc "Frame-class value requiring reflexivity." REFLEXIVE
@doc "Relation family combining two axis relations for rectangles." RectangleRelation
@doc "Reflexive and transitive frame class." S4
@doc "Reflexive, transitive, and symmetric frame class." S5
@doc "Frame-class value requiring seriality." SERIAL
@doc "Allen interval relation: both intervals start together, and the first ends later." STARTED_BY
@doc "Allen interval relation: both intervals start together, and the first ends earlier." STARTS
@doc "Point relation selecting immediate successors." SUCCESSOR
@doc "Frame-class value requiring symmetry." SYMMETRIC
@doc "Reflexive frame class." T
@doc "RCC8 relation: the first region is a tangential proper part of the second." TPP
@doc "RCC8 inverse relation: the first region contains the second as a tangential proper part." TPPi
@doc "Frame-class value requiring transitivity." TRANSITIVE
@doc "Relation family targeting the frame center." ToCenterRelation
@doc "First-order variable identified by a symbol." Variable
@doc "Construct the characteristic axiom formula for a frame class." axiom
@doc "Construct the characteristic axiom formulas for a frame class." axioms
@doc "Return the central world of a frame." centralworld
@doc "Check whether a frame satisfies a frame class." checkclass
@doc "Return the bisimulation classes in a contraction." classes
@doc "Return the clauses contained in clause-set knowledge." clauses
@doc "Alias for [`bisimulation_contraction`](@ref)." contract
@doc "Alias for [`bisimulation_contraction`](@ref)." contraction
@doc "Return the quotient world corresponding to a world." contraction_world
@doc "Alias for [`inverse`](@ref)." converse
@doc "Return the empty world of a frame." emptyworld
@doc "Test whether two clauses subsume each other." equivalent_under_subsumption
@doc "Alias for [`upward_refinements`](@ref)." generalizations
@doc "Singleton value of [`GlobalRelation`](@ref), relating every source to every target." globalrel
@doc "Singleton identity relation value, equivalent to [`IDENTITY`](@ref)." identityrel
@doc "Test whether a connective is a box modality." isbox
@doc "Test whether a connective is a diamond modality." isdiamond
@doc "Test whether a connective is modal." ismodal
@doc "Test whether a connective has arity one." isunary
@doc "Test validity using a propositional prover." isvalid
@doc "Return the lattice join table of a finite FLew algebra." join_table
@doc "Construct an ILP literal from a predicate or equality." literal
@doc "Return the literals contained in a clause or Horn clause." literals
@doc "Return the original model stored in a bisimulation contraction." model
@doc "Build an interpretation-learning example from a model." model_example
@doc "Return whether the first clause is more specific under θ-subsumption." more_specific
@doc "Construct or test a negative ILP literal." negative_literal
@doc "Construct or test a positive ILP literal." positive_literal
@doc "Test strict order precedence of finite truth values." precedes
@doc "Construct a relation on rectangles from two axis relations." rectangle_relation
@doc "Test whether a frame relation is reflexive." reflexive
@doc "Test whether a frame relation is serial." serial
@doc "Alias for [`downward_refinements`](@ref)." specializations
@doc "Test non-strict successor order of finite truth values." succeedeq
@doc "Test strict successor order of finite truth values." succeeds
@doc "Test whether a frame relation is symmetric." symmetric
@doc "Singleton to-center relation value of [`ToCenterRelation`](@ref)." tocenterrel
@doc "Test whether a frame relation is transitive." transitive
@doc "Return the shared frame when every model-family instance has an equal frame; return `nothing` for an empty or non-uniform family." uniform_frame
@doc "Alias for [`checkclass`](@ref)." validclass
@doc "Return the original-world to quotient-world map." world_map
@doc "Mathematical alias for [`NEGATION`](@ref)." (¬)
@doc "Named three-element Łukasiewicz FLew algebra." Ł3
@doc "Named four-element Łukasiewicz FLew algebra." Ł4
@doc "Mathematical alias for [`IMPLICATION`](@ref)." (→)
@doc "Mathematical alias for [`CONJUNCTION`](@ref)." (∧)
@doc "Mathematical alias for [`FUSION`](@ref)." (⊗)
@doc "Mathematical alias for [`DISJUNCTION`](@ref)." (∨)

end
