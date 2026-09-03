"""
The abstract supertype for finite primitive choices.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractChoiceVariable isa Type
true
```
"""
abstract type AbstractChoiceVariable end

"""Create a normalized finite choice variable.

The alternatives are mutually exclusive outcomes and `weights` are their
probabilities.  The alternatives may be atoms, `nothing` (no atom), or any
other finite ground value except `Bool`, which is reserved for event constants.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))
ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6))
```
"""
struct ChoiceVariable{I,A<:Tuple,W<:Tuple} <: AbstractChoiceVariable
    id::I
    alternatives::A
    weights::W
    function ChoiceVariable{I,A,W}(
        id::I, alternatives::A, weights::W
    ) where {I,A<:Tuple,W<:Tuple}
        _validate_choice(id, alternatives, weights)
        return new{I,A,W}(id, alternatives, weights)
    end
end

function _weight_is_valid(weight)
    weight isa Real || return false
    return isfinite(weight) && weight >= zero(weight)
end

function _validate_choice(id, alternatives, weights)
    # Route public choice values through the common finite-ground validator before
    # equality or arithmetic checks, so recursive values fail closed.
    _validate_ground(id, "choice identifier")
    for alternative in alternatives
        _validate_ground(alternative, "choice alternative")
    end
    isempty(alternatives) && throw(
        ProgramValidationError(
            :nonempty_alternatives, "choice variables need at least one alternative"
        ),
    )
    length(alternatives) == length(weights) || throw(
        ProgramValidationError(
            :matching_weights, "each alternative needs exactly one weight"
        ),
    )
    any(alternative isa Bool for alternative in alternatives) && throw(
        UnsupportedFeatureError(
            :boolean_choice_alternatives,
            "Bool values are reserved for two-valued event constants; use named atoms instead",
        ),
    )
    any(
        !isnothing(findfirst(i -> isequal(alternatives[i], alternatives[j]), 1:(j - 1))) for
        j in eachindex(alternatives)
    ) &&
        throw(ProgramValidationError(:unique_alternatives, "alternatives must be distinct"))
    all(_weight_is_valid, weights) || throw(
        InvalidProbabilityError(
            :nonnegative_finite,
            "choice weights must be finite nonnegative real numbers",
        ),
    )
    total = sum(weights; init=zero(first(weights)))
    normalized = if total isa AbstractFloat
        isapprox(total, one(total); atol=eps(total) * 8, rtol=eps(total) * 8)
    else
        total == one(total)
    end
    normalized || throw(
        UnnormalizedWeightsError(
            id, total, "normalize alternatives before constructing the program"
        ),
    )
    return nothing
end

"""Create a normalized finite choice variable.

The alternatives are mutually exclusive outcomes and `weights` are their
probabilities.  The alternatives may be atoms, `nothing` (no atom), or any
other finite ground value except `Bool`, which is reserved for event constants.
"""
function ChoiceVariable(id, alternatives, weights)
    a = alternatives isa Tuple ? alternatives : tuple(alternatives...)
    w = weights isa Tuple ? weights : tuple(weights...)
    _validate_choice(id, a, w)
    return ChoiceVariable{typeof(id),typeof(a),typeof(w)}(id, a, w)
end
ChoiceVariable(id, alternatives; weights) = ChoiceVariable(id, alternatives, weights)

"""
Return the alternatives of a choice variable.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> alternatives(c)
(:a, :b)
```
"""
alternatives(choice::ChoiceVariable) = choice.alternatives
"""
Return the normalized outcome weights of a choice variable.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> weights(c)
(0.4, 0.6)
```
"""
weights(choice::ChoiceVariable) = choice.weights
"""
Return a choice variable's stable identifier.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> choice_id(c)
:c1
```
"""
choice_id(choice::ChoiceVariable) = choice.id
Base.length(choice::ChoiceVariable) = length(choice.alternatives)
Base.iterate(choice::ChoiceVariable, state...) = iterate(choice.alternatives, state...)

"""An alternative of a finite choice, used as a circuit literal target.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> ChoiceAlternative(c, 1)
ChoiceAlternative{ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}}(ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6)), 1)
```
"""
struct ChoiceAlternative{V}
    variable::V
    index::Int
    function ChoiceAlternative(variable, index::Integer)
        index > 0 ||
            throw(ProgramValidationError(:choice_index, "alternative indices start at one"))
        return new{typeof(variable)}(variable, Int(index))
    end
