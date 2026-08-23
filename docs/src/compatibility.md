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
`CL_S`, `CL_E`, `CL_W`, `CL_NE`, `CL_NW`, `CL_SE`, `CL_SW`, `HS_A`, `HS_L`, `HS_B`, `HS_E`, `HS_D`, `HS_O`,
`HS_Ai`, `HS_Li`, `HS_Bi`, `HS_Ei`, `HS_Di`, `HS_Oi`, `LRCC8_Rec_DC`,
`LRCC8_Rec_EC`, `LRCC8_Rec_PO`, `LRCC8_Rec_TPP`, `LRCC8_Rec_TPPi`,
`LRCC8_Rec_NTPP`, `LRCC8_Rec_NTPPi`, `LTLFP_F`, `LTLFP_P`, `Truth`,
`syntaxstring`, `token`, `NamedConnective`, `BoxRelationalConnective`,
`DiamondRelationalConnective`, `relation`, `arity`, `collatetruth`, and
`sample`.

The nested `ManyValuedLogics` imports are `FiniteFLewAlgebra`, `FiniteTruth`,
`succeedeq`, `precedeq`, `getdomain`, `maximalmembers`, `minimalmembers`,
`booleanalgebra`, `G3`, `G4`, `G5`, `G6`, `H4`, `H6`, `H6_1`, `H6_2`, `H6_3`,
`H9`, `Ł3`, `Ł4`, `α`, `β`, and `BASE_MANY_VALUED_CONNECTIVES`.

## Mapping table

| Incumbent name | Compatibility result |
| --- | --- |
| `Formula`, `SyntaxStructure`, `SyntaxTree` | `Aletheia.Formula`; formulas are pool-local DAG handles. |
| `Atom` and `Atom(value)` | A compatibility `Atom <: Aletheia.Formula` wrapper is a real type for `isa`/dispatch; `Atom(value)` wraps an atom in the migration-only default pool. New code should use `atom(pool, value)`. |
| `SyntaxBranch(op, children...)` | A local compatibility constructor over `Aletheia.branch`, using the children's pool and repooling when a modal connective is added. |
| `children`, `value`, `token`, `tree` | `children`/`value` are direct; `token` returns the atom itself for a leaf and `operator` for a branch; `tree` is identity. |
| `syntaxstring`, `arity`, `nchildren`, `height`, `atoms`, `leaves`, `operators`, `ntokens`, `natoms`, `nleaves`, `nconnectives`, `noperators` | Tree-walk adapters over ordinary Aletheia formulas. Display-only Sole keywords are accepted and ignored. |
| `parseformula` | Parses through an explicit compatibility pool; `atom_parser` callbacks returning a compatibility `Atom` are unwrapped to their payload. |
| `dnf`, `cnf` | Aletheia's classical normal forms, returning ordinary pooled formulas. |
| `dual`, `hasdual`, `arity`, `relation` | Direct for Aletheia connective values (`¬`, `∧`, `∨`, `→`, `Diamond`, `Box`). |
| `∧`, `∨`, `¬`, `→`, `NamedConnective`, `Operator` | Aletheia values remain the underlying operators; compatibility connective wrappers provide `NamedConnective{:symbol}` dispatch for migrated consumers. |
| `Interval`, `Interval2D`, `Point`, `Point1D`, `Point2D`, `FullDimensionalFrame`, `IA_*`, `IARelations` | Data-level aliases to Aletheia's dimensional and Allen APIs. `IARelations` keeps Sole's 12-value order and excludes `EQUALS`. |
| `CL_*` | Direct aliases of Aletheia's Compass 2D point relations (`CL_N`, `CL_S`, `CL_E`, `CL_W`, `CL_NE`, `CL_NW`, `CL_SE`, `CL_SW`). |
| `diamond`, `box`, `TruthDict`, `KripkeStructure`, `allworlds`, `accessible`, `accessibles` | Small adapters to `Diamond`/`Box`, `Valuation`/Boolean `Model`, and lazy frame access; callers collect explicitly when they need storage. |
| `HS_*` | Direct aliases of Aletheia's `IA_*` Allen interval relations, including inverses. |
| `LRCC8_Rec_*` | Direct aliases of Aletheia's `Topo_*` RCC8 relations; the incumbent orientation is retained (notably `Topo_TPP = TPPi`). |
| `LTLFP_F`, `LTLFP_P` | Direct aliases of Aletheia's `GREATER` and `LESSER` point relations. |
| `AbstractFrame`, `AbstractUniModalFrame`, `AbstractMultiModalFrame`, `AbstractWorld`, `AbstractWorlds`, `AnyWorld` | Direct frame/world dispatch vocabulary; `Frame` is a concrete multimodal frame and dimensional worlds subtype `AbstractWorld`. |
| `globalrel`, `identityrel`, `AtWorldRelation`, `tocenterrel`, `centralworld`, `emptyworld` | Direct natural-relation values and frame hooks, with `identityrel === IDENTITY`; special accessibility remains lazy. |
| `collateworlds`, `ismodal`, `isunary`, `isdiamond`, `isbox`, `isgrounding`, `isgrounded`, `AbstractRelationalConnective` | Aletheia's Boolean world-set collation and syntactic/relation predicates. |
| `RCC8Relations` | Direct alias to Aletheia's top-level RCC8 relation tuple. |
| `ManyValuedLogics` | Exists as a nested namespace. Finite truth values and finite FLew algebras are boundary adapters over Aletheia's `UInt8` tables; named algebras, `BASE_MANY_VALUED_CONNECTIVES`, thresholds, and tableau order helpers are available. Native Boolean/Gödel/Lukasiewicz algebras are also exposed; Sole tableau truth-carrier/order helpers remain unsupported where no faithful adapter exists. |

