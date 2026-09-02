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
function ProverResult(
    status::Symbol;
    answer=nothing,
    certificate=nothing,
    countermodel=nothing,
    details=nothing,
)
    return ProverResult(status, answer, certificate, countermodel, details)
end
Base.Bool(result::ProverResult) = result.answer === true

"""A complete but intentionally tiny truth-table backend for propositional formulas."""
struct PropositionalProver <: AbstractProver end
const TruthTableProver = PropositionalProver

function _propositional_atoms(formula::Formula)
    atoms = Any[]
    for node in dag(formula)
        node.kind === :atom && !(node.payload in atoms) && push!(atoms, node.payload)
    end
    return atoms
end
function _propositional_atom_names(required_formulas; atoms=nothing)
    required = if required_formulas isa Formula
        _propositional_atoms(required_formulas)
    else
        unique(vcat((_propositional_atoms(formula) for formula in required_formulas)...))
    end
    atoms === nothing && return required
    # Accept same-pool Atom handles as a convenience, but use their payloads
    # as the valuation keys just like formula discovery does.
    names = [entry isa Atom ? value(entry) : entry for entry in atoms]
    length(unique(names)) == length(names) ||
        throw(ArgumentError("atoms override must not contain duplicates"))
    missing = [name for name in required if !(name in names)]
    isempty(missing) || throw(
        ArgumentError(
            "atoms override is missing formula atoms: $(join(string.(missing), ", "))"
        ),
    )
    return names
end
function _propositional_formula(formula::Atom)
    return true
end
function _propositional_formula(formula::Branch)
    c = operator(formula)
    c isa Union{Negation,Conjunction,Disjunction,Implication} || return false
    return all(_propositional_formula, children(formula))
end
function _table_model(formula, atoms, values)
    frame = Frame((:only,); index=true)
    valuation = Dict(
        atom_name => (value ? Set([:only]) : Set{Symbol}()) for
        (atom_name, value) in zip(atoms, values)
    )
    return Model(frame, BOOLEAN, valuation)
end
function _assignments(n)
    return (BitVector(((mask >> (i - 1)) & 1 == 1 for i in 1:n)) for mask in 0:(2^n - 1))
end
function _truth_table(formula; atoms=nothing)
    _propositional_formula(formula) || return ProverResult(
        :unknown;
        answer=nothing,
        details="the trivial backend handles only Boolean propositional connectives",
    )
    names = _propositional_atom_names(formula; atoms=atoms)
    for values in _assignments(length(names))
        model = _table_model(formula, names, values)
        truth = check(formula, model, :only)
        truth === true && return (true, model)
    end
    return (false, nothing)
end
function _prove_satisfiability(prover::PropositionalProver, formula::Formula; atoms=nothing)
    table = _truth_table(formula; atoms=atoms)
    table isa ProverResult && return table
    answer, countermodel = table
    answer isa Bool || return ProverResult(:unknown; details="unsupported formula")
    return if answer
        ProverResult(:sat; answer=true, countermodel=countermodel, certificate=:truth_table)
    else
        ProverResult(:unsat; answer=false, certificate=:truth_table)
    end
end
function _prove_validity(prover::PropositionalProver, formula::Formula; atoms=nothing)
    _propositional_formula(formula) ||
        return ProverResult(:unknown; details="unsupported formula")
    names = _propositional_atom_names(formula; atoms=atoms)
    for values in _assignments(length(names))
        model = _table_model(formula, names, values)
        !check(formula, model, :only) && return ProverResult(
            :invalid; answer=false, countermodel=model, certificate=:truth_table
        )
    end
    return ProverResult(:valid; answer=true, certificate=:truth_table)
end
function _prove_entailment(prover::PropositionalProver, premises, conclusion; atoms=nothing)
    all(_propositional_formula, premises) && _propositional_formula(conclusion) ||
        return ProverResult(:unknown; details="unsupported formula")
    names = _propositional_atom_names((premises..., conclusion); atoms=atoms)
    for values in _assignments(length(names))
        model = _table_model(conclusion, names, values)
        all(check(premise, model, :only) for premise in premises) || continue
        !check(conclusion, model, :only) &&
            return ProverResult(:invalid, false, nothing, model, :truth_table)
    end
    return ProverResult(:entailed; answer=true, certificate=:truth_table)