end

"""A signed primitive choice literal.  Positive literals select one outcome.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> c = ChoiceVariable(:c1, (:a, :b), (0.4, 0.6));

julia> ChoiceLiteral(c, 1)
ChoiceLiteral{ChoiceAlternative{ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}}}(ChoiceAlternative{ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}}(ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6)), 1), true)
```
"""
struct ChoiceLiteral{V}
    variable::V
    polarity::Bool
end
function ChoiceLiteral(variable, index::Integer)
    return ChoiceLiteral(ChoiceAlternative(variable, index), true)
end

"""A probabilistic fact, expanded to an independent two-outcome choice.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> ProbabilisticFact(:a, 0.3)
ProbabilisticFact{Symbol, Float64}(:a, 0.3)
```
"""
struct ProbabilisticFact{A,P}
    atom::A
    probability::P
    function ProbabilisticFact(atom, probability)
        _validate_ground(atom, "probabilistic fact")
        _weight_is_valid(probability) && probability <= one(probability) || throw(
            InvalidProbabilityError(
                :unit_interval, "a probabilistic fact probability must lie in [0, 1]"
            ),
        )
        return new{typeof(atom),typeof(probability)}(atom, probability)
    end
end
ProbabilisticFact(atom; probability) = ProbabilisticFact(atom, probability)

"""A finite ground rule, read as `head :- body[1], ..., body[end]`.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> GroundRule(:a, (:b, :c))
GroundRule{Symbol, Tuple{Symbol, Symbol}}(:a, (:b, :c))
```
"""
struct GroundRule{H,B<:Tuple}
    head::H
    body::B
    function GroundRule{H,B}(head::H, body::B) where {H,B<:Tuple}
        _validate_ground(head, "rule head")
        _validate_ground(body, "rule body")
        return new{H,B}(head, body)
    end
end

function _body_tuple(body)
    body === nothing && return ()
    body isa Tuple && return body
    body isa AbstractVector && return tuple(body...)
    return (body,)
end
function GroundRule(head, body)
    body_tuple = _body_tuple(body)
    return GroundRule{typeof(head),typeof(body_tuple)}(head, body_tuple)
end
GroundRule(head) = GroundRule(head, ())
GroundRule(head, body::AbstractVector) = GroundRule(head, tuple(body...))
GroundRule(head, first, rest...) = GroundRule(head, (first, rest...))

"""Conjunction and disjunction are explicit event expressions for queries.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> EventNot(:a)
EventNot{Symbol}(:a)
```
"""
struct EventNot{T}
    child::T
end
"""
An event expression that conjoins child expressions.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> EventAnd((:a, :b))
EventAnd{Tuple{Symbol, Symbol}}((:a, :b))
```
"""
struct EventAnd{T<:Tuple}
    children::T
end
"""
An event expression that disjoins child expressions.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> EventOr((:a, :b))
EventOr{Tuple{Symbol, Symbol}}((:a, :b))
```
"""
struct EventOr{T<:Tuple}
    children::T
end
"""
Create a negated event expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> Not(:a)
EventNot{Symbol}(:a)
```
"""
Not(value) = EventNot(value)
"""
Create a conjunction event expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> And(:a, :b)
EventAnd{Tuple{Symbol, Symbol}}((:a, :b))
```
"""
function And(values...)
    xs = length(values) == 1 && values[1] isa Tuple ? values[1] : values
    return EventAnd(tuple(xs...))
end
"""
Create a disjunction event expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> Or(:a, :b)
EventOr{Tuple{Symbol, Symbol}}((:a, :b))
```
"""
function Or(values...)
    xs = length(values) == 1 && values[1] isa Tuple ? values[1] : values
    return EventOr(tuple(xs...))
end
"""
Create a negated event expression through the named helper.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> not_event(:a)
EventNot{Symbol}(:a)
```
"""
not_event(value) = Not(value)
"""
Create a conjunction event expression through the named helper.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> and_event(:a, :b)
EventAnd{Tuple{Symbol, Symbol}}((:a, :b))
```
"""
and_event(values...) = And(values...)
"""
Create a disjunction event expression through the named helper.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> or_event(:a, :b)
EventOr{Tuple{Symbol, Symbol}}((:a, :b))
```
"""
or_event(values...) = Or(values...)

