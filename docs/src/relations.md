# Relations, generated frames, and frame classes

```@meta
CurrentModule = Aletheia
```


## Relation families are values

A relation is data carried by `Diamond` or `Box`. The minimal extension protocol
is [`relation_holds`](@ref); the optional [`relation_successors`](@ref) hook
can enumerate successors without scanning all worlds. If the hook returns
`nothing` (the default), generated frames use the generic predicate filter.
Bounded relations may additionally implement the four-argument
`relation_holds(relation, source, target, worlds)` form. Thus an external
relation family needs a value and one method, not a new frame×relation
implementation.

```@example relations
using Aletheia

struct SameParity end
Aletheia.relation_holds(::SameParity, source::Int, target::Int) =
    iseven(source) == iseven(target)

frame = point_frame(1:4)
println(collect(accessible(frame, 1, SameParity())))
println(collect(accessible(frame, 2, SameParity())))
```

```text
[1, 3]
[2, 4]
```

`inverse` and `converse` provide the relation-level converse. The protocol's
orientation is `(source, target)`: `relation_holds(r, source, target)` means
that `target` is accessible from `source` by `r`. This orientation is the same
one used by `accessible(frame, source, r)`, so defining a relation in the
opposite order silently changes every modal accessibility result. A custom
relation value does not have to subtype `RelationFamily`: implementing
`relation_holds` is sufficient. If a custom family can enumerate successors,
it may additionally implement `relation_successors(r, source, worlds)`; return
`nothing` (the default) to request the generic predicate filter. A successor
hook is trusted to return valid members of `worlds` and is not cross-checked
against `relation_holds`. Point relations whose meaning is bounded by a finite
domain use `relation_holds(r, source, target, worlds)`; this keeps `MINIMUM`,
`MAXIMUM`, and positional `SUCCESSOR`/`PREDECESSOR` consistent on sparse point
domains.

## Allen intervals and RCC8 rectangles

Aletheia provides all thirteen Allen values in `ALLEN_RELATIONS`, including
`EQUALS`, and compatibility `IA_*` spellings. `interval_frame(n)` makes all
intervals over `n` cells; `rectangle_frame(nx, ny)` makes all axis-aligned
rectangles. Both return the existing `Frame`, so the evaluator and model cache
are unchanged. The RCC8 implementation includes the formal eighth relation
`RCC_EQ`; `RCC8_BASICS` retains the seven-value compatibility list.

```@example relations
using Aletheia

a = Interval(1, 3)
b = Interval(3, 5)
println(relation_holds(MEETS, a, b))
println(inverse(MEETS) === MET_BY)
println(length(worlds(interval_frame(3))))
println(length(worlds(rectangle_frame(2, 2))))
```

```text
true
true
6
9
```

To evaluate an Allen relation as a modal operator, use the same source-to-target
orientation. `interval_frame(3)` enumerates closed integer intervals whose endpoints
are chosen from `1:4`, so `(1,2)` can meet `(2,3)`; the valuation below marks
`(2,3)` as the target proposition.

```@example relations_meets
using Aletheia

frame = interval_frame(3)
signature = Signature((Diamond(MEETS),))
pool = FormulaPool(signature)
p = atom(pool, "p")
formula = branch(pool, Diamond(MEETS), p)
target = Interval(2, 3)
model = Model(frame, BOOLEAN, Dict("p" => Set([target])))
println(collect(worlds(frame)))
println(collect(accessible(frame, Interval(1, 2), MEETS)))
println(check(formula, model, Interval(1, 2)))
println(relation_holds(MEETS, Interval(1, 2), target))
```

```text
Interval{Int64}[(1−2), (1−3), (1−4), (2−3), (2−4), (3−4)]
Interval{Int64}[(2−3), (2−4)]
true
true
```

Allen and RCC8 are relation-family implementations, not claims that the five
references define those particular application fragments. RCC5 composition is
intentionally left for later work rather than exposing an incomplete API.

## Compass logic 2D point relations

