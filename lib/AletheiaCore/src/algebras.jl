# Finite residuated-lattice semantics.
#
# A FiniteFLewAlgebra stores truth values as one-based UInt8 indices.  The
# one-based convention is intentional: it is the convention used by
# SoleLogics' FiniteTruth tables and is also the natural convention for Julia
# table indexing.  The operation tables therefore contain no boxed truth
# objects and evaluation is a single integer lookup.

"""The integer carrier used by [`FiniteFLewAlgebra`](@ref).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("FiniteTruth"))
true
```
"""
const FiniteTruth = UInt8

struct _ValidatedFiniteFLew end
const _validated_flew = _ValidatedFiniteFLew()

"""
    FiniteFLewAlgebra{N}

A finite FLew algebra over the carrier `UInt8(1):UInt8(N)`.  `join` and
`meet` are the bounded-lattice tables, `fusion` is the commutative monoid
(table used for multiplicative conjunction), and `implication` is derived at
construction as the greatest element satisfying residuation.  `bot` and
`top` are designated carrier indices.

Use `FiniteFLewAlgebra(join, meet, fusion, bot, top)` to construct one.  All
three input tables are explicit `N × N` integer-indexed tables; a malformed
or non-FLew presentation is rejected before an object is returned.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("FiniteFLewAlgebra"))
true
```
"""
struct FiniteFLewAlgebra{N} <: TruthAlgebra{FiniteTruth}
    join::Matrix{FiniteTruth}
    meet::Matrix{FiniteTruth}
    fusion::Matrix{FiniteTruth}
    implication::Matrix{FiniteTruth}
    bot::FiniteTruth
    top::FiniteTruth

    # The only low-level constructor is marked with a private validation tag;
    # public constructors below always normalize and validate their input.
    function FiniteFLewAlgebra{N}(
        join::Matrix{FiniteTruth}, meet::Matrix{FiniteTruth},
        fusion::Matrix{FiniteTruth}, implication::Matrix{FiniteTruth},
        bot::FiniteTruth, top::FiniteTruth, ::_ValidatedFiniteFLew
    ) where N
        new{N}(join, meet, fusion, implication, bot, top)
    end
end

function _finite_index(value, n::Int, name::AbstractString)
    value isa Integer || throw(ArgumentError("$name must be an integer truth index"))
    index = Int(value)
    1 <= index <= n || throw(ArgumentError("$name index $value is outside 1:$n"))
    FiniteTruth(index)
end

function _finite_table(data, n::Int, name::AbstractString)
    source = if data isa AbstractMatrix
        size(data) == (n, n) || throw(ArgumentError("$name table must have size ($n, $n), got $(size(data))"))
        data
    elseif data isa AbstractVector || data isa Tuple
        length(data) == n * n || throw(ArgumentError("$name table must contain $(n * n) entries"))
        # Flat tables follow Julia's column-major indexing.  Symmetric tables
        # are the common FLew case, while callers needing orientation should
        # pass an explicit matrix.
        reshape(collect(data), n, n)
    else
        throw(ArgumentError("$name table must be an N×N integer matrix"))
    end
    result = Matrix{FiniteTruth}(undef, n, n)
    for i in axes(source, 1), j in axes(source, 2)
        result[i, j] = _finite_index(source[i, j], n, "$name[$i,$j]")
    end
    result
end

@inline function _finite_leq(meet_table::Matrix{FiniteTruth}, x::FiniteTruth, y::FiniteTruth)
    meet_table[Int(x), Int(y)] == x
end

function _invalid_flew(axiom::AbstractString, witness, detail="")
    suffix = isempty(detail) ? "" : ": $detail"
    throw(ArgumentError("invalid FLew-algebra: $axiom; witness $(repr(witness))$suffix"))
end

