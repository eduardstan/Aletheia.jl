# Inductive logic programming foundations over the first-order syntax.
# Definitions and terminology follow Muggleton & De Raedt (1994), §5.2.

"""A signed atomic first-order literal (Muggleton & De Raedt, §5.2 [muggleton1994](@cite))."""
struct Literal
    atom::Union{Predicate,Equality}
    positive::Bool
    function Literal(atom::Union{Predicate,Equality}, positive::Bool=true)
        new(atom, positive)
    end
end

Literal(formula::FONegation) = formula.child isa Union{Predicate,Equality} ? Literal(formula.child, false) :
    throw(ArgumentError("a literal may negate only a predicate or equality"))
Literal(other) = throw(ArgumentError("a literal must contain a predicate or equality; got $(typeof(other))"))
literal(atom::Union{Predicate,Equality}, positive::Bool=true) = Literal(atom, positive)
positive_literal(atom::Union{Predicate,Equality}) = Literal(atom, true)
negative_literal(atom::Union{Predicate,Equality}) = Literal(atom, false)
positive_literal(literal::Literal) = literal.positive
negative_literal(literal::Literal) = !literal.positive

"""Return the signed atom carried by a literal."""
atoms(literal::Literal) = literal.atom

function Base.show(io::IO, literal::Literal)
    literal.positive || print(io, "¬")
    print(io, _fo_text(literal.atom))
end
Base.string(literal::Literal) = sprint(show, literal)

_normalize_literal(literal::Literal) = literal
_normalize_literal(atom::Union{Predicate,Equality}) = Literal(atom)
_normalize_literal(formula::FONegation) = Literal(formula)
_normalize_literal(other) = throw(ArgumentError("expected a predicate, equality, or literal; got $(typeof(other))"))

"""A clause, represented compactly as a canonical immutable tuple of literals.

The tuple has set semantics: duplicate literals are removed and ordering is
canonicalized for stable equality, hashing, and display.  A clause is read as
the disjunction of its literals; the empty clause is contradiction. This is the
clause representation of Muggleton & De Raedt, §5.2 [muggleton1994](@cite).
"""
struct Clause{L<:Tuple}
    literals::L
    function Clause(literals::Tuple)
        normalized = Literal[_normalize_literal(literal) for literal in literals]
        unique!(normalized)
        sort!(normalized, by=_literal_sort_key)
        canonical = tuple(normalized...)
        new{typeof(canonical)}(canonical)
    end
end

Clause(literals::AbstractVector) = Clause(tuple(literals...))
Clause(literals::AbstractSet) = Clause(tuple(literals...))
Clause(first, rest...) = Clause(tuple(first, rest...))
Clause() = Clause(())

Base.length(clause::Clause) = length(clause.literals)
Base.iterate(clause::Clause, state...) = iterate(clause.literals, state...)
Base.getindex(clause::Clause, i::Integer) = clause.literals[i]
Base.isempty(clause::Clause) = isempty(clause.literals)
Base.eltype(::Type{<:Clause}) = Literal
_literal_sort_key(literal::Literal) = (literal.positive ? 1 : 0, string(typeof(literal.atom)), repr(literal.atom))
function _clause_set_equal(left::Clause, right::Clause)
    length(left) == length(right) && all(any(isequal(literal, other) for other in right) for literal in left)
end
Base.isequal(left::Clause, right::Clause) = _clause_set_equal(left, right)
Base.:(==)(left::Clause, right::Clause) = isequal(left, right)
function Base.hash(clause::Clause, seed::UInt)
    # XOR makes the hash independent of the tuple's canonical order.
    foldl((h, literal) -> xor(h, hash(literal, seed)), clause.literals; init=hash(length(clause), seed))
end
function Base.show(io::IO, clause::Clause)
    isempty(clause) ? print(io, "⊥") : print(io, join(string.(clause.literals), " ∨ "))
end
Base.string(clause::Clause) = sprint(show, clause)

