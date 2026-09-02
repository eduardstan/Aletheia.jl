# Relations, generated frames, and frame classes

```@meta
CurrentModule = Aletheia
```

`AletheiaCore` represents accessibility relations as values and evaluates them
through one frame protocol. This follows the relational-frame role of
accessibility in modal semantics [blackburn2001; §1.3, pp. 16–20](@cite).

## Relation families are values

A relation is data carried by `Diamond` or `Box`. The minimal extension protocol
is [`relation_holds`](@ref); the optional [`relation_successors`](@ref) hook
can enumerate successors without scanning all worlds. If the hook returns
`nothing` (the default), generated frames use the generic predicate filter.
Bounded relations may additionally implement the four-argument
`relation_holds(relation, source, target, worlds)` form. Thus an external
relation family needs a value and one method, not a new frame×relation
implementation.

```jldoctest relations
using Aletheia

struct SameParity end
Aletheia.relation_holds(::SameParity, source::Int, target::Int) =
    iseven(source) == iseven(target)

points = point_frame(1:4)
println(collect(accessible(points, 1, SameParity())))
println(collect(accessible(points, 2, SameParity())))

# output

[1, 3]
[2, 4]
```

`inverse` and `converse` provide the relation-level converse. The protocol's
orientation is `(source, target)`: `relation_holds(r, source, target)` means
that `target` is accessible from `source` by `r`, the same orientation used by
`accessible(frame, source, r)`. The returned value always satisfies
`relation_holds(inverse(r), a, b) == relation_holds(r, b, a)`; a relation whose
converse this vocabulary does not name throws an `ArgumentError` explaining why,
instead of returning a relation which is not its converse. `MINIMUM` and
`MAXIMUM` are two such values, because each relates every source to one fixed
boundary world and so has a converse relating that world to every target;
`tocenterrel` is the third, because a frame rather than a predicate defines its
target.

!!! warning
    Defining a relation in the opposite order silently changes every modal
    accessibility result.

A custom relation value does not have to subtype `RelationFamily`: implementing
`relation_holds` is sufficient. Two optional hooks refine that:

- `relation_successors(r, source, worlds)` enumerates successors directly;
  return `nothing` (the default) to request the generic predicate filter. The
  hook is trusted to return valid members of `worlds` and is not cross-checked
  against `relation_holds`.
- `relation_holds(r, source, target, worlds)` is the bounded form for point
  relations whose meaning depends on the finite domain; it keeps `MINIMUM`,
  `MAXIMUM`, and positional `SUCCESSOR`/`PREDECESSOR` consistent on sparse
  point domains.

## Allen intervals and RCC8 rectangles

Aletheia provides all thirteen Allen values in `ALLEN_RELATIONS`, including
`EQUALS`, corresponding to the thirteen relationships in Allen's Figure 2
[allen1983; §3, Figures 1–2, p. 834](@cite). The `IA32IARelations(IA_I)` member tuple intentionally excludes equality,
matching the twelve non-equality relationships in Allen's Figure 4
[allen1983; Fig. 4](@cite). `interval_frame(n)` builds every
interval over `n` cells — that is, every pair of boundaries drawn from
`1:(n + 1)` with the first strictly below the second, so `n * (n + 1) / 2`
worlds. `rectangle_frame(nx, ny)` makes all axis-aligned rectangles. Both
return the existing `Frame`; canonical interval providers use direct lazy
successor ranges for the hot `BEFORE` path while generic relation families
retain the predicate fallback.

```jldoctest relations
using Aletheia

a = Interval(1, 3)
b = Interval(3, 5)
println(relation_holds(MEETS, a, b))
println(inverse(MEETS) === MET_BY)
println(length(worlds(interval_frame(3))))
println(length(worlds(rectangle_frame(2, 2))))

# output

true
true
6
9
```

To evaluate an Allen relation as a modal operator, use the same
source-to-target orientation. In `interval_frame(3)`, `(1,2)` can meet `(2,3)`;
the valuation below marks `(2,3)` as the target proposition.

```jldoctest relations_meets
using Aletheia

intervals = interval_frame(3)
signature = Signature((Diamond(MEETS),))
pool = FormulaPool(signature)
p = atom(pool, "p")
formula = branch(pool, Diamond(MEETS), p)
target = Interval(2, 3)
model = Model(intervals, BOOLEAN, Dict("p" => Set([target])))
show(stdout, MIME"text/plain"(), intervals)
println()
println(collect(accessible(intervals, Interval(1, 2), MEETS)))
println(check(formula, model, Interval(1, 2)))
println(relation_holds(MEETS, Interval(1, 2), target))

# output

Frame (6 worlds, relations supplied on demand)
  Worlds (6): (1−2), (1−3), (1−4), (2−3), (2−4), (3−4)
  Relations: <callable>
Interval{Int64}[(2−3), (2−4)]
true
true
```