function _validate_lattice(join_table, meet_table, bot, top, n)
    for x in 1:n, y in 1:n
        jxy, jyx = join_table[x, y], join_table[y, x]
        jxy == jyx || _invalid_flew("lattice commutativity (join)", (x, y), "join[x,y] != join[y,x]")
        mxy, myx = meet_table[x, y], meet_table[y, x]
        mxy == myx || _invalid_flew("lattice commutativity (meet)", (x, y), "meet[x,y] != meet[y,x]")
        join_table[x, meet_table[x, y]] == x ||
            _invalid_flew("lattice absorption", (x, y), "x ∨ (x ∧ y) != x")
        meet_table[x, join_table[x, y]] == x ||
            _invalid_flew("lattice absorption", (x, y), "x ∧ (x ∨ y) != x")
    end
    for x in 1:n
        join_table[x, x] == x || _invalid_flew("lattice idempotence (join)", (x, x))
        meet_table[x, x] == x || _invalid_flew("lattice idempotence (meet)", (x, x))
        join_table[Int(bot), x] == x && meet_table[Int(bot), x] == bot ||
            _invalid_flew("lattice bounds", (bot, x), "⊥ is not a bound")
        join_table[Int(top), x] == top && meet_table[Int(top), x] == x ||
            _invalid_flew("lattice bounds", (top, x), "⊤ is not a bound")
    end
    for x in 1:n, y in 1:n, z in 1:n
        join_table[x, join_table[y, z]] == join_table[join_table[x, y], z] ||
            _invalid_flew("lattice associativity (join)", (x, y, z))
        meet_table[x, meet_table[y, z]] == meet_table[meet_table[x, y], z] ||
            _invalid_flew("lattice associativity (meet)", (x, y, z))
    end
end

function _validate_fusion(fusion, meet_table, top, n)
    for x in 1:n, y in 1:n
        fusion[x, y] == fusion[y, x] ||
            _invalid_flew("fusion commutativity", (x, y))
        fusion[Int(top), x] == x && fusion[x, Int(top)] == x ||
            _invalid_flew("fusion neutral top", (top, x), "⊤ is not the fusion identity")
    end
    for x in 1:n, y in 1:n, z in 1:n
        fusion[x, fusion[y, z]] == fusion[fusion[x, y], z] ||
            _invalid_flew("fusion associativity", (x, y, z))
    end
    # Monotonicity is checked in both arguments even though commutativity was
    # checked above; this gives a useful witnessing triple for either defect.
    for x in 1:n, y in 1:n, z in 1:n
        if _finite_leq(meet_table, FiniteTruth(x), FiniteTruth(y))
            fusion[x, z] == fusion[y, z] || _finite_leq(meet_table, fusion[x, z], fusion[y, z]) ||
                _invalid_flew("fusion monotonicity (left)", (x, y, z))
            fusion[z, x] == fusion[z, y] || _finite_leq(meet_table, fusion[z, x], fusion[z, y]) ||
                _invalid_flew("fusion monotonicity (right)", (z, x, y))
        end
    end
end

function _derive_implication(join_table, meet_table, fusion, bot, top, n)
    implication = Matrix{FiniteTruth}(undef, n, n)
    for x in 1:n, z in 1:n
        candidates = FiniteTruth[]
        for y in 1:n
            _finite_leq(meet_table, fusion[x, y], FiniteTruth(z)) && push!(candidates, FiniteTruth(y))
        end
        greatest = FiniteTruth[]
        for candidate in candidates
            all(other -> _finite_leq(meet_table, other, candidate), candidates) && push!(greatest, candidate)
        end
        length(greatest) == 1 || _invalid_flew("residuum existence", (x, z),
            "the set of y with x ⊗ y ≤ z has no greatest element")
        implication[x, z] = only(greatest)
    end
    # Explicitly validate residuation, rather than relying solely on the
    # candidate search above.  This catches accidental table/index mistakes
    # and keeps the promised axiom check visible in diagnostics.
    for x in 1:n, y in 1:n, z in 1:n
        left = _finite_leq(meet_table, fusion[x, y], FiniteTruth(z))
        right = _finite_leq(meet_table, FiniteTruth(x), implication[y, z])
        left == right || _invalid_flew("residuation", (x, y, z),
            "x ⊗ y ≤ z iff x ≤ y → z fails")
    end
    implication
end

