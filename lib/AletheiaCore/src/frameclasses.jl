# Frame-condition traits and named normal modal systems.

"""A named class of finite relational frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> FrameClass(:K, ())
K
```
"""
struct FrameClass
    name::Symbol
    conditions::Tuple{Vararg{Symbol}}
end

"""The basic normal modal system K (no frame conditions).

# Examples
```jldoctest
julia> using AletheiaCore

julia> K isa FrameClass
true
```
"""
const K = FrameClass(:K, ())
"""The system T (reflexive frames).

# Examples
```jldoctest
julia> using AletheiaCore

julia> T isa FrameClass
true
```
"""
const T = FrameClass(:T, (:reflexive,))
"""The system S4 (reflexive and transitive frames).

# Examples
```jldoctest
julia> using AletheiaCore

julia> S4 isa FrameClass
true
```
"""
const S4 = FrameClass(:S4, (:reflexive, :transitive))
"""The system S5 (equivalence frames).

# Examples
```jldoctest
julia> using AletheiaCore

julia> S5 isa FrameClass
true
```
"""
const S5 = FrameClass(:S5, (:reflexive, :transitive, :symmetric))
"""The class of reflexive frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> REFLEXIVE isa FrameClass
true
```
"""
const REFLEXIVE = FrameClass(:reflexive, (:reflexive,))
"""The class of transitive frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> TRANSITIVE isa FrameClass
true
```
"""
const TRANSITIVE = FrameClass(:transitive, (:transitive,))
"""The class of symmetric frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> SYMMETRIC isa FrameClass
true
```
"""
const SYMMETRIC = FrameClass(:symmetric, (:symmetric,))
"""The class of serial frames.

# Examples
```jldoctest
julia> using AletheiaCore

julia> SERIAL isa FrameClass
true
```
"""
const SERIAL = FrameClass(:serial, (:serial,))
const REFLEXIVITY = REFLEXIVE
const TRANSITIVITY = TRANSITIVE
const SYMMETRY = SYMMETRIC
const SERIALITY = SERIAL

Base.show(io::IO, class::FrameClass) = print(io, class.name)

function _class_targets(frame::Frame, relation)
    relation !== nothing && return (relation,)
    stored = relations(frame)
    stored isa AbstractDict || return ()
    Tuple(keys(stored))
end