The poolless `Atom(value)` and `SyntaxBranch(op, children...)` spellings are
deliberate conveniences of the legacy path only. `Atom` is a compatibility
wrapper type, so `φ isa Atom` and dispatch work without adding a one-argument
constructor to `Aletheia.Atom`; the PR 11 parent-namespace opt-in regression
therefore remains intact. The hidden default pool used by `Atom` is local to
`Aletheia.SoleLogics`; formula identity and equality remain pool-local, so
these conveniences are not equivalent to threading an explicit pool through
new code. Explicit `Aletheia.atom(pool, ...)` and `Aletheia.branch(pool, ...)`
remain the core API.

## Deliberate gaps

* `Truth`/`BooleanTruth`/`⊤`/`⊥` are compatibility leaves, not ordinary
  Aletheia atoms. Direct `Atom(⊤)` construction and parsing a truth leaf still
  raise an `ArgumentError`; finite tableau leaves are handled by the nested
  `ManyValuedLogics` boundary adapter below.
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
* `RCC5Relations`, `IA3Relations`, and `IA7Relations` map directly to
  Aletheia's RCC5 and coarser Allen relation values. Compass `CL_*` names map
  directly to Aletheia's 2D point relation values. Every unsupported marker
  has its own singleton dispatch type, so one consumer method per name does
  not overwrite another; invoking a marker still raises the explicit
  symbol-specific error.
* Aletheia formula equality is pool-local and `subterms` are distinct DAG IDs;
  Sole tree-occurrence equality and ordering are not silently redefined.
  `subformulas` here returns formula handles in dependency/height order.
* Existing consumers still say `using SoleLogics`. This layer cannot satisfy a
  top-level package import without changing that import (or adding a separate
  package, which this task deliberately does not do).

## SoleReasoners propositional smoke test

A scratch import-migrated SoleReasoners checkout was run against this nested
module (the checkout is not part of this repository). Its precompilation is
clean, including consumers that define separate methods for `LTLFP_F` and
`LTLFP_P`. With the same six formulas used by the benchmark scout, every result
agrees with the incumbent:

```text
p => true
¬p => true
p∨¬p => true
p∧¬p => false
(p→q)∧p∧¬q => false
(p∨q)∧(¬p∨q) => true
```

The compatibility `check` and `interpret` forwarders deliberately accept only
positional arguments: Aletheia's core methods have no keyword-argument surface,
so advertising `kwargs...` would create calls that can never resolve (and fails
JET on Julia 1.10/1.11).

