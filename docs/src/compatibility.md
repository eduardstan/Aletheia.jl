# Migration from SoleLogics

`Aletheia.SoleLogics` is an opt-in compatibility module. A consumer copy can
replace its old import with:

```julia
using Aletheia.SoleLogics
```

The module is nested, so these names are not added to `Aletheia` itself. It is
not a package named `SoleLogics`; a consumer's `Project.toml` and import line
must select the nested module explicitly. The scratch consumer experiment
below made only that import change and did not modify either consumer checkout.

## Scope derived from the consumers

The following inventory was obtained by scanning the checked-out source trees,
not by scanning the 79-name SoleLogics export list.

### SolePostHoc

Distinct qualified references (`SoleLogics.name`, including the `SL =
SoleLogics` alias) are: `BooleanTruth`, `DNF`, `Formula`, `IARelations`,
`LeftmostConjunctiveForm`, `LeftmostDisjunctiveForm`, `NamedConnective`,
`RCC5Relations`, `SyntaxBranch`, `atoms`, `children`, `conjuncts`,
`disjuncts`, `dnf`, `dual`, `feature`, `grandchildren`, `hasdual`, `ispos`,
`istop`, `nchildren`, `parseformula`, `token`, and `value`.

Bare names imported or used from wildcard imports in the source are:

`AbstractInterpretationSet`, `AbstractRelation`, `Atom`, `BooleanTruth`, `DNF`,
`Formula`, `LeftmostConjunctiveForm`, `LeftmostDisjunctiveForm`,
`LeftmostLinearForm`, `Literal`, `NamedConnective`, `Operator`, `SyntaxBranch`,
`SyntaxTree`, `⊤`, `∧`, `¬`, `atoms`, `alphabet`, `arity`, `children`,
`conjuncts`, `disjuncts`, `dnf`, `dual`, `feature`, `grandchildren`, `hasdual`,
`height`, `ispos`, `istop`, `name`, `nchildren`, `nconjuncts`, `nleaves`,
`noperators`, `ntokens`, `normalize`, `op`, `operators`, `parseformula`,
`relation`, `syntaxstring`, `threshold`, `token`, `tree`, `value`, and
`worldtype`. The wildcard imports in dormant algorithm directories were
included in this conservative list; the loaded `SolePostHoc` module itself
uses the syntax names in `src/shared_utils.jl` and no SoleLogics name in its
Orca path.

### SoleReasoners

Root imports and qualified references used by source, tests, and experiments
are: `Atom`, `BooleanTruth`, `Formula`, `children` (often aliased as
`subformulas`), `¬`, `∨`, `∧`, `→`, `⊥`, `height`, `isbot`, `istop`, `CL_N`,
`CL_S`, `CL_E`, `CL_W`, `HS_A`, `HS_L`, `HS_B`, `HS_E`, `HS_D`, `HS_O`,
`HS_Ai`, `HS_Li`, `HS_Bi`, `HS_Ei`, `HS_Di`, `HS_Oi`, `LRCC8_Rec_DC`,
`LRCC8_Rec_EC`, `LRCC8_Rec_PO`, `LRCC8_Rec_TPP`, `LRCC8_Rec_TPPi`,
`LRCC8_Rec_NTPP`, `LRCC8_Rec_NTPPi`, `LTLFP_F`, `LTLFP_P`, `Truth`,
`syntaxstring`, `token`, `NamedConnective`, `BoxRelationalConnective`,
`DiamondRelationalConnective`, `relation`, `arity`, `collatetruth`, and
`sample`.

The nested `ManyValuedLogics` imports are `FiniteFLewAlgebra`, `FiniteTruth`,
`succeedeq`, `precedeq`, `getdomain`, `maximalmembers`, `minimalmembers`,
`booleanalgebra`, `G3`, `G4`, `G5`, `G6`, `H4`, `H6`, `H6_1`, `H6_2`, `H6_3`,
`H9`, `Ł3`, `Ł4`, `α`, and `β`.

## Mapping table

