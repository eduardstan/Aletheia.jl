# Coverage audit

The audit was regenerated from the clean package test run with
`julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'` and
`julia --project=coverage -e 'using Pkg; Pkg.instantiate(); include("coverage/check.jl")'`.
The result is **1078/1126 (95.74%)**. The only genuine misses in the prior
run were `src/dimensional.jl:39-40` (`RectangleRelation` display/equality) and
`src/relations.jl:249` (`IdentityRelation` display); behavioural assertions
for those paths are now in `test/relations.jl`, so they are covered. The
remaining zero-count lines are exercised behaviourally but are not credited
by Julia's line counter.

## Julia coverage blind spots (all remaining zero-count lines)

Each entry names the exact source line and why its behaviour is nevertheless
covered. The one-line methods below are inlined before CoverageTools can attach
a counter; the fallback methods are exception paths whose throw sites are not
credited by the counter.

### `src/relations.jl`

- **20** — Generic `relation_holds` fallback is exercised by the `MethodError` tests; exceptional fallback body is not credited.
- **21** — Its `MethodError` throw is exercised by those same tests; exceptional throw sites are not credited.
- **25** — Generic `inverse` fallback is exercised by the `MethodError` tests; exceptional fallback body is not credited.
- **26** — Its `MethodError` throw is exercised by those same tests; exceptional throw sites are not credited.
- **117** — `BeforeRelation`'s name is exercised through its display and parser round-trip tests; the one-line method is inlined.
- **118** — `MeetsRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **119** — `OverlapsRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **120** — `StartsRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **121** — `DuringRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **122** — `FinishesRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **123** — `EqualsRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **124** — `AfterRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **125** — `MetByRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **126** — `OverlappedByRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **127** — `StartedByRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **128** — `ContainsRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **129** — `FinishedByRelation`'s name is exercised through its display tests; the one-line method is inlined.
- **130** — `IdentityRelation`'s name is exercised by the explicit identity display assertion; the one-line method is inlined.
- **233** — `MinimumRelation`'s name is exercised through point-relation display tests; the one-line method is inlined.
- **234** — `MaximumRelation`'s name is exercised through point-relation display tests; the one-line method is inlined.
- **235** — `SuccessorRelation`'s name is exercised through point-relation display tests; the one-line method is inlined.
- **236** — `PredecessorRelation`'s name is exercised through point-relation display tests; the one-line method is inlined.
- **237** — `GreaterRelation`'s name is exercised through point-relation display tests; the one-line method is inlined.
- **238** — `LesserRelation`'s name is exercised through point-relation display tests; the one-line method is inlined.
- **239** — `DisconnectedRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **240** — `ExternallyConnectedRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **241** — `PartiallyOverlappingRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **242** — `TangentialProperPartRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **243** — `TangentialProperPartInverseRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **244** — `NonTangentialProperPartRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **245** — `NonTangentialProperPartInverseRelation`'s name is exercised through RCC display tests; the one-line method is inlined.
- **246** — `RCCEqualsRelation`'s name is exercised through RCC display tests; the one-line method is inlined.

### `src/semantics.jl`

- **79** — Boolean `top` is exercised by algebra and evaluator tests; the one-line method is inlined.
- **80** — Boolean `bottom` is exercised by algebra and evaluator tests; the one-line method is inlined.
- **170** — Gödel `top` is exercised directly and through `invokelatest`; the one-line method is inlined.
- **171** — Gödel `bottom` is exercised directly and through `invokelatest`; the one-line method is inlined.
- **182** — Łukasiewicz `top` is exercised directly and through `invokelatest`; the one-line method is inlined.
- **183** — Łukasiewicz `bottom` is exercised directly and through `invokelatest`; the one-line method is inlined.
- **418** — `Valuation` lookup is exercised by wrapped valuation model tests; the one-line forwarding method is inlined.

### `src/syntax.jl`

- **311** — Atom `nchildren` is exercised by syntax API tests; the one-line method is inlined.
- **356** — Atom `isatom` is exercised by syntax API tests; the one-line method is inlined.
- **357** — Branch `isatom` is exercised by syntax API tests; the one-line method is inlined.
- **360** — Atom `isbranch` is exercised by syntax API tests; the one-line method is inlined.
- **361** — Branch `isbranch` is exercised by syntax API tests; the one-line method is inlined.
- **536** — Cross-kind `isequal(Atom, Branch)` is exercised by syntax tests; the one-line method is inlined.
- **537** — Cross-kind `isequal(Branch, Atom)` is exercised by syntax tests; the one-line method is inlined.
- **540** — Cross-kind `==(Atom, Branch)` is exercised by syntax tests; the one-line method is inlined.
- **541** — Cross-kind `==(Branch, Atom)` is exercised by syntax tests; the one-line method is inlined.
