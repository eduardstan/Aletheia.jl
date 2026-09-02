# A small first-order target language and the standard translation of modal formulas.
# The target is intentionally syntax-only; `evaluate` is a reference interpreter for tests
# and examples, not a theorem prover.  Standard translation follows BDV §2.4.

abstract type FirstOrderTerm end
struct Variable <: FirstOrderTerm
    name::Symbol
end
Variable(name::AbstractString) = Variable(Symbol(name))

struct Constant <: FirstOrderTerm
    value::Any
end

"""A first-order function term. Function symbols are uninterpreted syntax here;
function symbols are part of the clause language in Muggleton & De Raedt, §5.2
[muggleton1994](@cite)."""
struct FunctionTerm <: FirstOrderTerm
    name::Any
    arguments::Tuple{Vararg{FirstOrderTerm}}
end
FunctionTerm(name, arguments::AbstractVector) = FunctionTerm(name, tuple(arguments...))
FunctionTerm(name, arguments::FirstOrderTerm...) = FunctionTerm(name, arguments)
const FOFunction = FunctionTerm
const CompoundTerm = FunctionTerm

abstract type FirstOrderFormula end
struct Predicate <: FirstOrderFormula
    name::Any
    arguments::Tuple{Vararg{FirstOrderTerm}}
end
Predicate(name, arguments::AbstractVector) = Predicate(name, tuple(arguments...))
Predicate(name, arguments::FirstOrderTerm...) = Predicate(name, arguments)
struct Equality <: FirstOrderFormula
    left::FirstOrderTerm
    right::FirstOrderTerm
end
struct FONegation <: FirstOrderFormula
    child::FirstOrderFormula
end
struct FOConjunction <: FirstOrderFormula
    left::FirstOrderFormula
    right::FirstOrderFormula
end
struct FODisjunction <: FirstOrderFormula
    left::FirstOrderFormula
    right::FirstOrderFormula
end
struct FOImplication <: FirstOrderFormula
    left::FirstOrderFormula
    right::FirstOrderFormula
end
struct Exists <: FirstOrderFormula
    variable::Variable
    body::FirstOrderFormula
end
struct Forall <: FirstOrderFormula
    variable::Variable
    body::FirstOrderFormula
end

const FOTerm = FirstOrderTerm
const FOFormula = FirstOrderFormula
const FOVariable = Variable
const FOConstant = Constant
const FOAtom = Predicate
const FOPredicate = Predicate
const FOEquality = Equality
const FONot = FONegation
const FOAnd = FOConjunction
const FOOr = FODisjunction
const FOImplies = FOImplication
const FOExists = Exists
const FOForall = Forall

Base.show(io::IO, v::Variable) = print(io, v.name)
_fo_constant_text(value) = value isa Symbol ? string(value) : repr(value)
Base.show(io::IO, c::Constant) = print(io, _fo_constant_text(c.value))
function _fo_term_text(term)
    term isa Variable && return string(term.name)
    term isa Constant && return _fo_constant_text(term.value)
    term isa FunctionTerm && return "$(term.name)(" *
           join((_fo_term_text(t) for t in term.arguments), ", ") *
           ")"
    return string(typeof(term))
end
Base.show(io::IO, t::FunctionTerm) = print(io, _fo_term_text(t))
function _fo_text(formula::FirstOrderFormula, parent::Symbol=:root)
    if formula isa Predicate
        return "$(formula.name)(" *
               join((_fo_term_text(t) for t in formula.arguments), ", ") *
               ")"
    elseif formula isa Equality
        return "$( _fo_term_text(formula.left) ) = $( _fo_term_text(formula.right) )"
    elseif formula isa FONegation
        text = "¬" * _fo_text(formula.child, :not)
        return if formula.child isa Predicate || formula.child isa Equality
            text
        else
            "¬(" * _fo_text(formula.child) * ")"
        end
    elseif formula isa FOConjunction
        return _fo_join(formula, "∧", :and, parent)
    elseif formula isa FODisjunction
        return _fo_join(formula, "∨", :or, parent)
    elseif formula isa FOImplication
        return _fo_join(formula, "→", :imp, parent)
    elseif formula isa Exists
        return "∃$(formula.variable). " * _fo_text(formula.body)
    elseif formula isa Forall
        return "∀$(formula.variable). " * _fo_text(formula.body)
    end
    return string(typeof(formula))
end
function _fo_child_text(formula)
    return if formula isa Predicate || formula isa Equality
        _fo_text(formula)
    else
        "(" * _fo_text(formula) * ")"
    end
end
function _fo_join(formula, token, kind, parent)
    text = _fo_child_text(formula.left) * " $token " * _fo_child_text(formula.right)
    return parent == :root ? text : "(" * text * ")"
end
Base.show(io::IO, f::FirstOrderFormula) = print(io, _fo_text(f))
Base.string(f::FirstOrderFormula) = _fo_text(f)

