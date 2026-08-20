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
include("evaluation.jl")
include("firstorder.jl")
include("normalforms.jl")
include("bisimulation.jl")
include("prover.jl")

export Signature, Formula, FormulaPool, Atom, Branch, DAGNode
export atom, branch, children, nchildren, value, operator, head, pool, id
export isatom, isbranch, dag, subterms, nsubterms, signature, connectives
export arity, dual, hasconnective, hasdual, precedence, associativity, commutative
export iscommutative, modality, ismodality, notation, relation, syntaxstring
export Negation, Conjunction, Disjunction, Implication, Diamond, Box
export NEGATION, CONJUNCTION, DISJUNCTION, IMPLICATION
export NOT, AND, OR, IMPLIES, ¬, ∧, ∨, →
export TruthAlgebra, BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export GodelChain, LukasiewiczChain, GödelAlgebra, ŁukasiewiczAlgebra
export BOOLEAN, truth_type, truthtype, carrier, top, bottom, bot, meet, join
export domain
export implication, negation, implies, negate, levels, isfinitechain
export Frame, worlds, relations, world_index, hasworldindex, world_position, accessible
export check, extension
export Valuation, Model, frame, algebra, valuation, interpret

export FirstOrderTerm, FirstOrderFormula, FOTerm, FOFormula
export Variable, Constant, Predicate, Equality, FONegation, FOConjunction, FODisjunction, FOImplication
export Exists, Forall, FOVariable, FOConstant, FOAtom, FOPredicate, FOEquality
export FONot, FOAnd, FOOr, FOImplies, FOExists, FOForall
export FirstOrderInterpretation, FOInterpretation, FOModel, evaluate, standard_translation, standardtranslate, translate
export first_order_interpretation, firstorder
export iscnf, isdnf, to_cnf, to_dnf, cnf, dnf, conjunctive_normal_form, disjunctive_normal_form
export bisimilar, BisimulationClass, BisimulationContraction, QuotientModel, bisimulation_contraction, contraction_world
export model, classes, world_map, contract, contraction
export AbstractProver, ProverResult, PropositionalProver, TruthTableProver, prove, prove_valid
export issatisfiable, isvalid, entails

end