| Incumbent name | Compatibility result |
| --- | --- |
| `Formula`, `SyntaxStructure`, `SyntaxTree` | `Aletheia.Formula`; formulas are pool-local DAG handles. |
| `Atom(value)` | `Aletheia.Atom`, with a migration-only default pool. New code should use `atom(pool, value)`. |
| `SyntaxBranch(op, children...)` | `Aletheia.Branch` over the children's pool; children are repooled when a modal connective is added. |
| `children`, `value`, `token`, `tree` | `children`/`value` are direct; `token` returns the atom itself for a leaf and `operator` for a branch; `tree` is identity. |
| `syntaxstring`, `arity`, `nchildren`, `height`, `atoms`, `leaves`, `operators`, `ntokens`, `natoms`, `nleaves`, `nconnectives`, `noperators` | Tree-walk adapters over ordinary Aletheia formulas. Display-only Sole keywords are accepted and ignored. |
| `parseformula` | Parses through an explicit compatibility pool; `atom_parser` callbacks returning a compatibility `Atom` are unwrapped to their payload. |
| `dnf`, `cnf` | Aletheia's classical normal forms, returning ordinary pooled formulas. |
| `dual`, `hasdual`, `arity`, `relation` | Direct for Aletheia connective values (`¬`, `∧`, `∨`, `→`, `Diamond`, `Box`). |
| `∧`, `∨`, `¬`, `→`, `NamedConnective`, `Operator` | Standard values map directly; parameterized `NamedConnective{:symbol}` construction does not. |
| `Interval`, `Interval2D`, `Point`, `Point1D`, `Point2D`, `FullDimensionalFrame`, `IA_*`, `IARelations` | Data-level aliases to Aletheia's dimensional and Allen APIs. `IARelations` keeps Sole's 12-value order and excludes `EQUALS`. |
| `diamond`, `box`, `TruthDict`, `KripkeStructure`, `allworlds`, `accessibles` | Small adapters to `Diamond`/`Box`, `Valuation`/Boolean `Model`, and lazy frame access (the latter is collected). |
| `ManyValuedLogics` | Exists as a nested namespace. Aletheia's `BooleanAlgebra`, `GodelAlgebra`, and `LukasiewiczAlgebra` are available; old tableau algebras are not. |

## Deliberate gaps

* `Truth`/`BooleanTruth`/`⊤`/`⊥` are markers only. Aletheia deliberately
  keeps truth carriers out of syntax, so constructing `Atom(⊤)` or parsing a
  truth leaf raises an `ArgumentError` explaining the mismatch. This is the
  central old-identity gap.
* `LeftmostLinearForm`, `LeftmostConjunctiveForm`,
  `LeftmostDisjunctiveForm`, `Literal`, `DNF`, and `CNF` have no faithful
  wrapper. Aletheia uses ordinary binary branches in a hash-consed DAG;
  container construction and `ispos` therefore raise explicit errors. The
  helper names `grandchildren`, `conjuncts`, `disjuncts`, and `nconjuncts`
  remain useful shallow/flattened views over ordinary formulas, and `dnf`/`cnf`
  are available with their Aletheia representation.
* `NamedConnective{:symbol}` dispatch, `BoxRelationalConnective`/
  `DiamondRelationalConnective` type-parameter dispatch, and the old
  `collatetruth` protocol have no Aletheia counterpart. Connectives are values
  with extensible traits, and semantic operations belong to `TruthAlgebra`.
* `AbstractInterpretationSet`, `alphabet`, `feature`, `condition`, `threshold`,
  and `normalize` are SoleData/SoleModels concepts. They raise clear errors;
  they are not approximated by syntax payload inspection.
* `RCC5Relations` is intentionally absent from Aletheia's selected RCC8
  fragment. The `RCC5Relations` binding is an error-producing marker. The
  `CL_*`, `HS_*`, `LRCC8_Rec_*`, and `LTLFP_*` names and the many-valued tableau
  order helpers similarly remain explicit semantic gaps.
* Aletheia formula equality is pool-local and `subterms` are distinct DAG IDs;
  Sole tree-occurrence equality and ordering are not silently redefined.
  `subformulas` here returns formula handles in dependency/height order.
* Existing consumers still say `using SoleLogics`. This layer cannot satisfy a
  top-level package import without changing that import (or adding a separate
  package, which this task deliberately does not do).

## Evidence

A scratch copy of `SolePostHoc/src/shared_utils.jl` was loaded in a small module
with SoleData/SoleModels test doubles and `using Aletheia.SoleLogics`; the copy
was not committed and the consumer checkout was not modified. The loaded
consumer functions `_element_to_string`, its `Atom`/`SyntaxBranch` traversal,
and its parser callback all ran successfully. The `dnf_to_syntaxbranch` path
could not be attempted because it requires the deliberately unsupported
leftmost wrappers. The package tests exercise the mapped surface directly in
`test/compatibility.jl`; they do not add either Sole package as a dependency.

```@docs
Aletheia.SoleLogics
```

```@autodocs
Modules = [Aletheia.SoleLogics]
Order = [:type, :function, :constant]
```
