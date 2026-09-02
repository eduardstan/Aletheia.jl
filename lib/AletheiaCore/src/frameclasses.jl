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
    return Tuple(keys(stored))
end

"""Check reflexivity of a named accessibility relation on a finite frame."""
function isreflexive(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    return !isempty(targets) && all(
        all(w -> any(v -> isequal(v, w), accessible(frame, w, r)), worlds(frame)) for
        r in targets
    )
end
"""Check transitivity of a named accessibility relation on a finite frame."""
function istransitive(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    return !isempty(targets) && all(
        begin
            all(
                w -> all(
                    v -> all(
                        u -> any(x -> isequal(x, u), accessible(frame, w, r)),
                        accessible(frame, v, r),
                    ),
                    accessible(frame, w, r),
                ),
                worlds(frame),
            )
        end for r in targets
    )
end
"""Check symmetry of a named accessibility relation on a finite frame."""
function issymmetric(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    return !isempty(targets) && all(
        all(
            begin
                all(
                    v -> any(x -> isequal(x, w), accessible(frame, v, r)),
                    accessible(frame, w, r),
                )
            end for w in worlds(frame)
        ) for r in targets
    )
end
"""Check seriality of a named accessibility relation on a finite frame."""
function isserial(frame::Frame, relation=nothing)
    targets = _class_targets(frame, relation)
    return !isempty(targets) && all(
        all(!isempty(collect(accessible(frame, w, r))) for w in worlds(frame)) for
        r in targets
    )
end

# Natural-language aliases.
reflexive(frame, relation=nothing) = isreflexive(frame, relation)
transitive(frame, relation=nothing) = istransitive(frame, relation)
symmetric(frame, relation=nothing) = issymmetric(frame, relation)
serial(frame, relation=nothing) = isserial(frame, relation)

"""Return whether `frame` satisfies a named class for `relation`."""
function satisfies(frame::Frame, class::FrameClass, relation=nothing)
    class.name === :K && return true
    return all(condition -> if condition === :reflexive
        isreflexive(frame, relation)
    elseif condition === :transitive
        istransitive(frame, relation)
    elseif condition === :symmetric
        issymmetric(frame, relation)
    elseif condition === :serial
        isserial(frame, relation)
    else
        false
    end, class.conditions)
end
function checkclass(frame::Frame, class::FrameClass, relation=nothing)
    return satisfies(frame, class, relation)
end
function validclass(frame::Frame, class::FrameClass, relation=nothing)
    return satisfies(frame, class, relation)
end

# The standard correspondence axioms (Blackburn–de Rijke–Venema, Ch. 3;
# Schwarz, Logic 2). `axioms` returns the individual schemas so callers can
# inspect or test each condition; `axiom` conjoins them when ∧ is available.
# An empty custom class has no axiom schema: `axioms` returns `()`, while the
# singular `axiom` API rejects it with an ArgumentError.
function _require_connective(pool::FormulaPool, connective)
    hasconnective(signature(pool), connective) || throw(
        ArgumentError(
            "the pool signature must contain $(repr(connective)) to construct a frame axiom",
        ),
    )
    return connective
end
function _axiom_atom(pool::FormulaPool, atom_value)
    return atom(pool, atom_value)
end
function _primitive_axioms(pool::FormulaPool, condition::Symbol, relation, atom_value)
    p = _axiom_atom(pool, atom_value)
    box = Box(relation)
    diamond = Diamond(relation)
    if condition === :reflexive
        _require_connective(pool, box)
        _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, branch(pool, box, p), p),)
    elseif condition === :transitive
        _require_connective(pool, box)
        _require_connective(pool, IMPLICATION)
        (
            branch(
                pool,
                IMPLICATION,
                branch(pool, box, p),
                branch(pool, box, branch(pool, box, p)),
            ),
        )
    elseif condition === :symmetric
        _require_connective(pool, box)
        _require_connective(pool, diamond)
        _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, p, branch(pool, box, branch(pool, diamond, p))),)
    elseif condition === :serial
        _require_connective(pool, box)
        _require_connective(pool, diamond)
        _require_connective(pool, IMPLICATION)
        (branch(pool, IMPLICATION, branch(pool, box, p), branch(pool, diamond, p)),)
    else
        throw(ArgumentError("unknown frame condition $condition"))
    end
end
function axioms(pool::FormulaPool, class::FrameClass; relation=:R, atom_value="p")
    if class.name === :K
        p = _axiom_atom(pool, atom_value)
        q = _axiom_atom(pool, "q")
        box = Box(relation)
        _require_connective(pool, box)
        _require_connective(pool, IMPLICATION)
        implication = branch(pool, IMPLICATION, p, q)
        return (
            branch(
                pool,
                IMPLICATION,
                branch(pool, box, implication),
                branch(pool, IMPLICATION, branch(pool, box, p), branch(pool, box, q)),
            ),
        )
    end
    result = Formula[]
    for condition in class.conditions
        append!(result, _primitive_axioms(pool, condition, relation, atom_value))
    end
    return Tuple(result)
end
function axiom(pool::FormulaPool, class::FrameClass; relation=:R, atom_value="p")
    forms = axioms(pool, class; relation=relation, atom_value=atom_value)
    isempty(forms) && throw(
        ArgumentError(
            "frame class $(class.name) has no axiom schema; use axioms for its empty schema set",
        ),
    )
    length(forms) == 1 && return forms[1]
    _require_connective(pool, CONJUNCTION)
    result = forms[1]
    for form in forms[2:end]
        result = branch(pool, CONJUNCTION, result, form)
    end
    return result
end

"""Check a class axiom in a particular model at every world."""
function validates(model::Model, formula::Formula)
    return all(
        check(formula, model, world) == top(algebra(model)) for
        world in worlds(frame(model))
    )
end
validates(formula::Formula, model::Model) = validates(model, formula)
