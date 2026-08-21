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
that `target` is accessible from `source` by `r`. Point relations whose meaning
is bounded by a finite domain use `relation_holds(r, source, target, worlds)`;
this keeps `MINIMUM`, `MAXIMUM`, and positional `SUCCESSOR`/`PREDECESSOR`
consistent on sparse point domains.

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
requires the connectives it uses to be present in the formula signature.

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