"""A Horn clause: a clause with at most one positive literal (Muggleton & De Raedt, §3.2 [muggleton1994](@cite))."""
struct HornClause
    clause::Clause
    function HornClause(clause::Clause)
        count(literal -> literal.positive, clause.literals) <= 1 ||
            throw(ArgumentError("a Horn clause has at most one positive literal"))
        new(clause)
    end
end
HornClause(literals::Tuple) = HornClause(Clause(literals))
HornClause(literals::AbstractVector) = HornClause(Clause(literals))
HornClause(literals::AbstractSet) = HornClause(Clause(literals))
HornClause(first, rest...) = HornClause(Clause(first, rest...))
HornClause(head::Union{Nothing,Predicate,Equality}, body::Union{Predicate,Equality}...) =
    HornClause(head === nothing ? Clause(tuple((Literal(a, false) for a in body)...)) :
               Clause((Literal(head, true), (Literal(a, false) for a in body)...)))
Base.length(clause::HornClause) = length(clause.clause)
Base.iterate(clause::HornClause, state...) = iterate(clause.clause, state...)
Base.getindex(clause::HornClause, i::Integer) = clause.clause[i]
function _horn_clause_string(clause::HornClause)
    lits = clause.clause.literals
    pos_idx = findfirst(l -> l.positive, lits)
    pos_lit = pos_idx !== nothing ? lits[pos_idx] : nothing
    neg_lits = [l for l in lits if !l.positive]

    head_str = pos_lit !== nothing ? _fo_text(pos_lit.atom) : ""
    body_str = join([_fo_text(l.atom) for l in neg_lits], ", ")

    if pos_lit !== nothing && !isempty(neg_lits)
        return "$head_str :- $body_str"
    elseif pos_lit !== nothing && isempty(neg_lits)
        return head_str
    elseif pos_lit === nothing && !isempty(neg_lits)
        return ":- $body_str"
    else
        return "⊥"
    end
end

Base.show(io::IO, clause::HornClause) = print(io, _horn_clause_string(clause))
Base.show(io::IO, ::MIME"text/plain", clause::HornClause) = print(io, _horn_clause_string(clause))
Base.string(clause::HornClause) = _horn_clause_string(clause)
Base.:(==)(left::HornClause, right::HornClause) = left.clause == right.clause
Base.hash(clause::HornClause, h::UInt) = hash(clause.clause, h)
literals(clause::Clause) = clause.literals
literals(clause::HornClause) = clause.clause.literals

"""A finite background knowledge base, represented as a tuple of clauses (Muggleton & De Raedt, §3 [muggleton1994](@cite))."""
struct ClauseSet{C<:Tuple}
    clauses::C
    function ClauseSet(clauses::Tuple)
        normalized = Clause[clause isa HornClause ? clause.clause : clause isa Clause ? clause : Clause(clause)
                            for clause in clauses]
        unique!(normalized)
        sort!(normalized, by=string)
        canonical = tuple(normalized...)
        new{typeof(canonical)}(canonical)
    end
end
ClauseSet(clauses::AbstractVector) = ClauseSet(tuple(clauses...))
ClauseSet(clauses::AbstractSet) = ClauseSet(tuple(clauses...))
ClauseSet(first, rest...) = ClauseSet(tuple(first, rest...))
ClauseSet() = ClauseSet(())
const BackgroundKnowledge = ClauseSet
Base.length(knowledge::ClauseSet) = length(knowledge.clauses)
Base.iterate(knowledge::ClauseSet, state...) = iterate(knowledge.clauses, state...)
Base.getindex(knowledge::ClauseSet, i::Integer) = knowledge.clauses[i]
Base.isequal(left::ClauseSet, right::ClauseSet) = length(left) == length(right) &&
    all(any(isequal(clause, other) for other in right) for clause in left)
Base.:(==)(left::ClauseSet, right::ClauseSet) = isequal(left, right)
Base.hash(knowledge::ClauseSet, seed::UInt) = foldl((h, clause) -> xor(h, hash(clause, seed)), knowledge.clauses;
                                                    init=hash(length(knowledge), seed))
clauses(knowledge::ClauseSet) = knowledge.clauses
Base.show(io::IO, knowledge::ClauseSet) = print(io, "ClauseSet(", join(string.(knowledge.clauses), ", "), ")")