"""A finite, function-free, acyclic distribution-semantics profile.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> DSProfile()
DSProfile(true, true, true, false)
```
"""
struct DSProfile
    function_free::Bool
    acyclic::Bool
    finite::Bool
    locally_stratified::Bool
end
function DSProfile(;
    function_free=true, acyclic=true, finite=true, locally_stratified=false
)
    return DSProfile(function_free, acyclic, finite, locally_stratified)
end

"""A query and optional evidence expression.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> DSQuery(:a; evidence=:b)
DSQuery{Symbol, Symbol}(:a, :b)
```
"""
struct DSQuery{Q,E}
    query::Q
    evidence::E
end
DSQuery(query; evidence=nothing) = DSQuery{typeof(query),typeof(evidence)}(query, evidence)

"""
The abstract supertype for distribution-semantics programs.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> AbstractDSProgram isa Type
true
```
"""
abstract type AbstractDSProgram end

"""A finite distribution-semantics program.

`choices` are independent normalized alternatives, `facts` are retained as
source records, and `rules` are already ground.  Probabilistic facts passed in
`choices` or through `probabilistic_facts` are expanded into choices.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))])
DSProgram{Tuple{ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}}, Tuple{}, Tuple{}, Tuple{}}((ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6)),), (), (), ())
```
"""
struct DSProgram{C,F,R,D} <: AbstractDSProgram
    choices::C
    facts::F
    rules::R
    domain::D
end

function _as_entries(x)
    return if x === nothing
        ()
    elseif x isa Tuple
        x
    elseif x isa AbstractVector
        tuple(x...)
    else
        (x,)
    end
end
_fact_choice_id(atom) = (:probabilistic_fact, atom)

function _program_entries(entries, probabilistic_facts)
    all_entries = (_as_entries(entries)..., _as_entries(probabilistic_facts)...)
    choices = ChoiceVariable[]
    facts = ProbabilisticFact[]
    for entry in all_entries
        if entry isa ProbabilisticFact
            push!(facts, entry)
            push!(
                choices,
                ChoiceVariable(
                    _fact_choice_id(entry.atom),
                    (entry.atom, nothing),
                    (entry.probability, one(entry.probability) - entry.probability),
                ),
            )
        elseif entry isa ChoiceVariable
            push!(choices, entry)
        else
            throw(
                ProgramValidationError(
                    :choice_variable,
                    "expected ChoiceVariable or ProbabilisticFact, got $(typeof(entry))",
                ),
            )
        end
    end
    return tuple(choices...), tuple(facts...)
end

function DSProgram(
    entries=(); rules=(), domain=(), probabilistic_facts=(), facts=(), choices=nothing
)
    source = choices === nothing ? entries : choices
    all_facts = (_as_entries(probabilistic_facts)..., _as_entries(facts)...)
    cs, fs = _program_entries(source, all_facts)
    rs = tuple((_as_entries(rules))...)
    ds = if domain isa Tuple
        domain
    elseif domain isa AbstractVector
        tuple(domain...)
    else
        (domain,)
    end
    return DSProgram{typeof(cs),typeof(fs),typeof(rs),typeof(ds)}(cs, fs, rs, ds)
end
DSProgram(entries, rules, domain) = DSProgram(entries; rules=rules, domain=domain)
function DSProgram(entries, rules; domain=(), probabilistic_facts=(), facts=())
    return DSProgram(
        entries;
        rules=rules,
        domain=domain,
        probabilistic_facts=probabilistic_facts,
        facts=facts,
    )
end

"""
Return the independent primitive choices in a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> choices(prog)
(ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6)),)
```
"""
choices(program::DSProgram) = program.choices
"""
Return the source probabilistic facts in a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(probabilistic_facts=[ProbabilisticFact(:f1, 0.3)]);

julia> facts(prog)
(ProbabilisticFact{Symbol, Float64}(:f1, 0.3),)
```
"""
facts(program::DSProgram) = program.facts
"""
Return the ground rules in a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(rules=[GroundRule(:a, (:b,))]);

julia> rules(prog)
(GroundRule{Symbol, Tuple{Symbol}}(:a, (:b,)),)
```
"""
rules(program::DSProgram) = program.rules
"""
Return the finite domain tuple carried by a program.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(domain=(:a, :b));

julia> domain(prog)
(:a, :b)
```
"""
domain(program::DSProgram) = program.domain

