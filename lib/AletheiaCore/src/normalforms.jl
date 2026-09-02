# Boolean conjunctive and disjunctive normal forms over the interned syntax.
# Modal subformulas are treated as propositional letters.  This keeps conversion
# in the existing pool and is the useful classical normal-form contract.

function _require_connectives(formula, wanted)
    return all(hasconnective(signature(formula), c) for c in wanted) || throw(
        ArgumentError("normal-form conversion needs ¬, ∧, and ∨ in the formula signature")
    )
end

@inline _is_literal(formula::Atom) = true
function _is_literal(formula::Branch)
    c = operator(formula)
    if c isa Negation
        child = children(formula)[1]
        return !(
            child isa Branch && (
                operator(child) isa Negation ||
                operator(child) isa Conjunction ||
                operator(child) isa Disjunction ||
                operator(child) isa Implication
            )
        )
    end
    return !(c isa Negation || c isa Conjunction || c isa Disjunction || c isa Implication)
end

function _nnf(formula::Atom, polarity::Bool)
    return polarity ? formula : branch(pool(formula), ¬, formula)
end
function _nnf(formula::Branch, polarity::Bool)
    c, child, p = operator(formula), children(formula), pool(formula)
    if c isa Negation
        return _nnf(child[1], !polarity)
    elseif c isa Implication
        left = _nnf(child[1], !polarity)
        right = _nnf(child[2], polarity)
        return polarity ? branch(p, ∨, left, right) : branch(p, ∧, left, right)
    elseif c isa Conjunction || c isa Disjunction
        op = polarity ? c : (c isa Conjunction ? (∨) : (∧))
        return branch(p, op, _nnf(child[1], polarity), _nnf(child[2], polarity))
    elseif polarity
        return formula
    else
        return branch(p, ¬, formula)
    end
end

function _literal_from_pair(pool, base, polarity)
    return polarity ? base : branch(pool, ¬, base)
end
function _literal_lists(formula, polarity)
    # Return NNF clauses as lists of signed, non-Boolean formula handles.
    if formula isa Atom
        return polarity ? [[(formula, true)]] : [[(formula, false)]]
    end
    c, child = operator(formula), children(formula)
    if c isa Negation
        return _literal_lists(child[1], !polarity)
    elseif c isa Implication
        left = _literal_lists(child[1], !polarity)
        right = _literal_lists(child[2], polarity)
        return if polarity
            _combine_disjunction(left, right)
        else
            _combine_conjunction(left, right)
        end
    elseif c isa Conjunction
        left, right = _literal_lists(child[1], polarity), _literal_lists(child[2], polarity)
        return if polarity
            _combine_conjunction(left, right)
        else
            _combine_disjunction(left, right)
        end
    elseif c isa Disjunction
        left, right = _literal_lists(child[1], polarity), _literal_lists(child[2], polarity)
        return if polarity
            _combine_disjunction(left, right)
        else
            _combine_conjunction(left, right)
        end
    end
    return [[(formula, polarity)]]
end
function _combine_conjunction(left, right)
    return vcat(left, right)
end
function _combine_disjunction(left, right)
    return [[a..., b...] for a in left for b in right]
end

function _normal_formula(pool, groups, outer, inner)
    built = Formula[]
    for group in groups
        isempty(group) && continue
        clause = [_literal_from_pair(pool, base, polarity) for (base, polarity) in group]
        current = clause[1]
        for item in clause[2:end]
            current = branch(pool, inner, current, item)
        end
        push!(built, current)
    end
    isempty(built) && throw(
        ArgumentError(
            "normalization produced an empty clause; constants are not in the core signature",
        ),
    )
    current = built[1]
    for item in built[2:end]
        current = branch(pool, outer, current, item)
    end
    return current
end

"""Return whether a formula is a classical conjunctive normal form.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("iscnf"))
true
```
"""
function iscnf(formula::Formula)
    if _is_literal(formula)
        return true
    end
    if formula isa Branch && operator(formula) isa Conjunction
        return all(_is_clause(c) for c in _flatten(formula, Conjunction))
    end
    return _is_clause(formula)
end
function _is_clause(formula)
    _is_literal(formula) && return true
    formula isa Branch && operator(formula) isa Disjunction || return false
    return all(_is_literal(c) for c in _flatten(formula, Disjunction))
end
"""Return whether a formula is a classical disjunctive normal form.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("isdnf"))
true
```
"""
function isdnf(formula::Formula)
    _is_literal(formula) && return true
    if formula isa Branch && operator(formula) isa Disjunction
        return all(_is_term(c) for c in _flatten(formula, Disjunction))
    end
    return _is_term(formula)
end
function _is_term(formula)
    _is_literal(formula) && return true
    formula isa Branch && operator(formula) isa Conjunction || return false
    return all(_is_literal(c) for c in _flatten(formula, Conjunction))
end
function _flatten(formula::Formula, connective::Type)
    formula isa Branch && operator(formula) isa connective || return Formula[formula]
    child = children(formula)
    return vcat(_flatten(child[1], connective), _flatten(child[2], connective))
end

"""Convert a formula to classical CNF while retaining its original FormulaPool.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("to_cnf"))
true
```
"""
function to_cnf(formula::Formula)
    _require_connectives(formula, (¬, ∧, ∨))
    groups = _literal_lists(formula, true)
    return _normal_formula(pool(formula), groups, ∧, ∨)
end
"""Convert a formula to classical DNF while retaining its original FormulaPool.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("to_dnf"))
true
```
"""
function to_dnf(formula::Formula)
    _require_connectives(formula, (¬, ∧, ∨))
    # DNF is CNF's dual: negate, obtain CNF, then negate back to NNF DNF.
    groups = _literal_lists(formula, true)
    terms = _dnf_from_formula(formula)
    return _normal_formula(pool(formula), terms, ∨, ∧)
end
function _dnf_from_formula(formula::Atom)
    return [[(formula, true)]]
end
function _dnf_from_formula(formula::Branch)
    c, child = operator(formula), children(formula)
    if c isa Negation
        return _dnf_from_nnf(_nnf(formula, true))
    elseif c isa Disjunction
        return vcat(_dnf_from_formula(child[1]), _dnf_from_formula(child[2]))
    elseif c isa Conjunction
        return [
            [a..., b...] for a in _dnf_from_formula(child[1]) for
            b in _dnf_from_formula(child[2])
        ]
    elseif c isa Implication
        return _dnf_from_nnf(_nnf(formula, true))
    end
    return [[(formula, true)]]
end
function _dnf_from_nnf(formula)
    if _is_literal(formula)
        return [[(formula, true)]]
    end
    c, child = operator(formula), children(formula)
    c isa Disjunction && return vcat(_dnf_from_nnf(child[1]), _dnf_from_nnf(child[2]))
    # A non-literal NNF node is necessarily a conjunction.
    return [[a..., b...] for a in _dnf_from_nnf(child[1]) for b in _dnf_from_nnf(child[2])]
end
const cnf = to_cnf
const dnf = to_dnf
const conjunctive_normal_form = to_cnf
const disjunctive_normal_form = to_dnf