"""A finite first-order interpretation used by `evaluate` and translation tests."""
struct FirstOrderInterpretation{D,P,E,F}
    domain::D
    predicates::P
    equality::E
    functions::F
end
function FirstOrderInterpretation(
    domain; predicates=Dict(), equality=(==), functions=Dict()
)
    return FirstOrderInterpretation(
        domain, predicates; equality=equality, functions=functions
    )
end

function FirstOrderInterpretation(domain, predicates; equality=(==), functions=Dict())
    values = tuple(domain...)
    isempty(values) && throw(ArgumentError("a first-order domain must be non-empty"))
    return FirstOrderInterpretation{
        typeof(values),typeof(predicates),typeof(equality),typeof(functions)
    }(
        values, predicates, equality, functions
    )
end
function FirstOrderInterpretation(domain, predicates, equality)
    return FirstOrderInterpretation(domain, predicates; equality=equality)
end
const FOInterpretation = FirstOrderInterpretation
const FOModel = FirstOrderInterpretation
domain(interpretation::FirstOrderInterpretation) = interpretation.domain

function _assignment_value(assignment, name::Symbol)
    assignment isa AbstractDict && haskey(assignment, name) && return assignment[name]
    assignment isa NamedTuple &&
        hasproperty(assignment, name) &&
        return getproperty(assignment, name)
    return throw(KeyError(name))
end
function _term_value(term::Variable, interpretation, assignment)
    value = _assignment_value(assignment, term.name)
    value in interpretation.domain ||
        throw(ArgumentError("assignment value is outside the first-order domain"))
    return value
end
_term_value(term::Constant, interpretation, assignment) = term.value
function _function_value(table, args)
    table isa Function && return table(args...)
    table isa AbstractDict && haskey(table, args) && return table[args]
    return throw(KeyError(args))
end
function _term_value(term::FunctionTerm, interpretation, assignment)
    args = Tuple(_term_value(t, interpretation, assignment) for t in term.arguments)
    table = interpretation.functions
    if table isa AbstractDict
        key = (term.name, length(args))
        haskey(table, key) && return _function_value(table[key], args)
        haskey(table, term.name) && return _function_value(table[term.name], args)
    elseif table isa Function
        return table(term.name, args...)
    end
    return throw(KeyError(term.name))
end

function _predicate_value(table, args)
    table isa Function && return Bool(table(args...))
    table isa AbstractSet && return length(args) == 1 ? (args[1] in table) : (args in table)
    table isa AbstractDict && (haskey(table, args) && return Bool(table[args]))
    table isa AbstractDict &&
        length(args) == 1 &&
        haskey(table, args[1]) &&
        return Bool(table[args[1]])
    return throw(KeyError(args))
end
function _predicate_value(interpretation::FirstOrderInterpretation, name, args)
    predicates = interpretation.predicates
    if predicates isa AbstractDict
        key = (name, length(args))
        haskey(predicates, key) && return _predicate_value(predicates[key], args)
        haskey(predicates, name) && return _predicate_value(predicates[name], args)
    end
    predicates isa Function && return Bool(predicates(name, args...))
    return throw(KeyError(name))
end

"""Evaluate a first-order formula in a finite interpretation."""
function evaluate(
    formula::FirstOrderFormula,
    interpretation::FirstOrderInterpretation,
    assignment=Dict{Symbol,Any}(),
)
    if formula isa Predicate
        return _predicate_value(
            interpretation,
            formula.name,
            Tuple(_term_value(t, interpretation, assignment) for t in formula.arguments),
        )
    elseif formula isa Equality
        return interpretation.equality(
            _term_value(formula.left, interpretation, assignment),
            _term_value(formula.right, interpretation, assignment),
        )
    elseif formula isa FONegation
        return !evaluate(formula.child, interpretation, assignment)
    elseif formula isa FOConjunction
        return evaluate(formula.left, interpretation, assignment) &&
               evaluate(formula.right, interpretation, assignment)
    elseif formula isa FODisjunction
        return evaluate(formula.left, interpretation, assignment) ||
               evaluate(formula.right, interpretation, assignment)
    elseif formula isa FOImplication
        return !evaluate(formula.left, interpretation, assignment) ||
               evaluate(formula.right, interpretation, assignment)
    elseif formula isa Exists || formula isa Forall
        variable, body = formula.variable, formula.body
        base_assignment = if assignment isa NamedTuple
            Dict{Symbol,Any}(pairs(assignment))
        else
            Dict{Symbol,Any}(assignment)
        end
        values = (
            let next = copy(base_assignment)
                next[variable.name] = value
                next
            end for value in interpretation.domain
        )
        return if formula isa Exists
            any(evaluate(body, interpretation, a) for a in values)
        else
            all(evaluate(body, interpretation, a) for a in values)
        end
    end
    return throw(ArgumentError("unsupported first-order formula $(typeof(formula))"))
