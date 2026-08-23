# Finite residuated-lattice semantics.
#
# A FiniteFLewAlgebra stores truth values as one-based UInt8 indices.  The
# one-based convention is intentional: it is the convention used by
# SoleLogics' FiniteTruth tables and is also the natural convention for Julia
# table indexing.  The operation tables therefore contain no boxed truth
# objects and evaluation is a single integer lookup.

"""The integer carrier used by [`FiniteFLewAlgebra`](@ref)."""
const FiniteTruth = UInt8

"""
    FiniteFLewAlgebra{N}

A finite FLew algebra over the carrier `UInt8(1):UInt8(N)`.  `join` and
`meet` are the bounded-lattice tables, `monoid` is the commutative monoid
(table used for logical conjunction), and `implication` is derived at
construction as the greatest element satisfying residuation.  `bot` and
`top` are designated carrier indices.

Use `FiniteFLewAlgebra(join, meet, monoid, bot, top)` to construct one.  All
three input tables are explicit `N × N` integer-indexed tables; a malformed
or non-FLew presentation is rejected before an object is returned.
"""
struct FiniteFLewAlgebra{N} <: TruthAlgebra{FiniteTruth}
    join::Matrix{FiniteTruth}
    meet::Matrix{FiniteTruth}
    monoid::Matrix{FiniteTruth}
    implication::Matrix{FiniteTruth}
    bot::FiniteTruth
    top::FiniteTruth

    # The only low-level constructor is marked with a private validation tag;
    # public constructors below always normalize and validate their input.
    function FiniteFLewAlgebra{N}(
        join::Matrix{FiniteTruth}, meet::Matrix{FiniteTruth},
        monoid::Matrix{FiniteTruth}, implication::Matrix{FiniteTruth},
        bot::FiniteTruth, top::FiniteTruth, ::Val{:validated}
    ) where N
        new{N}(join, meet, monoid, implication, bot, top)
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

function _validate_monoid(monoid, meet_table, top, n)
    for x in 1:n, y in 1:n
        monoid[x, y] == monoid[y, x] ||
            _invalid_flew("monoid commutativity", (x, y))
        monoid[Int(top), x] == x && monoid[x, Int(top)] == x ||
            _invalid_flew("monoid neutral top", (top, x), "⊤ is not the monoid identity")
    end
    for x in 1:n, y in 1:n, z in 1:n
        monoid[x, monoid[y, z]] == monoid[monoid[x, y], z] ||
            _invalid_flew("monoid associativity", (x, y, z))
    end
    # Monotonicity is checked in both arguments even though commutativity was
    # checked above; this gives a useful witnessing triple for either defect.
    for x in 1:n, y in 1:n, z in 1:n
        if _finite_leq(meet_table, FiniteTruth(x), FiniteTruth(y))
            monoid[x, z] == monoid[y, z] || _finite_leq(meet_table, monoid[x, z], monoid[y, z]) ||
                _invalid_flew("monoid monotonicity (left)", (x, y, z))
            monoid[z, x] == monoid[z, y] || _finite_leq(meet_table, monoid[z, x], monoid[z, y]) ||
                _invalid_flew("monoid monotonicity (right)", (z, x, y))
        end
    end
end

function _derive_implication(join_table, meet_table, monoid, bot, top, n)
    implication = Matrix{FiniteTruth}(undef, n, n)
    for x in 1:n, z in 1:n
        candidates = FiniteTruth[]
        for y in 1:n
            _finite_leq(meet_table, monoid[x, y], FiniteTruth(z)) && push!(candidates, FiniteTruth(y))
        end
        greatest = FiniteTruth[]
        for candidate in candidates
            all(other -> _finite_leq(meet_table, other, candidate), candidates) && push!(greatest, candidate)
        end
        length(greatest) == 1 || _invalid_flew("residuum existence", (x, z),
            "the set of y with x ⊙ y ≤ z has no greatest element")
        implication[x, z] = only(greatest)
    end
    # Explicitly validate residuation, rather than relying solely on the
    # candidate search above.  This catches accidental table/index mistakes
    # and keeps the promised axiom check visible in diagnostics.
    for x in 1:n, y in 1:n, z in 1:n
        left = _finite_leq(meet_table, monoid[x, y], FiniteTruth(z))
        right = _finite_leq(meet_table, FiniteTruth(x), implication[y, z])
        left == right || _invalid_flew("residuation", (x, y, z),
            "x ⊙ y ≤ z iff x ≤ y → z fails")
    end
    implication
