# Bisimulation and finite bisimulation contraction, following BDV §2.2.

function _model_relation_names(frame::Frame)
    stored = frame.relations
    stored isa AbstractDict && return collect(keys(stored))
    stored isa _IntervalRelationMap && return collect(ALLEN_RELATIONS)
    stored isa Function && throw(ArgumentError(
        "callable accessibility requires an explicit relations keyword"))
    stored isa _RelationProvider && throw(ArgumentError(
        "unrecognised relation provider $(typeof(stored)); pass an explicit relations keyword"))
    throw(ArgumentError(
        "unrecognised relation representation $(typeof(stored)); pass an explicit relations keyword"))
end

function _valuation_atoms(model::Model)
    data = valuation(model)
    while data isa Valuation
        data = data.data
    end
    (data isa Function || data isa ValuationCallback) && throw(ArgumentError(
        "callable valuations require an explicit atoms keyword"))
    data isa AbstractDict || throw(ArgumentError(
        "unrecognised valuation representation $(typeof(data)); pass an explicit atoms keyword"))
    frame_worlds = worlds(frame(model))
    is_world(value) = any(world -> isequal(world, value), frame_worlds)
    result = Any[]
    for (key, value) in data
        if key isa Tuple && length(key) == 2
            first_world, second_world = is_world(key[1]), is_world(key[2])
            if first_world && second_world
                throw(ArgumentError(
                    "dictionary valuation keys $(repr(key)) are ambiguous between atom and world; pass an explicit atoms keyword"))
            elseif first_world || second_world
                push!(result, first_world ? key[2] : key[1])
            else
                # A tuple with no identifiable world is an atom payload, not
                # an atom/world pair.  The latter cannot enumerate its atom.
                push!(result, key)
            end
        elseif is_world(key)
            # A world-keyed nested dictionary/set can enumerate atoms, but a
            # world-only or world-overlapping namespace cannot be inferred.
            candidates = if value isa AbstractDict
                collect(keys(value))
            elseif value isa AbstractSet
                collect(value)
            else
                Any[]
            end
            isempty(candidates) && throw(ArgumentError(
                "dictionary valuation key $(repr(key)) does not enumerate atoms; pass an explicit atoms keyword"))
            any(is_world, candidates) && throw(ArgumentError(
                "dictionary valuation key $(repr(key)) has an ambiguous atom namespace; pass an explicit atoms keyword"))
            append!(result, candidates)
        else
            push!(result, key)
        end
    end
    unique(result)
end

function _label_compatible(m1, w1, m2, w2, atoms)
    all(isequal(_atom_truth(m1, a, w1), _atom_truth(m2, a, w2)) for a in atoms)
end
function _targets_tuple(model, world, name)
    Tuple(accessible(frame(model), world, name))
end

"""
    bisimilar(m₁, w₁, m₂, w₂; atoms, relations)

Decide the standard labelled bisimulation game for finite models.  The
implementation starts with all label-compatible world pairs and repeatedly
refines that partition using the forth and back conditions for every named
relation.  With nᵢ = |Wᵢ|, r named relations, and dᵢ maximum out-degree, one
refinement pass is O(n₁n₂r d₁d₂) time and O(n₁n₂) space; because this
straightforward implementation can make at most n₁n₂ passes, its worst-case time is
O((n₁n₂)²r d₁d₂). These are derived implementation bounds, not bounds stated
by the cited literature. Definitions and invariance are those of BDV §2.2
[blackburn2001](@cite).
When omitted, `atoms` are inferred from dictionary-backed models and `relations`
from dictionary-backed frames and generated interval frames; pass them explicitly
for callable valuations or callable accessibility.
Dictionary layouts enumerate atom names, including nested world-to-atom
maps when their nested keys are unambiguous. Overlapping dictionary keys whose
orientation cannot be determined require an explicit `atoms` keyword.
Unrecognised valuation representations likewise require an explicit atom
namespace.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("bisimilar"))
true
```
"""
function bisimilar(m1::Model, w1, m2::Model, w2; atoms=nothing, relations=nothing)
    _check_world(frame(m1), w1); _check_world(frame(m2), w2)
    names = atoms === nothing ? unique(vcat(_valuation_atoms(m1), _valuation_atoms(m2))) : collect(atoms)
    rels = relations === nothing ? unique(vcat(_model_relation_names(frame(m1)), _model_relation_names(frame(m2)))) : collect(relations)
    pairs = Set{Tuple{Any,Any}}()
    for left in worlds(frame(m1)), right in worlds(frame(m2))
        _label_compatible(m1, left, m2, right, names) && push!(pairs, (left, right))
    end
    changed = true
    while changed
        changed = false
        for pair in collect(pairs)
            left, right = pair
            survives = all(any((target, candidate) in pairs for candidate in _targets_tuple(m2, right, rel))
                           for rel in rels for target in _targets_tuple(m1, left, rel)) &&
                all(any((candidate, target) in pairs for candidate in _targets_tuple(m1, left, rel))
                    for rel in rels for target in _targets_tuple(m2, right, rel))
            if !survives
                delete!(pairs, pair)
                changed = true
            end
        end
    end
    (w1, w2) in pairs
