"""Inductive logic programming foundations for Aletheia."""
module AletheiaLearn

using AletheiaCore
import AletheiaCore: _fo_text, _display_header, _display_bounded, _display_elision_line, _display_elision, _styled, _DISPLAY_HEAD, DISPLAY_ITEMS
include("ilp.jl")

export Literal, literal, positive_literal, negative_literal, atoms, literals, clauses, Clause, HornClause, ClauseSet, Substitution, substitute
export subsumes, more_general, more_specific, equivalent_under_subsumption, ishorn, downward_refinements, upward_refinements, generalizations, HypothesisScore, score, ILPExample, EntailmentExample
export InterpretationExample, ProofExample, learning_from_entailment, learning_from_interpretations, learning_from_proofs, interpretation_example, model_example

end