This validates the propositional tableau boundary and the finite-valued
truth-carrier boundary. `ManyValuedLogics.FiniteTruth` retains Sole's indexed
carrier identity while converting to Aletheia's `UInt8` tables only inside the
compatibility operation adapters. The named finite FLew algebras and the
threshold/order protocol therefore remain compatible without boxing Aletheia's
core evaluator values.

## Many-valued tableau bridge

The nested `ManyValuedLogics` namespace now maps Sole's finite tableau protocol:

* `FiniteTruth(index)` is an immutable boundary carrier with the incumbent
  `.index`, `istop`, `isbot`, conversion, and syntax-display behavior;
* `FiniteFLewAlgebra` wraps an Aletheia integer-table algebra and exposes
  callable `join`, `meet`, `monoid`, and `implication` operations that return
  boundary `FiniteTruth` values;
* `getdomain`, `precedeq`, `succeedeq`, `maximalmembers`, and
  `minimalmembers` follow the incumbent `order-utilities.jl` threshold code;
  native Aletheia finite algebras are accepted by the same order helpers;
* named G/Ł/H algebras, `booleanalgebra`, `α`, `β`, and
  `BASE_MANY_VALUED_CONNECTIVES` are mapped to Aletheia's shipped tables and
  connective values.

The wrapper is deliberately confined to `Aletheia.SoleLogics`. Core
`Aletheia.FiniteFLewAlgebra` evaluation still carries `UInt8` indices. Truth
leaves are constants at the compatibility `check`/`interpret` boundary rather
than valuation keys, while formulas without truth leaves take the unchanged
core path. A scratch
import-migrated SoleReasoners copy loaded `alphasat` and ran seeded HS, Compass,
RCC8, and temporal tableau calls; its selected HS suite agreed exactly with the
native SoleLogics run, including the native `nothing` timeout outcomes. The
scratch consumer was not committed.

## Allocation profile and substrate rerun

The pre-fix allocation profile used Julia's `Profile.Allocs.@profile` around ten
warm tableau decisions. Its flat report attributed repeated compatibility work
to `children` and both `_CompatChildren.iterate` methods, in addition to
`Branch`/`_compat_branch`; this directly confirmed that traversal was boxing
fresh adapters rather than the parser being the source of the search loss.
After the fix, the same profile showed no repeated `children`, branch, or
wrapper allocations; only the small iterator protocol tuples remained.
The new wrapper fields retain the payload/connective and a precomputed child
view, while the per-pool wrapper and formula caches make repeated DAG access
reuse concrete immutable handles. The compatibility tests also assert inferred
child-view types and a bounded allocation budget for 1,000 traversals.

The agreement-first 72-formula sweep was rerun with the same seed and
SoleReasoners propositional tableau. Both sides produced 72 decisions (36 SAT,
36 UNSAT); timing was discarded for no disagreement. Medians below are
Aletheia/native, and allocation counts are the corresponding native/Aletheia
medians from the paired child-process runs:

| section | before time ratio | after time ratio | before allocations | after allocations |
| --- | ---: | ---: | ---: | ---: |
| parse existing text | 0.185x | 0.117x | 645 / 146 | 459.5 / 96.5 |
| construct from recipe | 62.30x | 1.10x | 136 / 1,427 | 94 / 85 |
| pre-parsed tableau search | 2.38x | 0.78x | 340 / 1,921.5 | 144 / 116.5 |

The post-fix paired search median is below the incumbent (0.78x), rather than
quietly treating parity as success. Exact command shape, timeout/file
isolation, and the fixed seed are the same as the benchmark Evidence section
in the timing report; the profile was collected before changing the wrapper
representation and repeated after it.

## Evidence

A scratch copy of `SolePostHoc/src/shared_utils.jl` was loaded in a small module
with SoleData/SoleModels test doubles and `using Aletheia.SoleLogics`; the copy
was not committed and the consumer checkout was not modified. The loaded
consumer functions `_element_to_string`, its `Atom`/`SyntaxBranch` traversal,
and its parser callback all ran successfully. The `dnf_to_syntaxbranch` path
could not be attempted because it requires the deliberately unsupported
leftmost wrappers. The package tests exercise the mapped surface directly in
`test/compatibility.jl`; they do not add either Sole package as a dependency.