end
bisimilar(m1::Model, w1, m2::Model, w2, atoms) = bisimilar(m1, w1, m2, w2; atoms=atoms)

"""An equivalence class of worlds in a bisimulation quotient.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("BisimulationClass"))
true
```
"""
struct BisimulationClass
    members::Tuple
end
Base.show(io::IO, class::BisimulationClass) = print(io, "Class(", join(repr.(class.members), ", "), ")")

"""The result of bisimulation quotient contraction on a model.

# Examples
```jldoctest
julia> using AletheiaCore

julia> m = Model(Frame([1, 2], Dict(globalrel => [(1, 2)])), Dict("p" => Dict(1 => true, 2 => false)));

julia> c = bisimulation_contraction(m);

julia> c isa BisimulationContraction
true
```
"""
struct BisimulationContraction{M,Q,W}
    model::M
    classes::Q
    world_map::W
end
"""Compatibility alias for [`BisimulationContraction`](@ref).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("QuotientModel"))
true
```
"""
const QuotientModel = BisimulationContraction

Base.show(io::IO, contraction::BisimulationContraction) =
    print(io, "BisimulationContraction(", length(contraction.world_map), " → ", length(contraction.classes), " worlds)")

function Base.show(io::IO, ::MIME"text/plain", contraction::BisimulationContraction)
    n_orig = length(contraction.world_map)
    n_classes = length(contraction.classes)
    pct = n_orig == 0 ? 0 : round(Int, (1.0 - n_classes / n_orig) * 100)
    _display_header(io, "BisimulationContraction",
        "$n_orig → $n_classes world$(n_classes == 1 ? "" : "s"), $pct% collapse ratio")

    shown, elided = _display_bounded(io, contraction.classes, DISPLAY_ITEMS)
    _display_label(io, 2, "Classes ($n_classes)", ":")
    for (i, class) in enumerate(shown)
        _display_label(io, 4, "Class $i")
        members, member_elided = _display_bounded(io, class.members, DISPLAY_ITEMS)
        print(io, join(repr.(members), ", "))
        _display_elision(io, member_elided)
    end
    _display_elision_line(io, 4, elided)
end

"""Return the contracted model from a bisimulation contraction.

# Examples
```jldoctest
julia> using AletheiaCore

julia> m = Model(Frame([1, 2], Dict(globalrel => [(1, 2)])), Dict("p" => Dict(1 => true, 2 => false)));

julia> c = bisimulation_contraction(m);

julia> model(c) isa Model
true
```
"""
model(contraction::BisimulationContraction) = contraction.model
"""Return the quotient equivalence classes from a bisimulation contraction.

# Examples
```jldoctest
julia> using AletheiaCore

julia> m = Model(Frame([1, 2], Dict(globalrel => [(1, 2)])), Dict("p" => Dict(1 => true, 2 => false)));

julia> c = bisimulation_contraction(m);

julia> classes(c) isa Tuple
true
```
"""
classes(contraction::BisimulationContraction) = contraction.classes
"""Return the world-to-class mapping from a bisimulation contraction.

# Examples
```jldoctest
julia> using AletheiaCore

julia> m = Model(Frame([1, 2], Dict(globalrel => [(1, 2)])), Dict("p" => Dict(1 => true, 2 => false)));

julia> c = bisimulation_contraction(m);

julia> world_map(c) isa Dict
true
```
"""
world_map(contraction::BisimulationContraction) = contraction.world_map
"""Return the quotient class corresponding to a original world.

# Examples
```jldoctest
julia> using AletheiaCore

julia> m = Model(Frame([1, 2], Dict(globalrel => [(1, 2)])), Dict("p" => Dict(1 => true, 2 => false)));

julia> c = bisimulation_contraction(m);

julia> contraction_world(c, 1) isa BisimulationClass
true
```
"""
function contraction_world(contraction::BisimulationContraction, world)
    world isa BisimulationClass && return world
    haskey(contraction.world_map, world) ? contraction.world_map[world] : throw(KeyError(world))