end

function _make_flew(join_table, meet_table, monoid_table, bot, top, n::Int)
    join = _finite_table(join_table, n, "join")
    lattice_meet = _finite_table(meet_table, n, "meet")
    monoid = _finite_table(monoid_table, n, "monoid")
    b = _finite_index(bot, n, "bottom")
    t = _finite_index(top, n, "top")
    _validate_lattice(join, lattice_meet, b, t, n)
    _validate_monoid(monoid, lattice_meet, t, n)
    implication = _derive_implication(join, lattice_meet, monoid, b, t, n)
    FiniteFLewAlgebra{n}(join, lattice_meet, monoid, implication, b, t, Val(:validated))
end

function FiniteFLewAlgebra(join_table, meet_table, monoid_table, bot, top)
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
    FiniteFLewAlgebra{n}(join_table, meet_table, monoid_table, bot, top)
end

function FiniteFLewAlgebra{N}(join_table, meet_table, monoid_table, bot, top) where N
    N isa Integer && 1 <= N <= typemax(FiniteTruth) ||
        throw(ArgumentError("FiniteFLewAlgebra parameter N must be an integer in 1:255"))
    _make_flew(join_table, meet_table, monoid_table, bot, top, Int(N))
end

truth_type(::Type{<:FiniteFLewAlgebra}) = FiniteTruth
truth_type(::FiniteFLewAlgebra) = FiniteTruth

@inline function _checked_finite_index(algebra::FiniteFLewAlgebra{N}, value) where N
    value isa Integer || throw(ArgumentError("truth value must be an integer index"))
    1 <= value <= N || throw(ArgumentError("truth index $value is outside 1:$N"))
    FiniteTruth(value)
end

"""Return the finite carrier indices in table order."""
domain(::FiniteFLewAlgebra{N}) where N = Tuple(FiniteTruth(i) for i in 1:N)
levels(algebra::FiniteFLewAlgebra) = domain(algebra)
isfinitechain(::FiniteFLewAlgebra) = false
Base.length(::FiniteFLewAlgebra{N}) where N = N