# The alias keeps `world` lightweight while documenting its contract in the API.
"""
A two-valued finite world represented by its true ground atoms.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> DSWorld isa Type
true
```
"""
const DSWorld = Set{Any}

function _first_feature(values, seen=IdDict{Any,Bool}())
    for value in values
        feature = _contains_feature(value, seen)
        feature === nothing || return feature
    end
    return nothing
end

function _contains_feature(value, seen=IdDict{Any,Bool}())
    value isa AletheiaCore.FunctionTerm && return :function_symbols
    value isa AletheiaCore.Variable && return :variables
    value isa AletheiaCore.Predicate && return _first_feature(value.arguments, seen)
    value isa AletheiaCore.Equality && return _first_feature((value.left, value.right), seen)
    value isa Union{
        AletheiaCore.FONegation,
        AletheiaCore.FOConjunction,
        AletheiaCore.FODisjunction,
        AletheiaCore.FOImplication,
        AletheiaCore.Exists,
        AletheiaCore.Forall,
    } && return :first_order_formulas
    value isa AletheiaCore.Constant && return _contains_feature(value.value, seen)
    value isa EventNot && return _contains_feature(value.child, seen)
    value isa EventAnd && return _first_feature(value.children, seen)
    value isa EventOr && return _first_feature(value.children, seen)
    value isa Pair && return _first_feature((value.first, value.second), seen)
    value isa NamedTuple && return _first_feature(values(value), seen)
    value isa Tuple && return _first_feature(value, seen)
    value isa AbstractArray || value isa AbstractSet || value isa AbstractDict || return nothing
    haskey(seen, value) && return nothing
    seen[value] = true
    feature = if value isa AbstractDict
        _first_feature((pair for pair in value), seen)
    else
        _first_feature(value, seen)
    end
    delete!(seen, value)
    return feature
end

function _expression_atoms(expression)
    expression isa EventNot && return _expression_atoms(expression.child)
    expression isa EventAnd &&
        return reduce(vcat, (_expression_atoms(v) for v in expression.children); init=Any[])
    expression isa EventOr &&
        return reduce(vcat, (_expression_atoms(v) for v in expression.children); init=Any[])
    expression isa Tuple &&
        return reduce(vcat, (_expression_atoms(v) for v in expression); init=Any[])
    expression isa Bool && return Any[]
    return [expression]
end

function _validate_profile(profile::DSProfile)
    profile.function_free || throw(
        UnsupportedFeatureError(:function_symbols, "the finite core is function-free")
    )
    profile.acyclic || throw(
        UnsupportedFeatureError(:cycles, "the finite core accepts only acyclic rules")
    )
    profile.finite || throw(
        UnsupportedFeatureError(
            :infinite_domains, "the finite core requires a finite domain"
        ),
    )
    profile.locally_stratified && throw(
        UnsupportedFeatureError(
            :locally_stratified_programs,
            "only the strictly acyclic profile is implemented",
        ),
    )
    return nothing
end

function _ground_value(value, seen=IdDict{Any,Bool}())
    value === nothing && return true
    value isa Union{Bool,Symbol,Char,AbstractString,Number,Missing} && return true
    value isa Function && return false
    value isa AletheiaCore.Constant && return _ground_value(value.value, seen)
    value isa Union{EventNot,EventAnd,EventOr} && return _ground_value(
        value isa EventNot ? value.child : value.children, seen
    )
    value isa Pair && return _ground_value(value.first, seen) && _ground_value(value.second, seen)
    value isa Tuple && return all(x -> _ground_value(x, seen), value)
    value isa NamedTuple && return all(x -> _ground_value(x, seen), values(value))
    value isa AbstractArray || value isa AbstractSet || value isa AbstractDict || return false
    # Mutable containers are tracked while descending. A revisit before the
    # container is removed is a cycle, not a finite shared subvalue.
    haskey(seen, value) && return false
    seen[value] = true
    valid = try
        if value isa AbstractDict
            all(_ground_value(k, seen) && _ground_value(v, seen) for (k, v) in value)
        else
            all(_ground_value(x, seen) for x in value)
        end
    finally
        delete!(seen, value)
    end
    return valid
end