end
frame(contraction::BisimulationContraction) = frame(contraction.model)
algebra(contraction::BisimulationContraction) = algebra(contraction.model)
valuation(contraction::BisimulationContraction) = valuation(contraction.model)
accessible(contraction::BisimulationContraction, world, relation_name) = accessible(frame(contraction), world, relation_name)
check(formula::Formula, contraction::BisimulationContraction, world) =
    check(formula, contraction.model, contraction_world(contraction, world))
extension(formula::Formula, contraction::BisimulationContraction) = extension(formula, contraction.model)

function _classes_for_model(model::Model, atoms, relations)
    worlds_list = collect(worlds(frame(model)))
    blocks = [Set{Any}(worlds_list)]
    while true
        block_index = Dict{Any,Int}()
        for (i, block) in enumerate(blocks), world in block
            block_index[world] = i
        end
        groups = Dict{Any,Vector{Any}}()
        for world in worlds_list
            labels = Tuple(_atom_truth(model, atom_name, world) for atom_name in atoms)
            successors = Tuple(Tuple(sort!(unique(block_index[target] for target in
                _targets_tuple(model, world, relation_name)))) for relation_name in relations)
            key = (labels, successors)
            push!(get!(groups, key, Any[]), world)
        end
        next_blocks = [Set(group) for group in values(groups)]
        # Dict and Set iteration is hash-order dependent. Class order follows
        # stable frame enumeration; members use total order when available,
        # with frame order as the documented fallback.
        sort!(next_blocks, by=block -> findfirst(world -> world in block, worlds_list))
        length(next_blocks) == length(blocks) &&
            all(any(next_block == block for next_block in next_blocks) for block in blocks) && break
        blocks = next_blocks
    end
    classes = BisimulationClass[]
    for block in blocks
        members = collect(block)
        try
            sort!(members)
        catch error
            error isa MethodError || rethrow()
            sort!(members, by=world -> findfirst(candidate -> isequal(candidate, world), worlds_list))
        end
        push!(classes, BisimulationClass(tuple(members...)))
    end
    classes
end

"""Return the largest auto-bisimulation quotient of a finite model.

The result is a `BisimulationContraction` wrapper.  `contraction_world(q, w)`
selects the quotient world corresponding to an original world, while `check`
and `extension` delegate normally.  For n worlds, r relations, and maximum
out-degree d, this implementation's partition refinement costs O(n²rd log d)
worst-case time and O(nrd + n) working space; quotient construction adds O(nrd)
time and storage. These are derived implementation bounds, not bounds stated by
the cited literature. Callable relation providers must be accompanied by
`relations`, except for built-in generated interval frames, whose Allen relation
names are inferred. Dictionary-backed frames infer relation names. Dictionary
layouts enumerate atom names, including nested world-to-atom maps
when their nested keys are unambiguous. Overlapping dictionary keys whose
orientation cannot be determined require an explicit `atoms` keyword.
Unrecognised valuation representations require explicit `atoms` as well.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("bisimulation_contraction"))
true
```
"""
function bisimulation_contraction(model::Model; atoms=nothing, relations=nothing)
    atom_names = atoms === nothing ? _valuation_atoms(model) : collect(atoms)
    relation_names = relations === nothing ? _model_relation_names(frame(model)) : collect(relations)
    quotient_classes = _classes_for_model(model, atom_names, relation_names)
    mapping = Dict{Any,Any}()
    for class in quotient_classes
        for world in class.members
            mapping[world] = class
        end
    end
    adjacency = Dict{Any,Any}()
    for relation_name in relation_names
        relation_map = Dict{Any,Any}()
        for class in quotient_classes
            targets = BisimulationClass[]
            for target in _targets_tuple(model, class.members[1], relation_name)
                quotient = mapping[target]
                quotient in targets || push!(targets, quotient)
            end
            relation_map[class] = tuple(targets...)
        end
        adjacency[relation_name] = relation_map
    end
    qframe = Frame(tuple(quotient_classes...), adjacency; index=true)
    qvaluation = (atom_value, quotient) -> begin
        original = quotient isa BisimulationClass ? quotient.members[1] : quotient
        atom_name = atom_value
        for candidate in atom_names
            if candidate isa Atom && isequal(value(candidate), atom_value)
                atom_name = candidate
                break
            end
        end
        _atom_truth(model, atom_name, original)
    end
    qmodel = Model(qframe, algebra(model), qvaluation)
    BisimulationContraction(qmodel, tuple(quotient_classes...), mapping)
end
const contract = bisimulation_contraction
const contraction = bisimulation_contraction