end

"""Return a backend-specific proof-search result for satisfiability."""
function prove(prover::AbstractProver, formula::Formula; kwargs...)
    return throw(MethodError(prove, (prover, formula)))
end
function prove(formula::Formula, prover::AbstractProver; kwargs...)
    return prove(prover, formula; kwargs...)
end
function prove(prover::PropositionalProver, formula::Formula; kwargs...)
    return _prove_satisfiability(prover, formula; kwargs...)
end

"""Return a backend-specific result for validity."""
function prove_valid(prover::AbstractProver, formula::Formula; kwargs...)
    return throw(MethodError(prove_valid, (prover, formula)))
end
function prove_valid(formula::Formula, prover::AbstractProver; kwargs...)
    return prove_valid(prover, formula; kwargs...)
end
function prove_valid(prover::PropositionalProver, formula::Formula; kwargs...)
    return _prove_validity(prover, formula; kwargs...)
end

"""Ask an `AbstractProver` whether `formula` is satisfiable.  The result is `Bool` or `nothing` for unknown."""
function issatisfiable(prover::AbstractProver, formula::Formula; kwargs...)
    result = prove(prover, formula; kwargs...)
    return result.answer
end
function issatisfiable(formula::Formula, prover::AbstractProver; kwargs...)
    return issatisfiable(prover, formula; kwargs...)
end

"""Ask an `AbstractProver` whether `formula` is valid.  The result is `Bool` or `nothing` for unknown."""
function isvalid(prover::AbstractProver, formula::Formula; kwargs...)
    result = prove_valid(prover, formula; kwargs...)
    return result.answer
end
function isvalid(formula::Formula, prover::AbstractProver; kwargs...)
    return isvalid(prover, formula; kwargs...)
end

"""Ask an `AbstractProver` whether premises entail a conclusion."""
function entails(prover::AbstractProver, premises, conclusion; kwargs...)
    normalized = premises isa Formula ? (premises,) : collect(premises)
    result = if prover isa PropositionalProver
        _prove_entailment(prover, normalized, conclusion; kwargs...)
    elseif prover isa FiniteModelProver
        _finite_entailment_result(prover, normalized, conclusion; kwargs...)
    else
        throw(MethodError(entails, (prover, premises, conclusion)))
    end
    return result.answer
end
function entails(premises, conclusion, prover::AbstractProver; kwargs...)
    return entails(prover, premises, conclusion; kwargs...)
end
# Disambiguate the two convenience orders when both outer arguments happen to be provers.
function entails(left::AbstractProver, premises, right::AbstractProver; kwargs...)
    return throw(
        ArgumentError("entails expects one AbstractProver and one premise collection")
    )
end
function entails(premise::Formula, conclusion::Formula, prover::AbstractProver; kwargs...)
    return entails(prover, (premise,), conclusion; kwargs...)
end

# Convenience spelling uses the shipped fallback explicitly; modal engines should
# always pass their own AbstractProver instance.
function issatisfiable(formula::Formula; kwargs...)
    return issatisfiable(PropositionalProver(), formula; kwargs...)
end
isvalid(formula::Formula; kwargs...) = isvalid(PropositionalProver(), formula; kwargs...)
function entails(premises, conclusion; kwargs...)
    return entails(PropositionalProver(), premises, conclusion; kwargs...)
end

struct _FiniteWorld
    index::Int
end