Aletheia provides the eight cardinal 2D point relations from Compass logic:
`CL_N`, `CL_S`, `CL_E`, `CL_W`, `CL_NE`, `CL_NW`, `CL_SE`, and `CL_SW` in `POINT2D_RELATIONS`.
`point_frame(nx, ny)` creates a 2D grid frame whose worlds are `Point(x, y)`.
Each relation is transitive and has a converse (e.g., `converse(CL_N) === CL_S` and `converse(CL_NE) === CL_SW`).

```@example relations
using Aletheia

frame2d = point_frame(3, 3)
w = Point(2, 2)
println(collect(accessible(frame2d, w, CL_N)))
println(collect(accessible(frame2d, w, CL_NE)))
println(converse(CL_NE) === CL_SW)
```

```text
Point[(2, 3)]
Point[(3, 3)]
true
```

`Interval(x, y)` requires `x < y`. For an integer `n`, `interval_frame(n)` uses
boundaries `1:(n + 1)`, so it has `n * (n + 1) / 2` interval worlds; a vector or
range is interpreted as the strictly increasing boundary values themselves.
`rectangle_frame(nx, ny)` applies the same rule independently on each axis.
`point_frame(n)` is different: its worlds are the points `1:n`, and the
integer point relations (`MINIMUM`, `SUCCESSOR`, `GREATER`, and so on) are
bounded by that explicit world order. The generated frames are ordinary
`Frame` values, and `accessible` remains lazy.

RCC8 has eight values in `RCC8_RELATIONS`, including `RCC_EQ`; the seven-value
`RCC8_BASICS` tuple is retained only for compatibility. `TPP` means that the
source is a tangential proper part of the target, while `TPPi` is its converse
(and likewise for `NTPP`/`NTPPi`). The compatibility spellings `Topo_TPP` and
`Topo_NTPP` use the incumbent's opposite naming orientation, so
`Topo_TPP === TPPi` and `Topo_NTPP === NTPPi`. Use the RCC names when writing
new code. `rectangle_relation(x, y)` instead combines one relation per axis;
it is not itself an RCC8 value.

## Frame classes and correspondence

Finite frames expose `isreflexive`, `istransitive`, `issymmetric`, and
`isserial`; `satisfies(frame, T, relation)` composes those traits into named
classes. The standard correspondence vocabulary is discussed in Blackburn et
al., §3.1 (Definitions 3.1–3.5 and Example 3.6, pp. 125–129)
[blackburn2001; §3.1, Definitions 3.1–3.5 and Example 3.6, pp. 125–129](@cite)
and Schwarz, §§3.3–3.4 (pp. 53–60) [schwarz2024; §§3.3–3.4, pp. 53–60](@cite).

```@example relations
using Aletheia
frame = Frame((1, 2), Dict(:R => Dict(1 => [1, 2], 2 => [1, 2])); index=true)
println(isreflexive(frame, :R), " ", istransitive(frame, :R))
println(satisfies(frame, S5, :R))
```

```text
true true
true
```

`axioms(pool, S4; relation=:R)` returns the schemas `T` and `4`; `validates`
checks one of those formulas on every world of a model. The schema generator
requires the connectives it uses to be present in the formula signature:
`K` needs `Box` and `→`, while non-`K` classes also need `Diamond` for the
serial/symmetric schemas; `axiom` additionally needs `∧` when a class has more
than one condition. These constructors return formulas in the supplied pool,
not a theorem-prover result. `validates` is a model check and compares each
world's value with that algebra's `top`.

With no relation argument, a frame trait checks every named relation stored by
the frame; pass `relation=:R` (or another relation value for generated frames)
to select one. A frame with no stored relations is not reflexive, transitive,
symmetric, or serial, whereas `K` is the unconstrained class and always
satisfies. These predicates inspect finite frames and do not establish a
correspondence theorem for an infinite or callable relation.

```@docs
relation_holds
relation_successors
inverse
Point2DRelation
Interval
Rectangle
interval_frame
rectangle_frame
point_frame
FrameClass
satisfies
validates
```