function _validate_ground(value, context)
    feature = _contains_feature(value)
    feature === :function_symbols && throw(
        UnsupportedFeatureError(
            :function_symbols,
            "function symbols are outside the finite ground fragment ($(context))",
        ),
    )
    feature === :variables && throw(
        GroundingError(
            :ground_terms,
            "variables require a grounding phase and are not accepted in $(context)",
        ),
    )
    feature === :first_order_formulas && throw(
        UnsupportedFeatureError(
            :first_order_formulas,
            "the finite event language uses atoms and explicit Not, And, and Or expressions ($(context))",
        ),
    )
    _ground_value(value) || throw(
        UnsupportedFeatureError(
            :ground_values,
            "$(context) must be a finite ground value: nothing, Bool, Symbol, Char, string, number, or finite tuple/record/collection",
        ),
    )
    return nothing
end

function _body_dependencies(expression, result=Any[])
    if expression isa EventNot
        _body_dependencies(expression.child, result)
    elseif expression isa EventAnd
        for child in expression.children
            _body_dependencies(child, result)
        end
    elseif expression isa EventOr
        for child in expression.children
            _body_dependencies(child, result)
        end
    elseif expression isa Tuple
        for child in expression
            _body_dependencies(child, result)
        end
    elseif !(expression isa Bool)
        push!(result, expression)
    end
    return result
end

function _check_acyclic(program::DSProgram)
    heads = [rule.head for rule in program.rules]
    dependencies = [unique(_body_dependencies(rule.body)) for rule in program.rules]
    graph = Dict{Any,Vector{Any}}()
    for (head, deps) in zip(heads, dependencies)
        graph[head] = get(graph, head, Any[])
        for dep in deps
            haskey(graph, dep) || (graph[dep] = Any[])
            push!(graph[dep], head)
        end
    end
    state = Dict{Any,UInt8}()
    function visit(node)
        mark = get(state, node, UInt8(0))
        mark == 1 && throw(
            ProgramValidationError(
                :acyclic_rules, "rule dependency cycle reaches $(repr(node))"
            ),
        )
        mark == 2 && return nothing
        state[node] = 1
        for next in get(graph, node, Any[])
            visit(next)
        end
        return state[node] = 2
    end
    for node in keys(graph)
        visit(node)
    end
    return nothing
end

"""Validate the exact finite, function-free, acyclic program contract.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> validate_program(prog) === nothing
true
```
"""
function validate_program(program::DSProgram, profile::DSProfile=DSProfile())
    _validate_profile(profile)
    ids = Any[]
    for choice in program.choices
        _validate_ground(choice.id, "choice identifier")
        _validate_ground(choice.alternatives, "choice alternatives")
        any(isequal(choice.id, old) for old in ids) && throw(
            ProgramValidationError(:unique_choice_ids, "choice identifiers must be unique"),
        )
        push!(ids, choice.id)
        _validate_choice(choice.id, choice.alternatives, choice.weights)
    end
    for fact in program.facts
        _validate_ground(fact.atom, "probabilistic fact")
    end
    for rule in program.rules
        rule isa GroundRule ||
            throw(GroundingError(:ground_rules, "rules must be GroundRule values"))
        _validate_ground(rule.head, "rule head")
        _validate_ground(rule.body, "rule body")
        rule.head isa Union{EventNot,EventAnd,EventOr,Tuple,Bool,Nothing} &&
            throw(GroundingError(:ground_rule_head, "a rule head must be one ground atom"))
    end
    _validate_ground(program.domain, "program domain")
    _check_acyclic(program)
    return nothing
end
function validate_program(program::AbstractDSProgram, profile::DSProfile=DSProfile())
    return throw(
        ProgramValidationError(:program_type, "expected DSProgram, got $(typeof(program))")
    )
end

"""Ground and validate a finite program.  Ground rules are returned unchanged.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> ground(prog, :a) === prog
true
```
"""
function ground(program::DSProgram, query=nothing; profile::DSProfile=DSProfile())
    validate_program(program, profile)
    query === nothing || _validate_ground(query, "query")
    return program
end
function ground(program::DSProgram, query::DSQuery; profile::DSProfile=DSProfile())
    ground(program, query.query; profile=profile)
    query.evidence === nothing || _validate_ground(query.evidence, "evidence")
    return program
end
function ground(program::DSProgram, query, profile::DSProfile)
    return ground(program, query; profile=profile)
end