"""
    FiniteModelProver([bound]; bound=bound)

A naive bounded finite-model decider for Boolean and supported finite-valued
formulas. `bound` is the greatest number of worlds considered (default `2`).
The decider enumerates every relation and atom valuation for each size from one
through `bound`; it never searches beyond that bound. A witness or
countermodel settles a query. If a modal query has no such result within the
bound, the result is `:inconclusive` with `answer === nothing`, rather than a
claim about larger models. Non-modal formulas are exhaustively decided over
the selected finite truth algebra. Infinite-valued algebras, unsupported
connectives, and other unsupported formulas return `:unknown`.

The `countermodel` field contains a satisfying model for `:sat` and a
counterexample model for `:invalid`; it is also copied to `certificate` for a
satisfying witness so that evidence is never unwitnessed.
"""
struct FiniteModelProver <: AbstractProver
    bound::Int
    function FiniteModelProver(bound::Integer)
        bound >= 1 || throw(ArgumentError("finite-model bound must be at least one"))
        bound <= typemax(Int) || throw(ArgumentError("finite-model bound is too large"))
        return new(Int(bound))
    end
end
FiniteModelProver(; bound::Integer=2) = FiniteModelProver(bound)

function _finite_formula(formula::Formula)
    for node in dag(formula)
        node.kind === :atom && continue
        connective = node.payload
        connective isa
        Union{Negation,Conjunction,Fusion,Disjunction,Implication,Diamond,Box} ||
            return false
    end
    return true
end
_finite_formula(::Any) = false

function _finite_truth_values(algebra::TruthAlgebra)
    if algebra isa BooleanAlgebra
        return domain(algebra)
    elseif algebra isa FiniteFLewAlgebra
        return domain(algebra)
    elseif algebra isa Union{GodelAlgebra,LukasiewiczAlgebra} && isfinitechain(algebra)
        return domain(algebra)
    end
    return nothing
end

function _finite_relation_names(formula::Formula)
    return sort!(collect(_relation_names(_evaluation_nodes(formula))); by=string)
end

function _finite_each_assignment(values, count::Int, visitor::Function)
    current = Vector{Any}(undef, count)
    function visit(slot::Int)
        slot > count && return visitor(current)
        for candidate in values
            current[slot] = candidate
            visit(slot + 1) && return true
        end
        return false
    end
    return visit(1)
end

function _finite_each_relation_masks(names, width::Int, visitor::Function)
    # A machine integer is intentional here: refusing an overflowing mask is
    # preferable to silently searching only a fragment of the finite space.
    width < 8 * sizeof(Int) - 1 || return false
    limit = Int(1) << width
    masks = Vector{Int}(undef, length(names))
    function visit(slot::Int)
        slot > length(names) && return visitor(masks)
        for mask in 0:(limit - 1)
            masks[slot] = mask
            visit(slot + 1) && return true
        end
        return false
    end
    return visit(1)
end

function _finite_frame(names, masks, n::Int)
    frame_worlds = Tuple(_FiniteWorld(i) for i in 1:n)
    relation_map = Dict{Any,Any}()
    for (name, mask) in zip(names, masks)
        adjacency = Dict{Any,Any}()
        for source in 1:n
            targets = Any[]
            for target in 1:n
                bit = (source - 1) * n + target - 1
                (mask >> bit) & 1 == 1 && push!(targets, target)
            end
            adjacency[frame_worlds[source]] = [frame_worlds[target] for target in targets]
        end
        relation_map[name] = adjacency
    end
    return Frame(frame_worlds, relation_map; index=true)
end

function _finite_model(names, values, frame::Frame, algebra::TruthAlgebra, atoms_count::Int)
    world_tuple = worlds(frame)
    valuation = Dict{Any,Any}()
    if algebra isa BooleanAlgebra
        for atom_slot in 1:atoms_count
            start = (atom_slot - 1) * length(world_tuple)
            valuation[names[atom_slot]] = Set(
                world_tuple[world_slot] for
                world_slot in eachindex(world_tuple) if values[start + world_slot] === true
            )
        end
    else
        for atom_slot in 1:atoms_count
            start = (atom_slot - 1) * length(world_tuple)
            valuation[names[atom_slot]] = Dict(
                world_tuple[world_slot] => values[start + world_slot] for
                world_slot in eachindex(world_tuple)
            )
        end
    end
    return Model(frame, algebra, valuation)
end