end

function interpret(
    formula::FirstOrderFormula,
    interpretation::FirstOrderInterpretation,
    assignment=Dict{Symbol,Any}(),
)
    return evaluate(formula, interpretation, assignment)
end

struct _TranslationState
    counter::Base.RefValue{Int}
    atom_predicate::Any
    relation_predicate::Any
end
function _fresh_variable!(state::_TranslationState, prefix::Symbol)
    state.counter[] += 1
    return Variable(Symbol(prefix, "_", state.counter[]))
end
function _predicate_name(f, value)
    return f isa Function ? f(value) : value
end
function _standard_translation(formula::Atom, world::Variable, state::_TranslationState)
    return Predicate(_predicate_name(state.atom_predicate, value(formula)), world)
end
function _standard_translation(formula::Branch, world::Variable, state::_TranslationState)
    c = operator(formula)
    child = children(formula)
    if c isa Negation
        return FONegation(_standard_translation(child[1], world, state))
    elseif c isa Conjunction
        return FOConjunction(
            _standard_translation(child[1], world, state),
            _standard_translation(child[2], world, state),
        )
    elseif c isa Disjunction
        return FODisjunction(
            _standard_translation(child[1], world, state),
            _standard_translation(child[2], world, state),
        )
    elseif c isa Implication
        return FOImplication(
            _standard_translation(child[1], world, state),
            _standard_translation(child[2], world, state),
        )
    elseif c isa Diamond
        next = _fresh_variable!(state, world.name)
        edge = Predicate(
            _predicate_name(state.relation_predicate, relation(c)), world, next
        )
        return Exists(
            next, FOConjunction(edge, _standard_translation(child[1], next, state))
        )
    elseif c isa Box
        next = _fresh_variable!(state, world.name)
        edge = Predicate(
            _predicate_name(state.relation_predicate, relation(c)), world, next
        )
        return Forall(
            next, FOImplication(edge, _standard_translation(child[1], next, state))
        )
    end
    return throw(
        ArgumentError("standard translation has no clause for connective $(repr(c))")
    )
end

"""
    standard_translation(formula; world=Variable(:x))

Translate a modal formula to its one-free-variable first-order translation.
Atoms become unary predicates, and each named modal relation becomes a binary
predicate.  The clauses are the standard ones of Blackburn, de Rijke, and
Venema §2.4 [blackburn2001](@cite).  `atom_predicate` and `relation_predicate`
may be functions when separate predicate namespaces are desired.
"""
function standard_translation(
    formula::Formula;
    world=Variable(:x),
    world_variable=nothing,
    atom_predicate=identity,
    relation_predicate=identity,
)
    root = world_variable === nothing ? world : world_variable
    root isa Symbol && (root = Variable(root))
    root isa AbstractString && (root = Variable(root))
    root isa Variable || throw(ArgumentError("world must be a Variable, Symbol, or string"))
    state = _TranslationState(Ref(0), atom_predicate, relation_predicate)
    return _standard_translation(formula, root, state)
end
standard_translation(formula::Formula, world) = standard_translation(formula; world=world)
const standardtranslate = standard_translation
const translate = standard_translation

"""Build the first-order interpretation corresponding to a Boolean modal model.

Dictionary layouts enumerate atom names, including nested world-to-atom maps
when their nested keys are unambiguous. Overlapping dictionary keys whose
orientation cannot be determined require an explicit `atoms` keyword; callable
and otherwise unrecognised valuations require it as well."""
function first_order_interpretation(
    model::Model;
    atoms=nothing,
    relations=nothing,
    atom_predicate=identity,
    relation_predicate=identity,
)
    algebra(model) isa BooleanAlgebra ||
        throw(ArgumentError("standard translation interpretations are Boolean"))
    atom_names = atoms === nothing ? _valuation_atoms(model) : collect(atoms)
    relation_names =
        relations === nothing ? _model_relation_names(frame(model)) : collect(relations)
    predicates = Dict{Any,Any}()
    for name in atom_names
        payload = name isa Atom ? value(name) : name
        mapped = _predicate_name(atom_predicate, payload)
        predicates[mapped] = (world -> Bool(_atom_truth(model, name, world)))
    end
    for name in relation_names
        mapped = _predicate_name(relation_predicate, name)
        predicates[(mapped, 2)] =
            (source, target) -> target in accessible(frame(model), source, name)
    end
    return FirstOrderInterpretation(worlds(frame(model)), predicates)
end
const firstorder = first_order_interpretation

function _atom_truth(model, name, world)
    if name isa Atom
        return interpret(name, model, world)
    end
    p = FormulaPool(Signature((¬,)))
    return interpret(atom(p, name), model, world)
end