function Base.show(io::IO, ::MIME"text/plain", knowledge::ClauseSet)
    nc = length(knowledge.clauses)
    _display_header(io, "ClauseSet", "$nc clause$(nc == 1 ? "" : "s")")
    shown, elided = _display_bounded(io, knowledge.clauses, DISPLAY_ITEMS)
    for clause in shown
        print(io, "\n  ", string(ishorn(clause) ? HornClause(clause) : clause))
    end
    _display_elision_line(io, 2, elided)
end

Base.string(knowledge::ClauseSet) = sprint(show, knowledge)

"""A finite substitution for first-order variables (Muggleton & De Raedt, Definition 5.3 [muggleton1994](@cite))."""
struct Substitution
    bindings::Tuple
    function Substitution(bindings::Tuple)
        normalized = Pair{Variable,FirstOrderTerm}[_as_variable(pair.first) => _as_term(pair.second)
                                                    for pair in bindings]
        keys_seen = Set{Variable}()
        result = Pair{Variable,FirstOrderTerm}[]
        for pair in normalized
            pair.first in keys_seen && throw(ArgumentError("a substitution cannot bind a variable twice"))
            push!(keys_seen, pair.first)
            push!(result, pair)
        end
        sort!(result, by=pair -> string(pair.first.name))
        canonical = tuple(result...)
        new(canonical)
    end
end
Substitution() = Substitution(())
function _as_variable(variable)
    variable isa Variable && return variable
    variable isa Symbol && return Variable(variable)
    variable isa AbstractString && return Variable(variable)
    throw(ArgumentError("substitution keys must be variables, symbols, or strings"))
end
function _as_term(term)
    term isa FirstOrderTerm || throw(ArgumentError("substitution values must be first-order terms"))
    term
end
Substitution(bindings::AbstractDict) = Substitution(tuple((pair.first => pair.second for pair in bindings)...))
Substitution(bindings::AbstractVector) = Substitution(tuple(bindings...))
Substitution(bindings::Pair...) = Substitution(tuple(bindings...))
Base.length(substitution::Substitution) = length(substitution.bindings)
Base.iterate(substitution::Substitution, state...) = iterate(substitution.bindings, state...)
function Base.getindex(substitution::Substitution, variable)
    variable = _as_variable(variable)
    for pair in substitution.bindings
        pair.first == variable && return pair.second
    end
    throw(KeyError(variable))
end
Base.haskey(substitution::Substitution, variable) = try
    substitution[variable]; true
catch error
    error isa KeyError || rethrow(); false
end

function _substitution_lookup(substitution::Substitution, variable::Variable)
    for pair in substitution.bindings
        pair.first == variable && return pair.second
    end
    nothing
end
function _apply_substitution(term::Variable, substitution::Substitution, seen::Set{Variable})
    bound = _substitution_lookup(substitution, term)
    bound === nothing && return term
    term in seen && return term
    next_seen = copy(seen)
    push!(next_seen, term)
    _apply_substitution(bound, substitution, next_seen)
end
_apply_substitution(term::Constant, substitution::Substitution, seen::Set{Variable}) = term
_apply_substitution(term::FunctionTerm, substitution::Substitution, seen::Set{Variable}) =
    FunctionTerm(term.name, tuple((_apply_substitution(argument, substitution, seen) for argument in term.arguments)...))

"""Apply a normalized substitution to a term, atomic formula, or clause.

Bindings are followed through variable chains; this is the usual composed application,
not a capture-avoiding operation for quantified formulas."""
substitute(term::FirstOrderTerm, substitution::Substitution) = _apply_substitution(term, substitution, Set{Variable}())
substitute(substitution::Substitution, term::FirstOrderTerm) = substitute(term, substitution)
function substitute(formula::Predicate, substitution::Substitution)
    Predicate(formula.name, tuple((substitute(argument, substitution) for argument in formula.arguments)...))
end
function substitute(formula::Equality, substitution::Substitution)
    Equality(substitute(formula.left, substitution), substitute(formula.right, substitution))