function _make_flew(join_table, meet_table, fusion_table, bot, top, n::Int)
    join = _finite_table(join_table, n, "join")
    lattice_meet = _finite_table(meet_table, n, "meet")
    fusion = _finite_table(fusion_table, n, "fusion")
    b = _finite_index(bot, n, "bottom")
    t = _finite_index(top, n, "top")
    _validate_lattice(join, lattice_meet, b, t, n)
    _validate_fusion(fusion, lattice_meet, t, n)
    implication = _derive_implication(join, lattice_meet, fusion, b, t, n)
    FiniteFLewAlgebra{n}(join, lattice_meet, fusion, implication, b, t, _validated_flew)
end

function FiniteFLewAlgebra(join_table, meet_table, fusion_table, bot, top)
    n = if meet_table isa AbstractMatrix
        size(meet_table, 1) == size(meet_table, 2) || throw(ArgumentError("meet table must be square"))
        size(meet_table, 1)
    elseif meet_table isa AbstractVector || meet_table isa Tuple
        r = isqrt(length(meet_table))
        r * r == length(meet_table) || throw(ArgumentError("meet table must contain a square number of entries"))
        r
    else
        throw(ArgumentError("meet table must be an N×N integer matrix"))
    end
    n >= 1 || throw(ArgumentError("a finite FLew-algebra must have at least one truth value"))
    n <= typemax(FiniteTruth) || throw(ArgumentError("FiniteFLewAlgebra supports at most 255 truth values"))
    FiniteFLewAlgebra{n}(join_table, meet_table, fusion_table, bot, top)
end

function FiniteFLewAlgebra{N}(join_table, meet_table, fusion_table, bot, top) where N
    N isa Integer && 1 <= N <= typemax(FiniteTruth) ||
        throw(ArgumentError("FiniteFLewAlgebra parameter N must be an integer in 1:255"))
    _make_flew(join_table, meet_table, fusion_table, bot, top, Int(N))
end

truth_type(::Type{<:FiniteFLewAlgebra}) = FiniteTruth
truth_type(::FiniteFLewAlgebra) = FiniteTruth

@inline function _checked_finite_index(algebra::FiniteFLewAlgebra{N}, value) where N
    (value isa Integer && !(value isa Bool)) ||
        throw(ArgumentError("value $(repr(value)) is outside the FiniteTruth carrier 1:$N"))
    1 <= value <= N ||
        throw(ArgumentError("value $(repr(value)) is outside the FiniteTruth carrier 1:$N"))
    FiniteTruth(value)
end
@inline _validate_atom_value(algebra::FiniteFLewAlgebra, value) =
    _checked_finite_index(algebra, value)

"""Return the finite carrier indices in table order."""
domain(::FiniteFLewAlgebra{N}) where N = Tuple(FiniteTruth(i) for i in 1:N)
levels(algebra::FiniteFLewAlgebra) = domain(algebra)
"""Return whether `algebra` is a finite chain rather than the unit interval.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("isfinitechain"))
true
```
"""
function isfinitechain(algebra::FiniteFLewAlgebra)
    values = domain(algebra)
    all(x -> all(y -> precedeq(algebra, x, y) || precedeq(algebra, y, x), values), values)
end
Base.length(::FiniteFLewAlgebra{N}) where N = N

