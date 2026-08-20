import Base: isvalid

# A deliberately small proof-search boundary.
# Aletheia asks a prover a question; it does not ship a modal/tableau engine.

"""Backend boundary for satisfiability, validity, and entailment queries."""
abstract type AbstractProver end
"""A backend response carrying a status, optional Boolean answer, and evidence."""
struct ProverResult{A,C,M,D}
    status::Symbol
    answer::A
    certificate::C
    countermodel::M
    details::D
end
ProverResult(status::Symbol; answer=nothing, certificate=nothing, countermodel=nothing, details=nothing) =
    ProverResult(status, answer, certificate, countermodel, details)
Base.Bool(result::ProverResult) = result.answer === true

"""A complete but intentionally tiny truth-table backend for propositional formulas."""
struct PropositionalProver <: AbstractProver end
const TruthTableProver = PropositionalProver

function _propositional_atoms(formula::Formula)
    atoms = Any[]
    for node in dag(formula)
        node.kind === :atom && !(node.payload in atoms) && push!(atoms, node.payload)
    end
    atoms
end
function _propositional_formula(formula::Atom)
    true
end
function _propositional_formula(formula::Branch)
    c = operator(formula)
    c isa Union{Negation,Conjunction,Disjunction,Implication} || return false
    all(_propositional_formula, children(formula))
end
function _table_model(formula, atoms, values)
    frame = Frame((:only,); index=true)
    valuation = Dict(atom_name => (value ? Set([:only]) : Set{Symbol}()) for (atom_name, value) in zip(atoms, values))
    Model(frame, BOOLEAN, valuation)
end
function _assignments(n)
    (BitVector(((mask >> (i - 1)) & 1 == 1 for i in 1:n)) for mask in 0:(2^n - 1))
end
function _truth_table(formula; atoms=nothing)
    _propositional_formula(formula) || return ProverResult(:unknown; answer=nothing,
        details="the trivial backend handles only Boolean propositional connectives")
    names = atoms === nothing ? _propositional_atoms(formula) : collect(atoms)
    for values in _assignments(length(names))
        model = _table_model(formula, names, values)
        truth = check(formula, model, :only)
        truth === true && return (true, model)
    end
    (false, nothing)
end
function _prove_satisfiability(prover::PropositionalProver, formula::Formula; atoms=nothing)
    table = _truth_table(formula; atoms=atoms)
    table isa ProverResult && return table
    answer, countermodel = table
    answer isa Bool || return ProverResult(:unknown; details="unsupported formula")
    answer ? ProverResult(:sat; answer=true, countermodel=countermodel, certificate=:truth_table) :
        ProverResult(:unsat; answer=false, certificate=:truth_table)
end
function _prove_validity(prover::PropositionalProver, formula::Formula; atoms=nothing)
    _propositional_formula(formula) || return ProverResult(:unknown; details="unsupported formula")
    names = atoms === nothing ? _propositional_atoms(formula) : collect(atoms)
    for values in _assignments(length(names))
        model = _table_model(formula, names, values)
        !check(formula, model, :only) && return ProverResult(:invalid; answer=false,
            countermodel=model, certificate=:truth_table)
    end
    ProverResult(:valid; answer=true, certificate=:truth_table)
end
function _prove_entailment(prover::PropositionalProver, premises, conclusion; atoms=nothing)
    all(_propositional_formula, premises) && _propositional_formula(conclusion) ||
        return ProverResult(:unknown; details="unsupported formula")
    names = atoms === nothing ? unique(vcat((_propositional_atoms(p) for p in premises)...,
                                            _propositional_atoms(conclusion))) : collect(atoms)
    for values in _assignments(length(names))
        model = _table_model(conclusion, names, values)
        all(check(premise, model, :only) for premise in premises) || continue
        !check(conclusion, model, :only) && return ProverResult(:invalid, false, nothing, model, :truth_table)
    end
    ProverResult(:entailed; answer=true, certificate=:truth_table)
end

"""Return a backend-specific proof-search result for satisfiability."""
function prove(prover::AbstractProver, formula::Formula; kwargs...)
    throw(MethodError(prove, (prover, formula)))
end
prove(formula::Formula, prover::AbstractProver; kwargs...) = prove(prover, formula; kwargs...)
prove(prover::PropositionalProver, formula::Formula; kwargs...) = _prove_satisfiability(prover, formula; kwargs...)

"""Return a backend-specific result for validity."""
function prove_valid(prover::AbstractProver, formula::Formula; kwargs...)
    throw(MethodError(prove_valid, (prover, formula)))
end
prove_valid(formula::Formula, prover::AbstractProver; kwargs...) = prove_valid(prover, formula; kwargs...)
prove_valid(prover::PropositionalProver, formula::Formula; kwargs...) = _prove_validity(prover, formula; kwargs...)

"""Ask an `AbstractProver` whether `formula` is satisfiable.  The result is `Bool` or `nothing` for unknown."""
function issatisfiable(prover::AbstractProver, formula::Formula; kwargs...)
    result = prove(prover, formula; kwargs...)
    result.answer
end
issatisfiable(formula::Formula, prover::AbstractProver; kwargs...) = issatisfiable(prover, formula; kwargs...)

"""Ask an `AbstractProver` whether `formula` is valid.  The result is `Bool` or `nothing` for unknown."""
function isvalid(prover::AbstractProver, formula::Formula; kwargs...)
    result = prove_valid(prover, formula; kwargs...)
    result.answer
end
isvalid(formula::Formula, prover::AbstractProver; kwargs...) = isvalid(prover, formula; kwargs...)

"""Ask an `AbstractProver` whether premises entail a conclusion."""
function entails(prover::AbstractProver, premises, conclusion; kwargs...)
    normalized = premises isa Formula ? (premises,) : collect(premises)
    result = if prover isa PropositionalProver
        _prove_entailment(prover, normalized, conclusion; kwargs...)
    else
        throw(MethodError(entails, (prover, premises, conclusion)))
    end
    result.answer
end
entails(premises, conclusion, prover::AbstractProver; kwargs...) = entails(prover, premises, conclusion; kwargs...)
# Disambiguate the two convenience orders when both outer arguments happen to be provers.
entails(left::AbstractProver, premises, right::AbstractProver; kwargs...) =
    throw(ArgumentError("entails expects one AbstractProver and one premise collection"))
entails(premise::Formula, conclusion::Formula, prover::AbstractProver; kwargs...) = entails(prover, (premise,), conclusion; kwargs...)

# Convenience spelling uses the shipped fallback explicitly; modal engines should
# always pass their own AbstractProver instance.
issatisfiable(formula::Formula; kwargs...) = issatisfiable(PropositionalProver(), formula; kwargs...)
isvalid(formula::Formula; kwargs...) = isvalid(PropositionalProver(), formula; kwargs...)
entails(premises, conclusion; kwargs...) = entails(PropositionalProver(), premises, conclusion; kwargs...)
