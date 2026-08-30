# Finite FLew-algebras

Aletheia's finite many-valued semantics includes **FLew-algebras**: finite
residuated lattices with a commutative monoid. A value is a small integer
index (`FiniteTruth`, currently `UInt8`) into a table carrier. The public
constructor is:

```julia
FiniteFLewAlgebra(join_table, meet_table, fusion_table, bottom, top)
```

where each table is a square integer matrix over the carrier indices. Flat
integer vectors or tuples of length `N*N` are also accepted and normalized to
`UInt8` matrices.

The constructor validates the bounded-lattice and commutative-monoid axioms,
monotonicity of fusion, and residuation. It derives `x → z` as the
largest `y` such that `x ⊗ y ≤ z`; implication is never accepted as an
independent hand-written table. `meet(algebra, x, y)` is the lattice infimum, while
`fusion(algebra, x, y)` is the monoid operation used for strong conjunction.
The syntax `⊗` denotes fusion and `∧` denotes the lattice meet.

The named `G3`, `G4`, `G5`, `G6`, `Ł3`, `Ł4`, `H4`, `H6`, `H6_1`, `H6_2`,
`H6_3`, and `H9` values reproduce the corresponding tables shipped by
SoleLogics' `ManyValuedLogics` module, element for element. The table carrier
is deliberately integer-indexed rather than boxed truth objects, so the common
operation is a single `UInt8` table lookup. The existing `GodelAlgebra{N}` and
`LukasiewiczAlgebra{N}` remain specialized `Float64` fast paths; tests compare
them against these general finite constructions for every level.

## Why a chain is not enough

`H4`'s carrier is the four `UInt8` indices `0x01`–`0x04`, in the order
⊤, ⊥, α, β; `domain(H4)` returns them. The two middle values are incomparable:
their join is ⊤ and their lattice meet is ⊥, while both are strictly between ⊥
and ⊤.

```jldoctest algebras
using Aletheia

⊤H, ⊥H, α, β = domain(H4)
show(stdout, MIME"text/plain"(), H4)
println()
println(join(H4, α, β) == ⊤H)
println(meet(H4, α, β) == ⊥H)
println(Aletheia.truthlabel.(Ref(H4), maximalmembers(H4, [α, β])))
println(Aletheia.truthlabel.(Ref(H4), minimalmembers(H4, [α, β])))

# output

FiniteFLewAlgebra{4} (4 values, not a chain, bottom=⊥, top=⊤)
  Elements: ⊥, α, β, ⊤

  Meet (∧)        Fusion (⊗)      Join (∨)        Implication (→)
 ∧ │ ⊥ α β ⊤     ⊗ │ ⊥ α β ⊤     ∨ │ ⊥ α β ⊤     → │ ⊥ α β ⊤
───┼────────    ───┼────────    ───┼────────    ───┼────────
 ⊥ │ ⊥ ⊥ ⊥ ⊥     ⊥ │ ⊥ ⊥ ⊥ ⊥     ⊥ │ ⊥ α β ⊤     ⊥ │ ⊤ ⊤ ⊤ ⊤
 α │ ⊥ α ⊥ α     α │ ⊥ α ⊥ α     α │ α α ⊤ ⊤     α │ β ⊤ β ⊤
 β │ ⊥ ⊥ β β     β │ ⊥ ⊥ β β     β │ β ⊤ β ⊤     β │ α α ⊤ ⊤
 ⊤ │ ⊥ α β ⊤     ⊤ │ ⊥ α β ⊤     ⊤ │ ⊤ ⊤ ⊤ ⊤     ⊤ │ ⊥ α β ⊤
true
true
["α", "β"]
["α", "β"]
```

A chain would have to put one of `α`, `β` below the other, changing at least
one of those two table entries. For example, a formula valuation may assign
`p = α` and `q = β`; then `p ∧ q = ⊥` and `p ∨ q = ⊤`, a genuinely non-chain
configuration that no totally ordered truth algebra can represent.

The order helpers are derived from the lattice meet:
`precedeq(a, x, y)` means `meet(a, x, y) == x`, and
`succeedeq` reverses the arguments. `check` and `extension` use the same DAG
walk for these algebras as for Boolean and chain models; finite models return
`UInt8` vectors, including for modal `Diamond` and `Box` formulas.

The bounded-residuated-lattice and FLew terminology follows Galatos et al.'s
algebraic treatment of substructural logics, §2.2 (printed pp. 91–94)
[galatos2007; §2.2, pp. 91–94](@cite).