function _choice_index(choice::ChoiceVariable, selected)
    if selected isa Integer && 1 <= selected <= length(choice)
        # A generated total choice carries alternative values; integer values are
        # values first when they occur among alternatives, and indices otherwise.
        found = findfirst(x -> isequal(x, selected), choice.alternatives)
        found !== nothing && return found
        return Int(selected)
    end
    found = findfirst(x -> isequal(x, selected), choice.alternatives)
    found === nothing && throw(
        GroundingError(
            :total_choice,
            "selection $(repr(selected)) is not an alternative of $(repr(choice.id))",
        ),
    )
    return found
end

function _assignment(program::DSProgram, total_choice)
    n = length(program.choices)
    if total_choice isa AbstractVector || total_choice isa Tuple
        length(total_choice) == n || throw(
            GroundingError(
                :total_choice,
                "a positional total choice must select every primitive variable",
            ),
        )
        return [
            _choice_index(c, selected) for
            (selected, c) in zip(total_choice, program.choices)
        ]
    elseif total_choice isa AbstractDict
        return [
            _choice_index(
                c,
                if haskey(total_choice, c.id)
                    total_choice[c.id]
                elseif haskey(total_choice, c)
                    total_choice[c]
                else
                    throw(
                    GroundingError(:total_choice, "missing selection for $(repr(c.id))")
                )
                end,
            ) for c in program.choices
        ]
    else
        throw(
            GroundingError(
                :total_choice, "expected a vector, tuple, or dictionary of selections"
            ),
        )
    end
end

function _expression_value(expression, atoms::Set{Any})
    expression isa Bool && return expression
    # A tuple present as a whole world value is an atom; absent tuples retain
    # their explicit conjunction syntax.
    expression isa Tuple && expression in atoms && return true
    expression isa EventNot && return !_expression_value(expression.child, atoms)
    expression isa EventAnd &&
        return all(_expression_value(v, atoms) for v in expression.children)
    expression isa EventOr &&
        return any(_expression_value(v, atoms) for v in expression.children)
    expression isa Tuple && return all(_expression_value(v, atoms) for v in expression)
    expression === nothing && return false
    return expression in atoms
end

"""Return the two-valued consequences of one primitive total choice.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> world(prog, Dict(:c1 => :a))
Set{Any} with 1 element:
  :a
```
"""
function world(program::DSProgram, total_choice)
    validate_program(program)
    assignment = _assignment(program, total_choice)
    atoms = Set{Any}()
    for (choice, index) in zip(program.choices, assignment)
        selected = choice.alternatives[index]
        selected === nothing || selected === false || push!(atoms, selected)
    end
    changed = true
    while changed
        changed = false
        for rule in program.rules
            if !(rule.head in atoms) && _expression_value(rule.body, atoms)
                push!(atoms, rule.head)
                changed = true
            end
        end
    end
    return atoms
end

"""
Return all finite primitive total choices.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> total_choices(prog)
2-element Vector{Dict{Any, Any}}:
 Dict(:c1 => :a)
 Dict(:c1 => :b)
```
"""
function total_choices(program::DSProgram)
    validate_program(program)
    result = Vector{Dict{Any,Any}}()
    function visit(i, selected)
        if i > length(program.choices)
            push!(result, copy(selected))
            return nothing
        end
        choice = program.choices[i]
        for alternative in choice.alternatives
            selected[choice.id] = alternative
            visit(i + 1, selected)
        end
        return delete!(selected, choice.id)
    end
    visit(1, Dict{Any,Any}())
    return result
end

"""
Return the product probability of one total choice.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> prog = DSProgram(choices=[ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))]);

julia> choice_probability(prog, Dict(:c1 => :a))
0.4
```
"""
function choice_probability(program::DSProgram, total_choice; T=nothing)
    validate_program(program)
    assignment = _assignment(program, total_choice)
    raw = [choice.weights[i] for (choice, i) in zip(program.choices, assignment)]
    type_ = T === nothing ? (isempty(raw) ? Float64 : promote_type(map(typeof, raw)...)) : T
    value = one(type_)
    for weight in raw
        value *= convert(type_, weight)
    end
    return value
end

function _atom_alternatives(program::DSProgram, atom)
    result = Tuple{Int,Int}[]
    for (i, choice) in enumerate(program.choices)
        for (j, alternative) in enumerate(choice.alternatives)
            isequal(atom, alternative) && push!(result, (i, j))
        end
    end
    return result
end

function world(program::AbstractDSProgram, total_choice)
    return throw(
        ProgramValidationError(:program_type, "expected DSProgram, got $(typeof(program))")
    )
end
