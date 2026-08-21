# Finite FLew-algebras

Aletheia's finite many-valued semantics includes **FLew-algebras**: finite
residuated lattices with a commutative monoid.  A value is a small integer
index (`FiniteTruth`, currently `UInt8`) into a table carrier.  The public
constructor is:

```julia
FiniteFLewAlgebra(join_table, lattice_meet_table, monoid_table, bottom, top)
```

The constructor validates the bounded-lattice and commutative-monoid axioms,
monotonicity of the monoid, and residuation.  It derives `x → z` as the
largest `y` such that `x ⊙ y ≤ z`; implication is never accepted as an
independent hand-written table.  `meet(algebra, x, y)` is the logical monoid
conjunction, while `lattice_meet(algebra, x, y)` exposes the lattice meet used
to derive `precedeq`.

The named `G3`, `G4`, `G5`, `G6`, `Ł3`, `Ł4`, `H4`, `H6`, `H6_1`, `H6_2`,
`H6_3`, and `H9` values reproduce the corresponding shipped SoleLogics
join/meet/monoid tables element for element.  The table carrier is deliberately
integer-indexed rather than boxed truth objects, so the common operation is a
single `UInt8` table lookup.  The existing `GodelAlgebra{N}` and
`LukasiewiczAlgebra{N}` remain specialized `Float64` fast paths; tests compare
them against these general finite constructions for every level.

## Why a chain is not enough

Consider `H4`, with carrier ordered as `(⊤, ⊥, α, β)`.  Its lattice tables
include

```text
α ∨ β = ⊤       α ∧ β = ⊥
```

while both `α` and `β` are strictly between `⊥` and `⊤`.  Thus `α` and `β`
are incomparable: a chain would have to put one below the other, changing at
least one of these two table entries.  For example, a formula valuation may
assign `p = α` and `q = β`; then `p ∧ q = ⊥` and `p ∨ q = ⊤`, a genuinely
non-chain configuration that no totally ordered truth algebra can represent.
`maximalmembers(H4, [α, β])` and `minimalmembers(H4, [α, β])` consequently
return both values.

The order helpers are derived from the lattice meet:
`precedeq(a, x, y)` means `lattice_meet(a, x, y) == x`, and
`succeedeq` reverses the arguments.  `check` and `extension` use the same DAG
walk for these algebras as for Boolean and chain models; finite models return
`UInt8` vectors, including for modal `Diamond` and `Box` formulas.

The bounded-residuated-lattice and FLew terminology follows Galatos et al.'s
algebraic treatment of substructural logics [galatos2007](@cite).