end
substitute(literal::Literal, substitution::Substitution) =
    Literal(substitute(literal.atom, substitution), literal.positive)
substitute(clause::Clause, substitution::Substitution) = Clause(tuple((substitute(literal, substitution) for literal in clause)...))
substitute(clause::HornClause, substitution::Substitution) = HornClause(substitute(clause.clause, substitution))
substitute(knowledge::ClauseSet, substitution::Substitution) = ClauseSet(tuple((substitute(clause, substitution) for clause in knowledge)...))

function _match_term(pattern::Variable, target::FirstOrderTerm, environment::Dict{Variable,FirstOrderTerm})
    existing = get(environment, pattern, nothing)
    if existing === nothing
        environment[pattern] = target
        return true
    end
    isequal(existing, target)
end
function _match_term(pattern::Constant, target::FirstOrderTerm, environment)
    target isa Constant && isequal(pattern.value, target.value)
end
function _match_term(pattern::FunctionTerm, target::FirstOrderTerm, environment)
    target isa FunctionTerm || return false
    isequal(pattern.name, target.name) || return false
    length(pattern.arguments) == length(target.arguments) || return false
    all(_match_term(pattern.arguments[i], target.arguments[i], environment) for i in eachindex(pattern.arguments))
end
function _match_literal(pattern::Literal, target::Literal, environment::Dict{Variable,FirstOrderTerm})
    pattern.positive == target.positive || return false
    left, right = pattern.atom, target.atom
    typeof(left) === typeof(right) || return false
    if left isa Predicate
        isequal(left.name, right.name) || return false
        length(left.arguments) == length(right.arguments) || return false
        return all(_match_term(left.arguments[i], right.arguments[i], environment) for i in eachindex(left.arguments))
    end
    _match_term(left.left, right.left, environment) && _match_term(left.right, right.right, environment)
end

"""Decide Plotkin's θ-subsumption: some substitution makes `left` a subset of `right`.

The search is a direct backtracking matcher and is exponential in the worst case,
as expected for the NP-complete general problem.  Variables in `right` are treated
as ordinary target terms; only variables in `left` are bound. The definition is
Muggleton & De Raedt, Definition 5.3 [muggleton1994](@cite).
"""
function subsumes(left::Clause, right::Clause)
    # A substitution may identify literals, so clause cardinality is not a safe
    # pruning bound (and equivalent clauses in the survey rely on this case).
    patterns = collect(left.literals)
    function search(position, environment)
        position > length(patterns) && return true
        pattern = patterns[position]
        for target in right.literals
            next = copy(environment)
            _match_literal(pattern, target, next) && search(position + 1, next) && return true
        end
        false
    end
    search(1, Dict{Variable,FirstOrderTerm}())
end
subsumes(left::HornClause, right::HornClause) = subsumes(left.clause, right.clause)
subsumes(left::Clause, right::HornClause) = subsumes(left, right.clause)
subsumes(left::HornClause, right::Clause) = subsumes(left.clause, right)

const theta_subsumes = subsumes
"""The ILP generality quasi-order, implemented by θ-subsumption (Muggleton & De Raedt, §5.2 [muggleton1994](@cite))."""
more_general(left, right) = subsumes(left, right)
more_specific(left, right) = subsumes(right, left)
function equivalent_under_subsumption(left, right)
    subsumes(left, right) && subsumes(right, left)
end

# Small, deliberately explicit lazy helpers for refinement operators.
struct _UniqueIterator{I}
    source::I
end
Base.IteratorSize(::Type{<:_UniqueIterator}) = Base.SizeUnknown()
function Base.iterate(iterator::_UniqueIterator, state=(Set{Any}(), nothing, false))
    seen, source_state, started = state
    while true
        next = started ? iterate(iterator.source, source_state) : iterate(iterator.source)
        next === nothing && return nothing
        item, source_state = next
        started = true
        item in seen && continue
        push!(seen, item)
        return item, (seen, source_state, started)
    end
end

function _proper_specialization(parent::Union{Clause,HornClause}, child::Union{Clause,HornClause})
    subsumes(parent, child) && !subsumes(child, parent)
