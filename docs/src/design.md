# Syntax and design

```@meta
CurrentModule = Aletheia
```

`[`AletheiaCore`](api.md)` is the dependency-free implementation of pooled syntax and
model evaluation. Its central boundary is simple: a formula is syntax; a truth
value is a result of interpreting syntax in a model. That distinction is not
cosmetic. It lets one pooled formula DAG be evaluated in Boolean, Gödel,
Łukasiewicz, or a user-defined algebra without making truth carriers into
special atom values. The distinction follows the syntax and satisfaction
boundary in Blackburn et al. [blackburn2001; §§1.2–1.3, pp. 9–26](@cite).

See [One recursive ownership rule](design-decisions.md#2026-09-05--one-recursive-ownership-rule) for the ownership and cache contract.

## Similarity types and pooled DAGs

`Signature` is a finite, value-based similarity type. `Diamond(:R)` and
`Box(:R)` are ordinary connective values carrying relation data: one connective
type carries the relation as data, so a new relation needs no new connective
type. A user-defined connective extends the open `arity`, `notation`, and (when
needed) `precedence`/`associativity` traits.

`Atom` and `Branch` are immutable handles into an explicit
`FormulaPool`. A branch stores child IDs, not recursively typed child
values. Thus a deeply nested formula does not produce a recursively nested
Julia type. Hash-consing makes repeated construction of the same atom or branch
return the same pool-local ID. This is an identity guarantee, not a general
allocation or runtime improvement; measured effects depend on whether a
workload actually reuses subterms:

```jldoctest design
using Aletheia

pool = FormulaPool(Signature((¬, ∧)))
p = atom(pool, "p")
left = branch(pool, ¬, p)
right = branch(pool, ¬, p)
println(left == right)
println(id(left), " ", subterms(left), " ", nsubterms(left))

# output

true
2 [1, 2] 2
```

Equality is deliberately pool-local. The same spelling in another pool is a
different formula, even if its printed syntax matches. Pool-local identity is
not only a performance device: the evaluator can index one vector by distinct
reachable DAG nodes, and formulas from unrelated signatures cannot be
accidentally combined. `dag` and `subterms` expose that identity when a
later algorithm needs it.

This follows the role of formula formation in the modal similarity-type
presentation (Blackburn et al., §1.2, Definitions 1.11–1.12, pp. 9–12)
[blackburn2001; §1.2, Definitions 1.11–1.12, pp. 9–12](@cite), while the
pool/ID representation is an implementation choice documented by the syntax
layer.

## Why truth values are not formulas

The semantic layer has a type parameter: `TruthAlgebra{T}` says that an atom
interpretation returns exactly `T`. In a Boolean model, `true` and `false` are
carriers. In a Gödel model, `0.5` is a carrier. Neither is an atom and neither
belongs in a syntax pool. Treating `⊤`, `⊥`, or a floating-point value as a
formula would make parsing, equality, normal forms, and model lookup disagree
about what an atom means.

The consequence is visible in the API: [`interpret`](@ref) accepts an atom
only; [`check`](@ref) and [`extension`](@ref) are the compound-formula entry
points. This is the same separation between a valuation and satisfaction used
in Blackburn et al., §1.3 (Definitions 1.19–1.20, pp. 16–18)
[blackburn2001; §1.3, Definitions 1.19–1.20, pp. 16–18](@cite). For the
adapter boundary, see the [Coming from SoleLogics](compatibility.md) on-ramp.

## Why many-valued logic is a parameter

Boolean, Gödel, and Łukasiewicz models share one evaluator. Their algebras
implement `top`, `bottom`, lattice `meet`, `join`, `fusion`, `implication`, and
`negation`; the
DAG walk calls those operations and stores either a `BitVector` or a
`Vector{T}`. This avoids three nearly-identical propositional/modal
implementations and makes a new finite chain an algebra value, not a new syntax
hierarchy.

This is an API decision, not a claim that classical normal forms remain
many-valued equivalences: [`to_cnf`](@ref) and [`to_dnf`](@ref) are explicitly
classical and treat modal subformulas as propositional letters. Goranko's
truth-table and logical-equivalence treatment (§§1.1, 1.3, pp. 1–17, 28–33)
[goranko2016; §§1.1, 1.3, pp. 1–17, 28–33](@cite) is the relevant classical
reference; the chain operations are the implemented algebra protocol.

## Why `Box` is not defined as the dual of `Diamond`

In Boolean modal logic, one often writes `□φ = ¬◇¬φ`. That identity is useful
as a theorem about a particular algebra and semantics; it is not a safe
implementation boundary here. The Gödel and Łukasiewicz algebras have their
own negations and residual operations, and a custom algebra need not make the
Boolean dual equation the operation used for its box.

Aletheia therefore keeps `Box(relation)` as a primitive syntactic connective.
During evaluation, diamond folds successor values with algebraic `join`, while
box folds them with the lattice `meet` (infimum). An empty successor set gives `bottom` for
diamond and `top` for box. The implementation expresses the frame semantics
directly (Blackburn et al., §1.3, pp. 17–18) [blackburn2001; §1.3, pp. 17–18](@cite),
then lets each algebra supply its operations. In Boolean models the expected
duality still holds and is tested; it is not assumed to define the other
operator.

## Parsing and printing

The parser reads the pool signature, handles infix binary notation with
precedence/associativity, and accepts prefix modal notation. The printer adds
parentheses only when needed and quotes an atom whose text would collide with a
connective or delimiter:

```jldoctest design2
using Aletheia
pool = FormulaPool(Signature((¬, ∧, →)))
f = parse(pool, "¬p → p ∧ q")
println(syntaxstring(f))
println(parse(pool, syntaxstring(f)) == f)

# output

¬p → p ∧ q
true
```

The syntax layer has no interpretation hooks. A custom connective can be
parsed and printed after defining its traits, but compound evaluation and
standard translation reject it unless a later layer defines explicit meaning.