The core non-equality RCC5-style tuple `RCC5_RELATIONS` contains
`(DR, PO, PP, PPi)`. It follows the `DR` and proper-part coarsenings of the
region-connection relations defined by Randell, Cui, and Cohn [randell1992;
§4, pp. 167–168](@cite); `RCC_EQ` remains separate rather than being a fifth
tuple member. The eight-value RCC8 basis, including equality, is described in
the same source [randell1992; §4, Fig. 1, pp. 167–168](@cite) and surveyed by
Cohn et al. [cohn1997](@cite). Each generated successor set is exhaustively
checked against its predicate on small interval and rectangle domains.

## Compass logic 2D point relations

The strict eight-direction 2D point vocabulary uses the values `CL_N`,
`CL_S`, `CL_E`, `CL_W`, `CL_NE`, `CL_NW`, `CL_SE`, and `CL_SW`. Venema provides
the foundational interval/product perspective
[venema1990](@cite), while Marx and Reynolds study Compass Logic
[marx1999compass](@cite). Montanari, Puppis, and Sala give the exact
projection-based formulas for the axial `N`, `S`, `E`, and `W` relations
[montanari2015cone; §2, p. 3](@cite). The four strict quadrant directions are a
package vocabulary extension, not attributed to these sources. Aletheia has no
coincident or undetermined-direction value. The canonical tuple is
`Aletheia.POINT2D_RELATIONS`. `point_frame(nx, ny)` creates a 2D grid frame whose worlds
are `Point(x, y)`. Each relation is transitive and has a converse (for example
`converse(CL_N) === CL_S` and `converse(CL_NE) === CL_SW`).

```jldoctest relations
using Aletheia

frame2d = point_frame(3, 3)
w = Point(2, 2)
println(collect(accessible(frame2d, w, Aletheia.SoleLogics.CL_N)))
println(collect(accessible(frame2d, w, Aletheia.SoleLogics.CL_NE)))
println(converse(Aletheia.SoleLogics.CL_NE) === Aletheia.SoleLogics.CL_SW)

# output

Point[Point((2, 3))]
Point[Point((3, 3))]
true
```

`Interval(x, y)` requires `x < y`. A vector or range passed to
`interval_frame` is interpreted as the strictly increasing boundary values
themselves; `rectangle_frame(nx, ny)` applies the same rule independently on
each axis. `point_frame` is different: `point_frame(n)` has the points `1:n` as
worlds and `point_frame(range)` the given range, and the integer point
relations (`MINIMUM`, `SUCCESSOR`, `GREATER`, and so on) are bounded by that
explicit world order. The generated frames are ordinary `Frame` values, and
`accessible` remains lazy.

RCC8 has eight values in `RCC8_RELATIONS`, including `RCC_EQ`; the seven-value
`RCC8_BASICS` tuple is a convenient non-equality partition. `TPP` means that the
source is a tangential proper part of the target, while `TPPi` is its converse
(and likewise for `NTPP`/`NTPPi`). Use the RCC names when writing new code.
`rectangle_relation(x, y)` instead combines one relation per axis; it is not
itself an RCC8 value.

For compatibility aliases and migration details, see the [Coming from SoleLogics](compatibility.md) on-ramp.

## Frame classes and correspondence

Finite frames expose `isreflexive`, `istransitive`, `issymmetric`, and
`isserial`; `satisfies(frame, T, relation)` composes those traits into named
classes.

```jldoctest relations_classes
using Aletheia
base_frame = Frame((1, 2), Dict(:R => Dict(1 => [1, 2], 2 => [1, 2])); index=true)
println(isreflexive(base_frame, :R), " ", istransitive(base_frame, :R))
println(satisfies(base_frame, S5, :R))

# output

true true
true
```

Correspondence theory pairs a frame condition with an axiom schema:
reflexivity with `T`, transitivity with `4` [blackburn2001; §3.1, Definitions
3.1–3.5 and Example 3.6, pp. 125–129](@cite), as discussed also by Schwarz,
§§3.3–3.4 (pp. 53–60) [schwarz2024; §§3.3–3.4, pp. 53–60](@cite). `axioms(pool, S4; relation=:R)`
builds those schemas as formulas in your pool, and `validates` checks one on
every world of a model — so you can confirm empirically that a finite frame
validates what its class predicts. The schema generator requires the
connectives it uses to be present in the formula signature:
`K` needs `Box` and `→`, while non-`K` classes also need `Diamond` for the
serial/symmetric schemas; `axiom` additionally needs `∧` when a class has more
than one condition. These constructors return formulas in the supplied pool,
not a theorem-prover result. An empty custom `FrameClass` has no axiom schema:
`axioms` returns `()`, while `axiom` throws `ArgumentError` because there is no
single formula to return. `validates` is a model check and compares each
world's value with that algebra's `top`.

With no relation argument, a frame trait checks every named relation stored by
the frame; pass `relation=:R` (or another relation value for generated frames)
to select one. A frame with no stored relations is not reflexive, transitive,
symmetric, or serial, whereas `K` is the unconstrained class and always
satisfies. These predicates inspect finite frames and do not establish a
correspondence theorem for an infinite or callable relation.
