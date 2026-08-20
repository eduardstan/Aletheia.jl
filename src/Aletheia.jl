"""
    Aletheia

Aletheia provides syntax-first foundations for logical languages.  It contains
similarity types, immutable hash-consed formulas, connective traits, a
precedence-aware parser/printer, truth algebras, relational frames, models,
and atom interpretation.  Compound-formula evaluation is deliberately left to
the next stage.
"""
module Aletheia

include("syntax.jl")
include("parse.jl")
include("semantics.jl")

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
export Valuation, Model, frame, algebra, valuation, interpret

end