end
function _proper_generalization(parent::Union{Clause,HornClause}, child::Union{Clause,HornClause})
    subsumes(child, parent) && !subsumes(parent, child)
end

# Refining a Horn clause must retain its invariant and type.  HornClause's
# constructor deliberately rejects an added positive head when one already
# exists, rather than silently widening the result to an ordinary Clause.
_refinement_candidate(parent::Clause, candidate::Clause) = candidate
_refinement_candidate(parent::HornClause, candidate::Clause) = HornClause(candidate)

function _fresh_variable(clause::Clause, index::Int)
    used = Set{Symbol}()
    for literal in clause
        for term in _clause_terms(literal.atom)
            term isa Variable && push!(used, term.name)
        end
    end
    candidate = Symbol("_G", index)
    while candidate in used
        index += 1
        candidate = Symbol("_G", index)
    end
    Variable(candidate)
end
function _clause_terms(atom::Predicate)
    Iterators.flatten((_term_tree(term) for term in atom.arguments))
end
function _clause_terms(atom::Equality)
    Iterators.flatten((_term_tree(term) for term in (atom.left, atom.right)))
end
_term_tree(term::Variable) = (term,)
_term_tree(term::Constant) = (term,)
function _term_tree(term::FunctionTerm)
    descendants = Iterators.flatten((_term_tree(argument) for argument in term.arguments))
    Iterators.flatten(((term,), descendants))
end

function _replace_term(term::Variable, target, replacement)
    isequal(term, target) ? replacement : term
end
_replace_term(term::Constant, target, replacement) = isequal(term, target) ? replacement : term
function _replace_term(term::FunctionTerm, target, replacement)
    isequal(term, target) ? replacement : FunctionTerm(term.name, tuple((_replace_term(argument, target, replacement) for argument in term.arguments)...))
end
function _replace_atom(atom::Predicate, target, replacement)
    Predicate(atom.name, tuple((_replace_term(term, target, replacement) for term in atom.arguments)...))
end
function _replace_atom(atom::Equality, target, replacement)
    Equality(_replace_term(atom.left, target, replacement), _replace_term(atom.right, target, replacement))
end
_replace_term(literal::Literal, target, replacement) = Literal(_replace_atom(literal.atom, target, replacement), literal.positive)

function _predicate_template(predicate)
    if predicate isa Literal || predicate isa Predicate || predicate isa Equality
        return _normalize_literal(predicate)
    elseif predicate isa Pair && predicate.second isa Integer
        name, arity = predicate.first, Int(predicate.second)
        arity >= 0 || throw(ArgumentError("predicate arity must be non-negative"))
        variables = tuple((Variable(Symbol("_A", i)) for i in 1:arity)...)
        return Literal(Predicate(name, variables))
    end
    throw(ArgumentError("predicates must contain atomic templates or name => arity pairs"))
end
function _predicate_templates(predicates)
    predicates === nothing && return ()
    if predicates isa AbstractArray || predicates isa AbstractSet || predicates isa Tuple
        return tuple((_predicate_template(predicate) for predicate in predicates)...)
    end
    (_predicate_template(predicate) for predicate in predicates)
end

