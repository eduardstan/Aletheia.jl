"""
    Aletheia

Aletheia provides syntax-first foundations for logical languages.  This first
layer contains similarity types, immutable hash-consed formulas, connective
traits, and a precedence-aware parser/printer.  It deliberately defines no
truth values, interpretation, or evaluation.
"""
module Aletheia

include("syntax.jl")
include("parse.jl")

export Signature, Formula, FormulaPool, Atom, Branch, DAGNode
export atom, branch, children, nchildren, value, operator, head, pool, id
export isatom, isbranch, dag, subterms, nsubterms, signature, connectives
export arity, dual, hasconnective, hasdual, precedence, associativity, commutative
export iscommutative, modality, ismodality, notation, relation, syntaxstring
export Negation, Conjunction, Disjunction, Implication, Diamond, Box
export NEGATION, CONJUNCTION, DISJUNCTION, IMPLICATION
export NOT, AND, OR, IMPLIES, ¬, ∧, ∨, →

end
