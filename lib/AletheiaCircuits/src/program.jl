abstract type AbstractChoiceVariable end

"""A primitive finite choice with mutually exclusive alternatives."""
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
other finite ground value.

# Examples
```jldoctest
julia> using AletheiaCircuits

julia> ChoiceVariable(:c1, (:a, :b), (0.4, 0.6))
ChoiceVariable{Symbol, Tuple{Symbol, Symbol}, Tuple{Float64, Float64}}(:c1, (:a, :b), (0.4, 0.6))
```
"""
function ChoiceVariable(id, alternatives, weights)
    a = alternatives isa Tuple ? alternatives : tuple(alternatives...)
    w = weights isa Tuple ? weights : tuple(weights...)
    _validate_choice(id, a, w)
    return ChoiceVariable{typeof(id),typeof(a),typeof(w)}(id, a, w)
end
ChoiceVariable(id, alternatives; weights) = ChoiceVariable(id, alternatives, weights)

alternatives(choice::ChoiceVariable) = choice.alternatives
weights(choice::ChoiceVariable) = choice.weights
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
end

function _body_tuple(body)
    body === nothing && return ()
    body isa Tuple && return body
    body isa AbstractVector && return tuple(body...)
    return (body,)
end
GroundRule(head) = GroundRule(head, ())
GroundRule(head, body::AbstractVector) = GroundRule(head, tuple(body...))
GroundRule(head, body) = GroundRule(head, _body_tuple(body))
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
struct EventAnd{T<:Tuple}
    children::T
end
struct EventOr{T<:Tuple}
    children::T
end
Not(value) = EventNot(value)
function And(values...)
    xs = length(values) == 1 && values[1] isa Tuple ? values[1] : values
    return EventAnd(tuple(xs...))
end
function Or(values...)
    xs = length(values) == 1 && values[1] isa Tuple ? values[1] : values
    return EventOr(tuple(xs...))
end
not_event(value) = Not(value)
and_event(values...) = And(values...)
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

choices(program::DSProgram) = program.choices
facts(program::DSProgram) = program.facts
rules(program::DSProgram) = program.rules
domain(program::DSProgram) = program.domain

# The alias keeps `world` lightweight while documenting its contract in the API.
const DSWorld = Set{Any}

function _first_feature(values)
    for value in values
        feature = _contains_feature(value)
        feature === nothing || return feature
    end
    return nothing
end

function _contains_feature(value)
    value isa AletheiaCore.FunctionTerm && return :function_symbols
    value isa AletheiaCore.Variable && return :variables
    value isa AletheiaCore.Predicate && return _first_feature(value.arguments)
    value isa AletheiaCore.Equality && return _first_feature((value.left, value.right))
    value isa Union{
        AletheiaCore.FONegation,
        AletheiaCore.FOConjunction,
        AletheiaCore.FODisjunction,
        AletheiaCore.FOImplication,
        AletheiaCore.Exists,
        AletheiaCore.Forall,
    } && return :first_order_formulas
    value isa AletheiaCore.Constant && return _contains_feature(value.value)
    value isa EventNot && return _contains_feature(value.child)
    value isa EventAnd && return _first_feature(value.children)
    value isa EventOr && return _first_feature(value.children)
    value isa Pair && return _first_feature((value.first, value.second))
    value isa NamedTuple && return _first_feature(values(value))
    value isa Tuple && return _first_feature(value)
    value isa AbstractArray && return _first_feature(value)
    return nothing
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
        rule.head isa Union{EventNot,EventAnd,EventOr,Tuple,Bool} &&
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

"""Enumerate total choices as dictionaries from choice identifiers to outcomes."""
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

"""Return the product weight of a primitive total choice."""
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