"""Return a lazy stream of proper specializations under θ-subsumption.

The one-step operator applies supplied substitutions and/or adds one supplied
literal template, exactly the two operations described in Muggleton & De Raedt
(1994), §5.2.2. Finite `literals`/`predicates` and a finite substitution set
make this one-step space locally finite; iterable vocabularies are consumed
lazily, so an unbounded language can be sampled without materialization. A
`max_literals` bound applies to every emitted candidate, including substitutions;
it must be `nothing` or a non-negative integer. Refining a `HornClause` returns
`HornClause` values and rejects additions that would create a second positive
literal. The operator is sound and proper, but is not claimed complete or
optimal: it cannot generate literals outside the bias and does not perform
reduced-clause canonicalization.
"""
function downward_refinements(clause::Union{Clause,HornClause}; literals=nothing, predicates=nothing,
                              substitutions=nothing, max_literals=nothing)
    max_literals === nothing || (max_literals isa Integer && max_literals >= 0) ||
        throw(ArgumentError("max_literals must be nothing or a non-negative integer"))
    base = clause isa HornClause ? clause.clause : clause
    within_limit(candidate) = max_literals === nothing || length(candidate) <= max_literals
    can_keep = max_literals === nothing || length(base) <= max_literals
    can_add = max_literals === nothing || length(base) < max_literals
    # Candidate vocabularies are iterated, not collected: an unbounded language
    # bias can therefore be consumed with `Iterators.take`.
    templates = if literals === nothing
        _predicate_templates(predicates)
    elseif literals isa AbstractArray || literals isa AbstractSet || literals isa Tuple
        tuple((_normalize_literal(literal) for literal in literals)...)
    else
        (_normalize_literal(literal) for literal in literals)
    end
    collection_substitutions = substitutions isa AbstractArray || substitutions isa AbstractSet || substitutions isa Tuple
    if collection_substitutions
        substitutions_source = tuple((s isa Substitution ? s : Substitution(s) for s in substitutions)...)
        # Iterate a lazy literal stream outside the finite substitution tuple,
        # so a non-collection vocabulary is reusable for every supplied θ.
        base_candidates = can_keep ?
            (_refinement_candidate(clause, candidate) for candidate in
             (substitute(base, substitution) for substitution in substitutions_source)
             if within_limit(candidate)) : ()
        per_template = can_add ?
            ((_refinement_candidate(clause, candidate) for candidate in
              (Clause((substitute(base, substitution).literals..., template)) for substitution in substitutions_source)
              if within_limit(candidate)) for template in templates) : ()
        source = Iterators.flatten((base_candidates, Iterators.flatten(per_template)))
    else
        substitutions_source = substitutions === nothing ? (Substitution(),) :
            (substitutions isa Substitution ? (substitutions,) :
             substitutions isa AbstractDict ? (Substitution(substitutions),) :
             (s isa Substitution ? s : Substitution(s) for s in substitutions))
        per_substitution = (
            Iterators.flatten((
                can_keep ?
                    (_refinement_candidate(clause, candidate) for candidate in
                     (substitute(base, substitution),) if within_limit(candidate)) : (),
                can_add ?
                    (_refinement_candidate(clause, candidate) for candidate in
                     (Clause((substitute(base, substitution).literals..., template)) for template in templates)
                     if within_limit(candidate)) : ()
            )) for substitution in substitutions_source)
        source = Iterators.flatten(per_substitution)
    end
    _UniqueIterator(Iterators.filter(candidate -> _proper_specialization(clause, candidate), source))
end

"""Return a lazy stream of proper generalizations under θ-subsumption.

This operator deletes one literal and replaces one non-variable subterm by a
fresh variable. It is sound, proper, locally finite for a finite clause, and
intentionally incomplete: no complete generalization operator exists for full
clausal logic without a language bias because θ-subsumption has infinite
chains (Muggleton & De Raedt (1994), §5.2.2).
"""
function upward_refinements(clause::Union{Clause,HornClause})
    base = clause isa HornClause ? clause.clause : clause
    deletions = (Clause(tuple((base.literals[j] for j in eachindex(base.literals) if j != i)...)) for i in eachindex(base.literals))
    terms = Any[]
    for literal in base
        for term in _clause_terms(literal.atom)
            term isa Variable || any(existing -> isequal(existing, term), terms) || push!(terms, term)
        end
    end
    generalizations = (Clause(tuple((_replace_term(literal, term, _fresh_variable(base, i))
                                   for literal in base)...)) for (i, term) in enumerate(terms))
    _UniqueIterator(Iterators.filter(candidate -> _proper_generalization(base, candidate),
        Iterators.flatten((deletions, generalizations))))
end

const downward_refinement = downward_refinements
const upward_refinement = upward_refinements
const specializations = downward_refinements
const generalizations = upward_refinements

"""Return whether a clause is a Horn clause (Muggleton & De Raedt, §3.2 [muggleton1994](@cite))."""
ishorn(clause::Clause) = count(literal -> literal.positive, clause.literals) <= 1
ishorn(::HornClause) = true