"""Check reflexivity of a named accessibility relation on a finite frame.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("isreflexive"))
true
```
"""
function isreflexive(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    !isempty(targets) && all(all(w -> any(v -> isequal(v, w), accessible(frame, w, r)), worlds(frame)) for r in targets)
end
"""Check transitivity of a named accessibility relation on a finite frame.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("istransitive"))
true
```
"""
function istransitive(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    !isempty(targets) && all(begin
        all(w -> all(v -> all(u -> any(x -> isequal(x, u), accessible(frame, w, r)),
                                      accessible(frame, v, r)), accessible(frame, w, r)), worlds(frame))
    end for r in targets)
end
"""Check symmetry of a named accessibility relation on a finite frame.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("issymmetric"))
true
```
"""
function issymmetric(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    !isempty(targets) && all(all(begin
        all(v -> any(x -> isequal(x, w), accessible(frame, v, r)), accessible(frame, w, r))
    end for w in worlds(frame)) for r in targets)
end
"""Check seriality of a named accessibility relation on a finite frame.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("isserial"))
true
```
"""
function isserial(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    !isempty(targets) && all(all(!isempty(collect(accessible(frame, w, r))) for w in worlds(frame)) for r in targets)
end

# Natural-language aliases.
"""Check reflexivity of a frame relation.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("reflexive"))
true
```
"""
reflexive(frame, relation=nothing) = isreflexive(frame, relation)
"""Check transitivity of a frame relation.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("transitive"))
true
```
"""
transitive(frame, relation=nothing) = istransitive(frame, relation)
"""Check symmetry of a frame relation.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("symmetric"))
true
```
"""
symmetric(frame, relation=nothing) = issymmetric(frame, relation)
"""Check seriality of a frame relation.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("serial"))
true
```
"""
serial(frame, relation=nothing) = isserial(frame, relation)

"""Return whether `frame` satisfies a named class for `relation`.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("satisfies"))
true
```
"""
function satisfies(frame::Frame, class::FrameClass, relation=nothing)
    class.name === :K && return true
    all(condition -> condition === :reflexive ? isreflexive(frame, relation) :
        condition === :transitive ? istransitive(frame, relation) :
        condition === :symmetric ? issymmetric(frame, relation) :
        condition === :serial ? isserial(frame, relation) : false, class.conditions)
end
checkclass(frame::Frame, class::FrameClass, relation=nothing) = satisfies(frame, class, relation)
validclass(frame::Frame, class::FrameClass, relation=nothing) = satisfies(frame, class, relation)

# The standard correspondence axioms (Blackburn–de Rijke–Venema, Ch. 3;
# Schwarz, Logic 2). `axioms` returns the individual schemas so callers can
# inspect or test each condition; `axiom` conjoins them when ∧ is available.
# An empty custom class has no axiom schema: `axioms` returns `()`, while the
# singular `axiom` API rejects it with an ArgumentError.
function _require_connective(pool::FormulaPool, connective)
    hasconnective(signature(pool), connective) ||
        throw(ArgumentError("the pool signature must contain $(repr(connective)) to construct a frame axiom"))
    connective
end
function _axiom_atom(pool::FormulaPool, atom_value)
    atom(pool, atom_value)
end
function _primitive_axioms(pool::FormulaPool, condition::Symbol, relation, atom_value)
    p = _axiom_atom(pool, atom_value)
    box = Box(relation); diamond = Diamond(relation)
    if condition === :reflexive
        _require_connective(pool, box); _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, branch(pool, box, p), p),)
    elseif condition === :transitive
        _require_connective(pool, box); _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, branch(pool, box, p), branch(pool, box, branch(pool, box, p))),)
    elseif condition === :symmetric
        _require_connective(pool, box); _require_connective(pool, diamond); _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, p, branch(pool, box, branch(pool, diamond, p))),)
    elseif condition === :serial
        _require_connective(pool, box); _require_connective(pool, diamond); _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, branch(pool, box, p), branch(pool, diamond, p)),)
    else
        throw(ArgumentError("unknown frame condition $condition"))
    end
end
"""Construct the correspondence axiom formulas for a frame class.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("axioms"))
true
```
"""
function axioms(pool::FormulaPool, class::FrameClass; relation=:R, atom_value="p")
    if class.name === :K
        p = _axiom_atom(pool, atom_value)
        q = _axiom_atom(pool, "q")
        box = Box(relation)
        _require_connective(pool, box); _require_connective(pool, IMPLICATION)
        implication = branch(pool, IMPLICATION, p, q)
        return (branch(pool, IMPLICATION, branch(pool, box, implication),
            branch(pool, IMPLICATION, branch(pool, box, p), branch(pool, box, q))),)
    end
    result = Formula[]
    for condition in class.conditions
        append!(result, _primitive_axioms(pool, condition, relation, atom_value))
    end
    Tuple(result)
end
"""Construct the first correspondence axiom formula for a frame class.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("axiom"))
true
```
"""
function axiom(pool::FormulaPool, class::FrameClass; relation=:R, atom_value="p")
    forms = axioms(pool, class; relation=relation, atom_value=atom_value)
    isempty(forms) && throw(ArgumentError(
        "frame class $(class.name) has no axiom schema; use axioms for its empty schema set"))
    length(forms) == 1 && return forms[1]
    _require_connective(pool, CONJUNCTION)
    result = forms[1]
    for form in forms[2:end]
        result = branch(pool, CONJUNCTION, result, form)
    end
    result
end

"""Check a class axiom in a particular model at every world.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("validates"))
true
```
"""
function validates(model::Model, formula::Formula)
    all(check(formula, model, world) == top(algebra(model)) for world in worlds(frame(model)))
end
validates(formula::Formula, model::Model) = validates(model, formula)