"""Return the lattice meet (as opposed to the monoid conjunction)."""
@inline function lattice_meet(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.meet[Int(x), Int(y)]
end
latticejoin(algebra::FiniteFLewAlgebra, left, right) = join(algebra, left, right)
lattice_join(algebra::FiniteFLewAlgebra, left, right) = join(algebra, left, right)
lmeet(algebra::FiniteFLewAlgebra, left, right) = lattice_meet(algebra, left, right)
join_table(algebra::FiniteFLewAlgebra) = algebra.join
lattice_meet_table(algebra::FiniteFLewAlgebra) = algebra.meet
monoid_table(algebra::FiniteFLewAlgebra) = algebra.monoid
implication_table(algebra::FiniteFLewAlgebra) = algebra.implication

"""Return the monoid product `x ⊙ y`; this is semantic conjunction."""
@inline function product(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.monoid[Int(x), Int(y)]
end
tnorm(algebra::FiniteFLewAlgebra, left, right) = product(algebra, left, right)
monoid_product(algebra::FiniteFLewAlgebra, left, right) = product(algebra, left, right)
monoid(algebra::FiniteFLewAlgebra, left, right) = product(algebra, left, right)
monoid_operation(algebra::FiniteFLewAlgebra, left, right) = product(algebra, left, right)

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
# In the TruthAlgebra interface `meet` is the logical conjunction.  FLew's
# lattice meet remains available as lattice_meet above.
@inline meet(algebra::FiniteFLewAlgebra, left, right) = product(algebra, left, right)
@inline function implication(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.implication[Int(x), Int(y)]
end
residuum(algebra::FiniteFLewAlgebra, left, right) = implication(algebra, left, right)
@inline negation(algebra::FiniteFLewAlgebra, value) = implication(algebra, value, bottom(algebra))

"""The derived lattice order `x ≤ y` (that is, `x ∧ y = x`)."""
@inline function precedeq(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    algebra.meet[Int(x), Int(y)] == x
end
@inline succeedeq(algebra::FiniteFLewAlgebra, left, right) = precedeq(algebra, right, left)
function precedes(algebra::FiniteFLewAlgebra, left, right)
    x, y = _checked_finite_index(algebra, left), _checked_finite_index(algebra, right)
    x != y && precedeq(algebra, x, y)
end
function succeedes(algebra::FiniteFLewAlgebra, left, right)
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
"""
function maximalmembers(algebra::FiniteFLewAlgebra, subset)
    values = subset isa Integer ?
        [x for x in domain(algebra) if !succeedeq(algebra, x, subset)] : _finite_subset(algebra, subset)
    [x for x in values if !any(y -> y != x && precedes(algebra, x, y), values)]
end

"""Return all minimal members of an arbitrary finite subset of the lattice.

For compatibility with SoleLogics, a single truth index is also accepted and
means the minimal values not below that threshold.
"""
function minimalmembers(algebra::FiniteFLewAlgebra, subset)
    values = subset isa Integer ?
        [x for x in domain(algebra) if !precedeq(algebra, x, subset)] : _finite_subset(algebra, subset)
    [x for x in values if !any(y -> y != x && precedes(algebra, y, x), values)]
end

# Alternate name makes the lattice meet unambiguous to callers that use the FLew notation directly.
latticemeet(algebra::FiniteFLewAlgebra, left, right) = lattice_meet(algebra, left, right)

function Base.show(io::IO, algebra::FiniteFLewAlgebra{N}) where N
    print(io, "FiniteFLewAlgebra{$N}(bottom=$(algebra.bot), top=$(algebra.top))")
end

Base.show(io::IO, ::MIME"text/plain", ::BooleanAlgebra) =
    print(io, "BooleanAlgebra (carrier Bool: {false, true})")

function Base.show(io::IO, ::MIME"text/plain", alg::GodelAlgebra{N}) where N
    if N == 0
        print(io, "GodelAlgebra (unit interval [0.0, 1.0])")
    else
        lvls = join(string.(levels(alg)), ", ")
        print(io, "GodelAlgebra{$N} (chain of $N levels: $lvls)")
    end
end

function Base.show(io::IO, ::MIME"text/plain", alg::LukasiewiczAlgebra{N}) where N
    if N == 0
        print(io, "LukasiewiczAlgebra (unit interval [0.0, 1.0])")
    else
        lvls = join(string.(round.(levels(alg), digits=3)), ", ")
        print(io, "LukasiewiczAlgebra{$N} (chain of $N levels: $lvls)")
    end
end

function _render_table_rows(op_symbol::String, matrix::Matrix{FiniteTruth}, N::Int)
    lines = String[]
    hdr = " " * op_symbol * " │ " * join(string.(1:N), " ")
    push!(lines, hdr)
    div_line = "───┼" * "─"^(2 * N)
    push!(lines, div_line)
    for i in 1:N
        row_str = " " * string(i) * " │ " * join(string.(matrix[i, :]), " ")
        push!(lines, row_str)
    end
    lines
end

function Base.show(io::IO, ::MIME"text/plain", algebra::FiniteFLewAlgebra{N}) where N
    println(io, "FiniteFLewAlgebra{$N} (bottom=$(algebra.bot), top=$(algebra.top))\n")
    if N <= 10
        t1 = _render_table_rows("∧", algebra.meet, N)
        t2 = _render_table_rows("∨", algebra.join, N)
        t3 = _render_table_rows("→", algebra.implication, N)

        titles = ["  Meet (∧)", "  Join (∨)", "  Implication (→)"]
        w1 = max(maximum(length, t1), length(titles[1]))
        w2 = max(maximum(length, t2), length(titles[2]))

        println(io, rpad(titles[1], w1 + 4), rpad(titles[2], w2 + 4), titles[3])
        for i in 1:length(t1)
            line1 = rpad(t1[i], w1 + 4)
            line2 = rpad(t2[i], w2 + 4)
            line3 = t3[i]
            if i == length(t1)
                print(io, line1, line2, line3)
            else
                println(io, line1, line2, line3)
            end
        end
    else
        print(io, "  Carrier: 1:$N")
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
    monoid_table = Matrix{FiniteTruth}(undef, n, n)
    levels_ = [i == 1 ? 1//1 : i == 2 ? 0//1 : (i - 2)//(n - 1) for i in 1:n]
    for i in 1:n, j in 1:n
        join_table[i, j] = _chain_index(max(levels_[i], levels_[j]), n)
        meet_table[i, j] = _chain_index(min(levels_[i], levels_[j]), n)
        monoid_level = kind === :godel ? min(levels_[i], levels_[j]) : max(0//1, levels_[i] + levels_[j] - 1)
        monoid_table[i, j] = _chain_index(monoid_level, n)
    end
    _make_flew(join_table, meet_table, monoid_table, 2, 1, n)
end

const G3 = _chain_flew(3, :godel)
const G4 = _chain_flew(4, :godel)
const G5 = _chain_flew(5, :godel)
const G6 = _chain_flew(6, :godel)
const Ł3 = _chain_flew(3, :lukasiewicz)
const Ł4 = _chain_flew(4, :lukasiewicz)
const L3 = Ł3
const L4 = Ł4

function _named_flew(join_values, meet_values, monoid_values, n)
    _make_flew(join_values, meet_values, monoid_values, 2, 1, n)
end

const H4 = _named_flew(
    [1 1 1 1; 1 2 3 4; 1 3 3 1; 1 4 1 4],
    [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4],
    [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4], 4)

const H6 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 6 5 6; 1 4 6 4 1 6; 1 5 5 1 5 1; 1 6 6 6 1 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 2 4; 5 2 3 2 5 3; 6 2 3 4 3 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 2 4; 5 2 3 2 5 3; 6 2 3 4 3 6], 6)

const H6_1 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 5 5 6; 1 4 5 4 5 6; 1 5 5 5 5 6; 1 6 6 6 6 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6], 6)

const H6_2 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 6 6; 1 5 5 6 5 6; 1 6 6 6 6 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 3 4; 5 2 3 3 5 5; 6 2 3 4 5 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 3 4; 5 2 3 3 5 5; 6 2 3 4 5 6], 6)

const H6_3 = _named_flew(
    [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 5 6; 1 5 5 5 5 1; 1 6 6 6 1 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 4; 6 2 3 4 4 6],
    [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 4; 6 2 3 4 4 6], 6)

const H9 = _named_flew(
    [1 1 1 1 1 1 1 1 1; 1 2 3 4 5 6 7 8 9; 1 3 3 6 5 6 9 8 9; 1 4 6 4 8 6 7 8 9; 1 5 5 8 5 8 1 8 1; 1 6 6 6 8 6 9 8 9; 1 7 9 7 1 9 7 1 9; 1 8 8 8 8 8 1 8 1; 1 9 9 9 1 9 9 1 9],
    [1 2 3 4 5 6 7 8 9; 2 2 2 2 2 2 2 2 2; 3 2 3 2 3 3 2 3 3; 4 2 2 4 2 4 4 4 4; 5 2 3 2 5 3 2 5 3; 6 2 3 4 3 6 4 6 6; 7 2 2 4 2 4 7 4 7; 8 2 3 4 5 6 4 8 6; 9 2 3 4 3 6 7 6 9],
    [1 2 3 4 5 6 7 8 9; 2 2 2 2 2 2 2 2 2; 3 2 3 2 3 3 2 3 3; 4 2 2 4 2 4 4 4 4; 5 2 3 2 5 3 2 5 3; 6 2 3 4 3 6 4 6 6; 7 2 2 4 2 4 7 4 7; 8 2 3 4 5 6 4 8 6; 9 2 3 4 3 6 7 6 9], 9)

# A finite Boolean FLew table is useful where a uniform UInt8 carrier is
# required, while BOOLEAN remains the optimized Bool TruthAlgebra.
const BooleanFLewAlgebra = _named_flew([1 1; 1 2], [1 2; 2 2], [1 2; 2 2], 2)