"""Return the lattice meet (infimum) of two finite truth values.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("meet"))
true
```
"""
@inline function meet(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.meet[Int(x), Int(y)]
end
join_table(algebra::FiniteFLewAlgebra) = _boundary_copy(algebra.join)
lattice_meet_table(algebra::FiniteFLewAlgebra) = _boundary_copy(algebra.meet)
fusion_table(algebra::FiniteFLewAlgebra) = _boundary_copy(algebra.fusion)
implication_table(algebra::FiniteFLewAlgebra) = _boundary_copy(algebra.implication)

"""Return the monoid fusion `x ⊗ y` of two finite truth values.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("fusion"))
true
```
"""
@inline function fusion(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.fusion[Int(x), Int(y)]
end

@inline function top(algebra::FiniteFLewAlgebra)
    algebra.top
end
@inline function bottom(algebra::FiniteFLewAlgebra)
    algebra.bot
end
@inline function join(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.join[Int(x), Int(y)]
end
@inline function implication(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.implication[Int(x), Int(y)]
end
residuum(algebra::FiniteFLewAlgebra, left, right) = implication(algebra, left, right)
@inline negation(algebra::FiniteFLewAlgebra, value) = implication(algebra, value, bottom(algebra))

"""The derived lattice order `x ≤ y` (that is, `x ∧ y = x`).

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("precedeq"))
true
```
"""
@inline function precedeq(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.meet[Int(x), Int(y)] == x
end
@inline succeedeq(algebra::FiniteFLewAlgebra, left, right) = precedeq(algebra, right, left)
"""Return whether the left finite truth value strictly precedes the right value.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("precedes"))
true
```
"""
function precedes(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    x != y && precedeq(algebra, x, y)
end
"""Return whether the left finite truth value strictly succeeds the right value.

# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("succeeds"))
true
```
"""
function succeeds(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    x != y && succeedeq(algebra, x, y)
end

function _finite_subset(algebra::FiniteFLewAlgebra{N}, subset) where N
    if subset isa Integer
        return [ _checked_finite_index(algebra, subset) ]
    end
    result = FiniteTruth[]
    for value in subset
        index = _checked_finite_index(algebra, value)
        index in result || push!(result, index)
    end
    result
end

"""Return all maximal members of an arbitrary finite subset of the lattice.

For compatibility with SoleLogics, a single truth index is also accepted and
means the maximal values not above that threshold.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("maximalmembers"))
true
```
"""
function maximalmembers(algebra::FiniteFLewAlgebra, subset)
    values = subset isa Integer ?
        [x for x in domain(algebra) if !succeedeq(algebra, x, subset)] : _finite_subset(algebra, subset)
    [x for x in values if !any(y -> y != x && precedes(algebra, x, y), values)]
end

"""Return all minimal members of an arbitrary finite subset of the lattice.

For compatibility with SoleLogics, a single truth index is also accepted and
means the minimal values not below that threshold.


# Examples
```jldoctest
julia> using AletheiaCore

julia> isdefined(AletheiaCore, Symbol("minimalmembers"))
true
```
"""
function minimalmembers(algebra::FiniteFLewAlgebra, subset)
    values = subset isa Integer ?
        [x for x in domain(algebra) if !precedeq(algebra, x, subset)] : _finite_subset(algebra, subset)
    [x for x in values if !any(y -> y != x && precedes(algebra, y, x), values)]
end

"""
    truthlabel(index)
    truthlabel(algebra, value)

Return the display label of a finite truth value.  The one-argument form uses
the carrier convention shared with SoleLogics (`1` is `⊤`, `2` is `⊥` and the
remaining indices are `α`, `β`, …); the two-argument form reads `⊥` and `⊤`
off `algebra` so that a carrier laid out differently still labels correctly.

Labels are a presentation concern only: the carrier itself stays an unboxed
`UInt8` index.
"""
truthlabel(index::Integer) = string(Int(index) < 3 ? Char(8867 + Int(index)) : Char(942 + Int(index)))

function truthlabel(algebra::FiniteFLewAlgebra, value)
    index = _checked_finite_index(algebra, value)
    index == algebra.top && return "⊤"
    index == algebra.bot && return "⊥"
    # Intermediate values are named α, β, … in carrier order; the label is
    # deliberately not the index, which is storage detail.
    rank = count(i -> i != Int(algebra.top) && i != Int(algebra.bot), 1:(Int(index) - 1))
    string(Char(945 + rank))
end

function _display_truth(algebra::FiniteFLewAlgebra{N}, value) where N
    # `Bool` is never the finite carrier, so it is left in its own form.
    value isa Integer && !(value isa Bool) && 1 <= value <= N ?
        truthlabel(algebra, value) : string(value)
end

"""Return the carrier in display order plus whether the lattice is a chain.

A chain is shown in ascending order.  A non-chain lattice has no such order to
show, so it is listed as `⊥`, the incomparable values, `⊤`, and the display
says so rather than implying the carrier order is a ranking.
"""
function _algebra_order(algebra::FiniteFLewAlgebra{N}) where N
    values = [FiniteTruth(i) for i in 1:N]
    ischain = all(precedeq(algebra, x, y) || precedeq(algebra, y, x) for x in values, y in values)
    ischain && return (sort(values; lt=(x, y) -> precedes(algebra, x, y)), true)
    rest = [v for v in values if v != algebra.bot && v != algebra.top]
    (unique(vcat(algebra.bot, rest, algebra.top)), false)
end

_truth_color(algebra::FiniteFLewAlgebra, value) =
    value == algebra.top ? _DISPLAY_TOP : value == algebra.bot ? _DISPLAY_BOT : :normal

function Base.show(io::IO, algebra::FiniteFLewAlgebra{N}) where N
    print(io, "FiniteFLewAlgebra{$N}(bottom=", truthlabel(algebra, algebra.bot),
        ", top=", truthlabel(algebra, algebra.top), ")")
end

Base.show(io::IO, ::MIME"text/plain", ::BooleanAlgebra) =
    _display_header(io, "BooleanAlgebra", "carrier Bool: {false, true}")

_model_algebra_summary(::BooleanAlgebra) = "BooleanAlgebra()"
_model_algebra_summary(::GodelAlgebra{0}) = "GodelAlgebra (unit interval [0.0, 1.0])"
_model_algebra_summary(::LukasiewiczAlgebra{0}) = "LukasiewiczAlgebra (unit interval [0.0, 1.0])"
_model_algebra_summary(::GodelAlgebra{N}) where N = "GodelAlgebra ($N-level chain)"
_model_algebra_summary(::LukasiewiczAlgebra{N}) where N = "LukasiewiczAlgebra ($N-level chain)"
_model_algebra_summary(::FiniteFLewAlgebra{N}) where N = "FiniteFLewAlgebra ($N values)"

function Base.show(io::IO, ::MIME"text/plain", alg::GodelAlgebra{N}) where N
    N == 0 && return _display_header(io, "GodelAlgebra", "unit interval [0.0, 1.0]")
    lvls = join(string.(levels(alg)), ", ")
    _display_header(io, "GodelAlgebra{$N}", "chain of $N levels: $lvls")
end

function Base.show(io::IO, ::MIME"text/plain", alg::LukasiewiczAlgebra{N}) where N
    N == 0 && return _display_header(io, "LukasiewiczAlgebra", "unit interval [0.0, 1.0]")
    lvls = join(string.(round.(levels(alg), digits=3)), ", ")
    _display_header(io, "LukasiewiczAlgebra{$N}", "chain of $N levels: $lvls")
end

"""Render one operation table as element-labelled lines, in display order."""
function _render_table_rows(op_symbol::String, matrix::Matrix{FiniteTruth}, order, labels)
    width = maximum(length, labels)
    cell(text) = lpad(text, width)
    lines = String[" " * cell(op_symbol) * " │ " * join((cell(labels[Int(y)]) for y in order), " ")]
    push!(lines, "─"^(width + 2) * "┼" * "─"^((width + 1) * length(order)))
    for x in order
        push!(lines, " " * cell(labels[Int(x)]) * " │ " *
            join((cell(labels[Int(matrix[Int(x), Int(y)])]) for y in order), " "))
    end
    lines
end

function Base.show(io::IO, ::MIME"text/plain", algebra::FiniteFLewAlgebra{N}) where N
    order, ischain = _algebra_order(algebra)
    labels = [truthlabel(algebra, i) for i in 1:N]
    _display_header(io, "FiniteFLewAlgebra{$N}",
        "$N value$(N == 1 ? "" : "s"), $(ischain ? "chain" : "not a chain"), " *
        "bottom=$(truthlabel(algebra, algebra.bot)), top=$(truthlabel(algebra, algebra.top))")

    shown, elided = _display_bounded(io, order, 12)
    _display_label(io, 2, ischain ? "Order" : "Elements")
    for (i, value) in enumerate(shown)
        i == 1 || print(io, ischain ? " < " : ", ")
        _styled(io, labels[Int(value)], _truth_color(algebra, value))
    end
    _display_elision(io, elided)

    N <= 10 || return
    tables = (_render_table_rows("∧", algebra.meet, order, labels),
              _render_table_rows("⊗", algebra.fusion, order, labels),
              _render_table_rows("∨", algebra.join, order, labels),
              _render_table_rows("→", algebra.implication, order, labels))
    titles = ("  Meet (∧)", "  Fusion (⊗)", "  Join (∨)", "  Implication (→)")
    widths = (max(maximum(length, tables[1]), length(titles[1])) + 4,
              max(maximum(length, tables[2]), length(titles[2])) + 4,
              max(maximum(length, tables[3]), length(titles[3])) + 4,
              0)

    print(io, "\n\n")
    for (title, width) in zip(titles, widths)
        _styled(io, width == 0 ? title : rpad(title, width), _DISPLAY_DIM)
    end
    for i in eachindex(tables[1])
        print(io, "\n")
        # The axis row carries the element labels and the rule separates it;
        # the body rows stay plain so the table reads as data, not decoration.
        color = i == 1 ? _DISPLAY_HEAD : i == 2 ? _DISPLAY_DIM : :normal
        for (table, width) in zip(tables, widths)
            _styled(io, width == 0 ? table[i] : rpad(table[i], width), color)
        end
    end
end

# ---------------------------------------------------------------------------
# SoleLogics' named finite tables.  Every table uses the source order
# (⊤, ⊥, α, β, …), exactly as in its shipped algebra files.  Only the G/Ł
# chain labels are increasing intermediate levels; H labels are arbitrary
# points of their partial lattices.

function _chain_index(level::Rational, n::Int)
    level == 1 && return FiniteTruth(1)
    level == 0 && return FiniteTruth(2)
    FiniteTruth(Int(level * (n - 1)) + 2)
end

function _chain_flew(n::Int, kind::Symbol)
    n >= 2 || throw(ArgumentError("a finite chain needs at least two values"))
    join_table = Matrix{FiniteTruth}(undef, n, n)
    meet_table = Matrix{FiniteTruth}(undef, n, n)
    fusion_table = Matrix{FiniteTruth}(undef, n, n)
    levels_ = [i == 1 ? 1//1 : i == 2 ? 0//1 : (i - 2)//(n - 1) for i in 1:n]
    for i in 1:n, j in 1:n
        join_table[i, j] = _chain_index(max(levels_[i], levels_[j]), n)
        meet_table[i, j] = _chain_index(min(levels_[i], levels_[j]), n)
        monoid_level = kind === :godel ? min(levels_[i], levels_[j]) : max(0//1, levels_[i] + levels_[j] - 1)
        fusion_table[i, j] = _chain_index(monoid_level, n)
    end
    _make_flew(join_table, meet_table, fusion_table, 2, 1, n)
end

"""The 3-element Gödel chain FLew algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> G3 isa FiniteFLewAlgebra
true
```
"""
const G3 = _chain_flew(3, :godel)
"""The 4-element Gödel chain FLew algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> G4 isa FiniteFLewAlgebra
true
```
"""
const G4 = _chain_flew(4, :godel)
"""The 5-element Gödel chain FLew algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> G5 isa FiniteFLewAlgebra
true
```
"""
const G5 = _chain_flew(5, :godel)
"""The 6-element Gödel chain FLew algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> G6 isa FiniteFLewAlgebra
true
```
"""
const G6 = _chain_flew(6, :godel)
"""The 3-element Łukasiewicz chain FLew algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> Ł3 isa FiniteFLewAlgebra
true
```
"""
const Ł3 = _chain_flew(3, :lukasiewicz)
"""The 4-element Łukasiewicz chain FLew algebra.

# Examples
```jldoctest
julia> using AletheiaCore

julia> Ł4 isa FiniteFLewAlgebra
true
```
"""
const Ł4 = _chain_flew(4, :lukasiewicz)
const L3 = Ł3
const L4 = Ł4

function _named_flew(join_values, meet_values, fusion_values, n)
    _make_flew(join_values, meet_values, fusion_values, 2, 1, n)
end

"""The 4-element non-chain FLew algebra H4.

# Examples
```jldoctest
julia> using AletheiaCore

julia> H4 isa FiniteFLewAlgebra
true
```
"""
const H4 = _named_flew(
    [1 1 1 1; 1 2 3 4; 1 3 3 1; 1 4 1 4],
    [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4],
    [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4], 4)

"""The 6-element non-chain FLew algebra H6.

# Examples
```jldoctest
julia> using AletheiaCore

julia> H6 isa FiniteFLewAlgebra
true
```
"""
const H6 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 6 5 6; 1 4 6 4 1 6; 1 5 5 1 5 1; 1 6 6 6 1 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 2 4; 5 2 3 2 5 3; 6 2 3 4 3 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 2 4; 5 2 3 2 5 3; 6 2 3 4 3 6], 6)

"""The 6-element non-chain FLew algebra H6_1.

# Examples
```jldoctest
julia> using AletheiaCore

julia> H6_1 isa FiniteFLewAlgebra
true
```
"""
const H6_1 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 5 5 6; 1 4 5 4 5 6; 1 5 5 5 5 6; 1 6 6 6 6 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6], 6)

"""The 6-element non-chain FLew algebra H6_2.

# Examples
```jldoctest
julia> using AletheiaCore

julia> H6_2 isa FiniteFLewAlgebra
true
```
"""
const H6_2 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 6 6; 1 5 5 6 5 6; 1 6 6 6 6 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 3 4; 5 2 3 3 5 5; 6 2 3 4 5 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 3 4; 5 2 3 3 5 5; 6 2 3 4 5 6], 6)

"""The 6-element non-chain FLew algebra H6_3.

# Examples
```jldoctest
julia> using AletheiaCore

julia> H6_3 isa FiniteFLewAlgebra
true
```
"""
const H6_3 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 5 6; 1 5 5 5 5 1; 1 6 6 6 1 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 4; 6 2 3 4 4 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 4; 6 2 3 4 4 6], 6)

"""The 9-element non-chain FLew algebra H9.

# Examples
```jldoctest
julia> using AletheiaCore

julia> H9 isa FiniteFLewAlgebra
true
```
"""
const H9 = _named_flew(
    [1 1 1 1 1 1 1 1 1; 1 2 3 4 5 6 7 8 9; 1 3 3 6 5 6 9 8 9; 1 4 6 4 8 6 7 8 9; 1 5 5 8 5 8 1 8 1; 1 6 6 6 8 6 9 8 9; 1 7 9 7 1 9 7 1 9; 1 8 8 8 8 8 1 8 1; 1 9 9 9 1 9 9 1 9],
    [1 2 3 4 5 6 7 8 9; 2 2 2 2 2 2 2 2 2; 3 2 3 2 3 3 2 3 3; 4 2 2 4 2 4 4 4 4; 5 2 3 2 5 3 2 5 3; 6 2 3 4 3 6 4 6 6; 7 2 2 4 2 4 7 4 7; 8 2 3 4 5 6 4 8 6; 9 2 3 4 3 6 7 6 9],
    [1 2 3 4 5 6 7 8 9; 2 2 2 2 2 2 2 2 2; 3 2 3 2 3 3 2 3 3; 4 2 2 4 2 4 4 4 4; 5 2 3 2 5 3 2 5 3; 6 2 3 4 3 6 4 6 6; 7 2 2 4 2 4 7 4 7; 8 2 3 4 5 6 4 8 6; 9 2 3 4 3 6 7 6 9], 9)

# A finite Boolean FLew table is useful where a uniform UInt8 carrier is
# required, while BOOLEAN remains the optimized Bool TruthAlgebra.
"""A 2-valued finite Boolean FLew table.

# Examples
```jldoctest
julia> using AletheiaCore

julia> BooleanFLewAlgebra isa FiniteFLewAlgebra
true
```
"""
const BooleanFLewAlgebra = _named_flew([1 1; 1 2], [1 2; 2 2], [1 2; 2 2], 2)