abstract type ILPExample end
"""An example in learning from entailment: a query and its positive/negative label
(Muggleton & De Raedt, §3 [muggleton1994](@cite))."""
struct EntailmentExample{E} <: ILPExample
    example::E
    positive::Bool
end
EntailmentExample(example; positive=true) = EntailmentExample(example, Bool(positive))
"""An example in learning from interpretations: an interpretation and its label
(Muggleton & De Raedt, §3 [muggleton1994](@cite))."""
struct InterpretationExample{I} <: ILPExample
    interpretation::I
    positive::Bool
end
InterpretationExample(interpretation; positive=true) = InterpretationExample(interpretation, Bool(positive))
"""An example in learning from proofs: a proof object and its label
(Muggleton & De Raedt, §5 [muggleton1994](@cite))."""
struct ProofExample{P} <: ILPExample
    proof::P
    positive::Bool
end
ProofExample(proof; positive=true) = ProofExample(proof, Bool(positive))
"""Construct an example for learning from entailment [muggleton1994](@cite)."""
learning_from_entailment(example; positive=true) = EntailmentExample(example; positive=positive)
"""Construct a modal `Model` example for learning from interpretations [muggleton1994](@cite).

The named learning-setting constructor intentionally follows [`interpretation_example`](@ref)
and rejects first-order adapters; callers with another interpretation type can use
[`InterpretationExample`](@ref) directly.
"""
learning_from_interpretations(example; positive=true) = interpretation_example(example; positive=positive)
"""Construct an example for learning from proofs [muggleton1994](@cite)."""
learning_from_proofs(example; positive=true) = ProofExample(example; positive=positive)

"""Present a Kripke `Model` directly as an interpretation example.

Aletheia's `Model` is an interpretation (a frame plus valuation), so this is
the concrete bridge to learning from interpretations. Boolean modal models can
also be converted to first-order interpretations with `first_order_interpretation`.
The setting follows Muggleton & De Raedt, §3 [muggleton1994](@cite).
"""
function interpretation_example(model::Model; positive=true)
    InterpretationExample(model; positive=positive)
end
interpretation_example(other; positive=true) =
    throw(ArgumentError("learning from interpretations expects a modal Model, got $(typeof(other))"))
model_example(model::Model; positive=true) = interpretation_example(model; positive=positive)

Base.show(io::IO, sub::Substitution) =
    print(io, "Substitution(", join(["$(p.first) => $(p.second)" for p in sub.bindings], ", "), ")")

function Base.show(io::IO, ::MIME"text/plain", sub::Substitution)
    _styled(io, "Substitution", _DISPLAY_HEAD; bold=true)
    print(io, ": {")
    shown, elided = _display_bounded(io, sub.bindings, DISPLAY_ITEMS)
    print(io, join(["$(p.first) ↦ $(p.second)" for p in shown], ", "))
    _display_elision(io, elided)
    print(io, "}")
end

Base.show(io::IO, ex::EntailmentExample) =
    print(io, "EntailmentExample(", ex.positive ? "+" : "-", ", ", ex.example, ")")

function Base.show(io::IO, ::MIME"text/plain", ex::EntailmentExample)
    _display_header(io, "EntailmentExample", ex.positive ? "+" : "-")
    print(io, ": ", ex.example)
end

Base.show(io::IO, ex::InterpretationExample) =
    print(io, "InterpretationExample(", ex.positive ? "+" : "-", ", ", ex.interpretation, ")")

function Base.show(io::IO, ::MIME"text/plain", ex::InterpretationExample)
    _display_header(io, "InterpretationExample", ex.positive ? "+" : "-")
    print(io, ": ", ex.interpretation)
end

Base.show(io::IO, ex::ProofExample) =
    print(io, "ProofExample(", ex.positive ? "+" : "-", ", ", ex.proof, ")")

function Base.show(io::IO, ::MIME"text/plain", ex::ProofExample)
    _display_header(io, "ProofExample", ex.positive ? "+" : "-")
    print(io, ": ", ex.proof)
end