"""Enumerate bounded frames and valuations, stopping when `visitor` succeeds."""
function _finite_models(
    formula::Formula,
    algebra::TruthAlgebra,
    bound::Int,
    visitor::Function;
    atoms=nothing,
    relations=nothing,
)
    atom_names = _propositional_atom_names(formula; atoms=atoms)
    relation_names = if relations === nothing
        _finite_relation_names(formula)
    else
        sort!(unique(collect(relations)); by=string)
    end
    values = _finite_truth_values(algebra)
    values === nothing && return (false, nothing, 0, false)
    tested = Ref(0)
    witness = Ref{Any}(nothing)
    complete = Ref(true)
    for world_count in 1:bound
        edge_width = world_count * world_count
        if edge_width >= 8 * sizeof(Int) - 1
            complete[] = false
            break
        end
        found = _finite_each_relation_masks(
            relation_names,
            edge_width,
            masks -> begin
                frame = _finite_frame(relation_names, masks, world_count)
                _finite_each_assignment(
                    values,
                    length(atom_names) * world_count,
                    assignment -> begin
                        model = _finite_model(
                            atom_names,
                            assignment,
                            frame,
                            algebra,
                            length(atom_names),
                        )
                        tested[] += 1
                        if visitor(model)
                            witness[] = model
                            true
                        else
                            false
                        end
                    end,
                )
            end,
        )
        found && return (true, witness[], tested[], complete[])
    end
    return (false, nothing, tested[], complete[])
end

function _finite_bound(prover::FiniteModelProver, requested)
    requested === nothing && return prover.bound
    return FiniteModelProver(requested).bound
end

function _finite_details(query, bound, tested; complete=true)
    suffix = complete ? "" : "; finite search space was too large to enumerate"
    return "$query search exhausted after $tested model$(tested == 1 ? "" : "s") through world bound $bound$suffix"
end

function _finite_unsupported(algebra, formula)
    _finite_formula(formula) || return "unsupported connective or formula"
    relation_names = _finite_relation_names(formula)
    any(name -> name isa RelationFamily, relation_names) &&
        return "relation-family connectives are not supported by the generated-frame search"
    _finite_truth_values(algebra) === nothing &&
        return "finite Boolean, Gödel-chain, Łukasiewicz-chain, or FLew algebra required"
    return nothing
end

function prove(
    prover::FiniteModelProver,
    formula::Formula;
    bound=nothing,
    atoms=nothing,
    algebra::TruthAlgebra=BOOLEAN,
)
    reason = _finite_unsupported(algebra, formula)
    reason !== nothing && return ProverResult(:unknown; details=reason)
    actual_bound = _finite_bound(prover, bound)
    modal = !isempty(_finite_relation_names(formula))
    found, model, tested, complete = _finite_models(
        formula,
        algebra,
        modal ? actual_bound : 1,
        candidate -> check(formula, candidate, AnyWorld());
        atoms=atoms,
    )
    found && return ProverResult(
        :sat;
        answer=true,
        certificate=model,
        countermodel=model,
        details="bounded finite-model witness",
    )
    modal || return ProverResult(
        :unsat;
        answer=false,
        certificate=:finite_exhaustion,
        details=_finite_details("satisfiability", actual_bound, tested; complete=complete),
    )
    return ProverResult(
        :inconclusive;
        details=_finite_details("satisfiability", actual_bound, tested; complete=complete),
    )
end

function _finite_algebra_for_query(formula::Formula, algebra)
    reason = _finite_unsupported(algebra, formula)
    reason === nothing || return reason
    return nothing
end

@inline _finite_designated(algebra::TruthAlgebra, value) = value == top(algebra)

function prove_valid(
    prover::FiniteModelProver,
    formula::Formula;
    bound=nothing,
    atoms=nothing,
    algebra::TruthAlgebra=BOOLEAN,
)
    reason = _finite_algebra_for_query(formula, algebra)
    reason !== nothing && return ProverResult(:unknown; details=reason)
    actual_bound = _finite_bound(prover, bound)
    modal = !isempty(_finite_relation_names(formula))
    found, model, tested, complete = _finite_models(
        formula,
        algebra,
        modal ? actual_bound : 1,
        candidate -> any(
            !_finite_designated(algebra, check(formula, candidate, world)) for
            world in worlds(frame(candidate))
        );
        atoms=atoms,
    )
    found && return ProverResult(
        :invalid;
        answer=false,
        countermodel=model,
        certificate=:finite_model,
        details="bounded finite-model counterexample",
    )
    modal || return ProverResult(
        :valid;
        answer=true,
        certificate=:finite_exhaustion,
        details=_finite_details("validity", actual_bound, tested; complete=complete),
    )
    return ProverResult(
        :inconclusive;
        details=_finite_details("validity", actual_bound, tested; complete=complete),
    )
end

function _finite_entailment_result(
    prover::FiniteModelProver,
    premises,
    conclusion;
    bound=nothing,
    atoms=nothing,
    algebra::TruthAlgebra=BOOLEAN,
)
    all(formula -> formula isa Formula && _finite_formula(formula), premises) &&
        _finite_formula(conclusion) ||
        return ProverResult(:unknown; details="unsupported connective or formula")
    any(
        name -> name isa RelationFamily,
        vcat((_finite_relation_names(formula) for formula in (premises..., conclusion))...),
    ) && return ProverResult(
        :unknown;
        details="relation-family connectives are not supported by the generated-frame search",
    )
    _finite_truth_values(algebra) === nothing && return ProverResult(
        :unknown;
        details="finite Boolean, Gödel-chain, Łukasiewicz-chain, or FLew algebra required",
    )
    actual_bound = _finite_bound(prover, bound)
    formulae = (premises..., conclusion)
    relation_names = sort!(
        unique(vcat((_finite_relation_names(formula) for formula in formulae)...));
        by=string,
    )
    modal = !isempty(relation_names)
    combined_atoms = _propositional_atom_names(formulae; atoms=atoms)
    found, model, tested, complete = _finite_models(
        conclusion,
        algebra,
        modal ? actual_bound : 1,
        candidate -> any(
            world ->
                all(
                    _finite_designated(algebra, check(premise, candidate, world)) for
                    premise in premises
                ) && !_finite_designated(algebra, check(conclusion, candidate, world)),
            worlds(frame(candidate)),
        );
        atoms=combined_atoms,
        relations=relation_names,
    )
    found && return ProverResult(
        :invalid;
        answer=false,
        countermodel=model,
        certificate=:finite_model,
        details="bounded finite-model counterexample",
    )
    modal || return ProverResult(
        :entailed;
        answer=true,
        certificate=:finite_exhaustion,
        details=_finite_details("entailment", actual_bound, tested; complete=complete),
    )
    return ProverResult(
        :inconclusive;
        details=_finite_details("entailment", actual_bound, tested; complete=complete),
    )
end

"""
    prove_entails(prover, premises, conclusion; kwargs...)

Return the full [`ProverResult`](@ref) for an entailment query. This is the
status-preserving counterpart of [`entails`](@ref), whose compatibility API
returns only `Bool` or `nothing`.
"""
function prove_entails(prover::AbstractProver, premises, conclusion; kwargs...)
    normalized = premises isa Formula ? (premises,) : collect(premises)
    if prover isa PropositionalProver
        return _prove_entailment(prover, normalized, conclusion; kwargs...)
    elseif prover isa FiniteModelProver
        return _finite_entailment_result(prover, normalized, conclusion; kwargs...)
    end
    return throw(MethodError(prove_entails, (prover, premises, conclusion)))
end
function prove_entails(premises, conclusion, prover::AbstractProver; kwargs...)
    return prove_entails(prover, premises, conclusion; kwargs...)
end
# Disambiguate the two convenience orders when both outer arguments are provers.
function prove_entails(left::AbstractProver, premises, right::AbstractProver; kwargs...)
    return throw(
        ArgumentError("prove_entails expects one AbstractProver and one premise collection")
    )
end
function prove_entails(
    premise::Formula, conclusion::Formula, prover::AbstractProver; kwargs...
)
    return prove_entails(prover, (premise,), conclusion; kwargs...)
end

const BoundedFiniteProver = FiniteModelProver
