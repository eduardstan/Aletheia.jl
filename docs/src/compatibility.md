# Migration from SoleLogics

If you have code that imports SoleLogics, this page tells you what will and
will not work if you point it at Aletheia instead.

`Aletheia.SoleLogics` is an opt-in compatibility module. A consumer whose
imported names are covered can begin a trial by replacing its old import with:

```julia
using Aletheia.SoleLogics
```

The module is nested, so these names are not added to `Aletheia` itself. It is
not a package named `SoleLogics`; a consumer's `Project.toml` and import line
must select the nested module explicitly. This import change is not sufficient
for every consumer; the gap inventory and trials below record the current limits.

## Mapping table

| SoleLogics name | Compatibility result |
| --- | --- |
| `Formula`, `SyntaxStructure`, `SyntaxTree` | `Aletheia.Formula`; formulas are pool-local DAG handles. |
| `Atom` and `Atom(value)` | A compatibility `Atom <: Aletheia.Formula` wrapper is a real type for `isa`/dispatch; `Atom(value)` wraps an atom in the migration-only default pool. New code should use `atom(pool, value)`. |
| `SyntaxBranch(op, children...)` | A local compatibility constructor over `Aletheia.branch`, using the children's pool and repooling when a modal connective is added. |
| `children`, `value`, `token`, `tree` | `children`/`value` are direct; `token` returns the atom itself for a leaf and `operator` for a branch; `tree` is identity. A truth constant occurring as a leaf comes back from `children` as the `Truth` itself, as in SoleLogics, not as an `Atom` wrapping one. |
| `syntaxstring`, `arity`, `nchildren`, `height`, `atoms`, `leaves`, `operators`, `ntokens`, `natoms`, `nleaves`, `nconnectives`, `noperators` | Tree-walk adapters over ordinary Aletheia formulas. Display-only Sole keywords are accepted and ignored. |
| `parseformula` | Parses through an explicit compatibility pool; `atom_parser` callbacks returning a compatibility `Atom` are unwrapped to their payload. |
| `dnf`, `cnf` | Aletheia's classical normal forms, returned in SoleLogics' `DNF`/`CNF` leftmost containers of `Literal`s. `tree` folds one back into an ordinary pooled formula. |
| `LeftmostLinearForm`, `LeftmostConjunctiveForm`, `LeftmostDisjunctiveForm`, `DNF`, `CNF`, `Literal`, `ispos`, `grandchildren`, `ngrandchildren`, `connective`, `pushconjunct!` | Module-local containers over ordinary Aletheia formulas: a connective in the type parameter and a flat `grandchildren` vector. Nothing is interned in a pool; `tree` folds a container into binary branches, and `check` goes through that fold. |
| `AbstractAlphabet`, `ExplicitAlphabet`, `UnionAlphabet`, `atoms`, `natoms`, `subalphabets`, `randatom` | Alphabets of Aletheia atoms, with SoleLogics' accessor protocol. |
| `randformula` | SoleLogics' generator over Aletheia formulas; `mode`, `basecase`, `opweights`, `atompicker`, `maxmodaldepth` and `earlystoppingtreshold` keep their meaning. The caller supplies the generator, since Aletheia has no dependency to build one from a seed. |
| `dual`, `hasdual`, `arity`, `relation` | Direct for Aletheia connective values (`¬`, `∧`, `∨`, `→`, `Diamond`, `Box`). |
| `∧`, `∨`, `¬`, `→`, `NamedConnective`, `Operator`, `Connective` | Aletheia values remain the underlying operators; compatibility connective wrappers provide `NamedConnective{:symbol}` dispatch, and `NamedConnective{:∧}()` constructs the wrapper for the four base connectives. `Operator`/`Connective` are the union of those wrappers with Aletheia's own connective values, so `Vector{Connective}` and `x isa Operator` behave as consumers expect. |
| `Interval`, `Interval2D`, `Point`, `Point1D`, `Point2D`, `FullDimensionalFrame`, `Full1DFrame`, `Full2DFrame`, `Full1DPointFrame`, `Full2DPointFrame`, `IA_*`, `IARelations` | Data-level aliases to Aletheia's dimensional and Allen APIs. `IARelations` keeps Sole's 12-value order and excludes `EQUALS`. |
| `CL_*` | Direct aliases of Aletheia's Compass 2D point relations (`CL_N`, `CL_S`, `CL_E`, `CL_W`, `CL_NE`, `CL_NW`, `CL_SE`, `CL_SW`). |
| `diamond`, `box`, `TruthDict`, `KripkeStructure`, `allworlds`, `accessible`, `accessibles` | Small adapters to `Diamond`/`Box`, `Valuation`/Boolean `Model`, and lazy frame access; callers collect explicitly when they need storage. |
| `HS_*` | Direct aliases of Aletheia's `IA_*` Allen interval relations, including inverses. |
| `LRCC8_Rec_*` | Direct aliases of the core RCC8 values with SoleLogics' orientation (notably `Topo_TPP = TPPi`). |
| `LTLFP_F`, `LTLFP_P` | Direct aliases of Aletheia's `GREATER` and `LESSER` point relations. |
| `AbstractFrame`, `AbstractUniModalFrame`, `AbstractMultiModalFrame`, `AbstractWorld`, `AbstractWorlds`, `AnyWorld` | Direct frame/world dispatch vocabulary; `Frame` is a concrete multimodal frame and dimensional worlds subtype `AbstractWorld`. |
| `globalrel`, `identityrel`, `AtWorldRelation`, `tocenterrel`, `centralworld`, `emptyworld` | Direct natural-relation values and frame hooks, with `identityrel === IDENTITY`; special accessibility remains lazy. |
| `collateworlds`, `ismodal`, `isunary`, `isdiamond`, `isbox`, `isgrounding`, `isgrounded`, `AbstractRelationalConnective` | Aletheia's Boolean world-set collation and syntactic/relation predicates. |
| `RCC8Relations` | SoleLogics' seven-value compatibility tuple, using its `Topo_*` orientation. The core `RCC8_RELATIONS` has eight values and includes `RCC_EQ`. |
| `Topo_DC`, `Topo_EC`, `Topo_PO`, `Topo_TPP`, `Topo_TPPi`, `Topo_NTPP`, `Topo_NTPPi`, `Topo_DR`, `Topo_PP`, `Topo_PPi` | Sole-oriented aliases to core relation values. Proper-part names retain SoleLogics' converse orientation; `LRCC8_Rec_*` aliases the same singletons. |
| `ManyValuedLogics` | Exists as a nested namespace. Finite truth values and finite FLew algebras are boundary adapters over Aletheia's `UInt8` tables; named algebras, `BASE_MANY_VALUED_CONNECTIVES`, thresholds, and tableau order helpers are available. Native Boolean/Gödel/Lukasiewicz algebras are also exposed; Sole tableau truth-carrier/order helpers remain unsupported where no faithful adapter exists. |

The poolless `Atom(value)` and `SyntaxBranch(op, children...)` spellings are
deliberate conveniences of the legacy path only. `Atom` is a compatibility
wrapper type, so `φ isa Atom` and dispatch work without adding a one-argument
constructor to `Aletheia.Atom`. That matters because adding one would leak a
poolless constructor into the top-level `Aletheia` namespace, which the
compatibility layer is designed to keep opt-in; a regression test guards it. The hidden default pool used by `Atom` is local to
`Aletheia.SoleLogics`; formula identity and equality remain pool-local, so
these conveniences are not equivalent to threading an explicit pool through
new code. Explicit `Aletheia.atom(pool, ...)` and `Aletheia.branch(pool, ...)`
remain the core API.

## Deliberate gaps

* `Truth`/`BooleanTruth`/`⊤`/`⊥` are compatibility leaves, not ordinary
  Aletheia atoms. Direct `Atom(⊤)` construction and parsing a truth leaf still
  raise an `ArgumentError`; finite tableau leaves are handled by the nested
  `ManyValuedLogics` boundary adapter below. Inside a formula a truth constant
  is stored as an ordinary pool payload — the core evaluator never sees a boxed
  truth — but every accessor hands it back as the `Truth`. Consumers branch on
  the child object's type, so an `Atom` there would be a semantic change, not a
  representation detail.
* `BoxRelationalConnective`/`DiamondRelationalConnective` type-parameter
  dispatch and the old `collatetruth` protocol have no Aletheia counterpart.
  Connectives are values with extensible traits, and semantic operations belong
  to `TruthAlgebra`.
* `normalize` is not reproduced. SoleLogics' rewriting profiles
  (`allow_atom_flipping`, `prefer_implications`, and the rest) are a different
  normalization semantics from Aletheia's; conversion here is explicit through
  `cnf` and `dnf`.
* `AbstractInterpretationSet` and `LogicalInstance` are SoleData/SoleModels
  concepts that remain unresolved here. `feature`, `condition`, and `threshold`
  are also SoleData/SoleModels concepts; they raise clear errors rather than
  being approximated by syntax payload inspection. `alphabet` answers for an
  alphabet or a vector of atoms and still raises for a dataset, because the
  alphabets a learner actually builds are SoleData objects over
  `ScalarCondition` payloads.
* `RCC5Relations`, `IA3Relations`, and `IA7Relations` map to Aletheia's
  canonical RCC5 and coarser Allen relation values. The compatibility RCC5
  tuple retains SoleLogics' `Topo_PP`/`Topo_PPi` orientation. Compass `CL_*` names map
  directly to Aletheia's 2D point relation values. Every unsupported marker
  has its own singleton dispatch type, so one consumer method per name does
  not overwrite another; invoking a marker still raises the explicit
  symbol-specific error.
* Aletheia formula equality is pool-local and `subterms` are distinct DAG IDs;
  Sole tree-occurrence equality and ordering are not silently redefined.
  `subformulas` here returns formula handles in dependency/height order.
* Existing consumers still say `using SoleLogics`. This layer cannot satisfy a
  top-level package import without changing that import. Publishing a separate
  package named `SoleLogics` would satisfy it, and Aletheia deliberately does
  not do that.
* The compatibility `check` and `interpret` forwarders accept positional
  arguments only. Aletheia's core methods have no keyword arguments, so
  accepting `kwargs...` would advertise calls that can never resolve.

## Consumer import gaps

A replay of the four consumers' literal SoleLogics imports resolves 107 of 142
bindings. The 25 distinct unresolved names (commented-out imports excluded) are:

```text
AbstractAssignment  AbstractDimensionalFrame  AbstractInterpretation
AbstractKripkeStructure  CONJUNCTION  CheckAlgorithm
Full0DFrame  Full1DFrame  Full2DFrame  LogicalInstance  OneWorld  Point3D
SyntaxToken  X  Y  Z  composeformulas  frametype  intervals2D_in
intervals_in  ndisjuncts  nparameters  nworlds  short_intervals_in valuetype
```

These gaps span SoleLogics vocabulary and consumer-facing type/value names;
they are not limited to the deliberate semantic gaps below.

## Measured top-level export cut

The pre-change top-level inventory contained 436 exported names. The measured
alias audit found 69 duplicate-constant classes covering 187 names, about 25
function aliases, and 66 names referenced only once. We retained the canonical
names used by the compatibility layer, the SoleData extension, and the four
consumer scans, and removed unused migration spellings and implementation
storage accessors. The direct-import scan found 151 distinct names: 101 were
resolved and 50 were already outside Aletheia's supported surface. The nested
`ManyValuedLogics` scan is separate: SoleReasoners imports 22 names, including
12 named algebras now exported from that nested module. The replay above is an
occurrence-level 107/142 result; it is not intended to add to the 151-name
union count.

The resulting core exports are intentionally smaller. In particular, tables,
DAG records, valuation plumbing, SoleLogics aliases, and `Topo_*` spellings
are accessed through qualified compatibility or internal names rather than
being added to the flat `using Aletheia` namespace.

## What downstream packages actually use

Two packages depend heavily on SoleLogics: SolePostHoc and SoleReasoners. The
lists below come from scanning their source trees rather than SoleLogics'
79-name export list, so they describe the surface that migration actually has
to cover.

### SolePostHoc

Distinct qualified references (`SoleLogics.name`, including the
`SL = SoleLogics` alias):

```text
BooleanTruth  DNF  Formula  IARelations  LeftmostConjunctiveForm
LeftmostDisjunctiveForm  NamedConnective  RCC5Relations  SyntaxBranch
atoms  children  conjuncts  disjuncts  dnf  dual  feature  grandchildren
hasdual  ispos  istop  nchildren  parseformula  token  value
```

Bare names imported or used from wildcard imports in the source:

```text
AbstractInterpretationSet  AbstractRelation  Atom  BooleanTruth  DNF  Formula
LeftmostConjunctiveForm  LeftmostDisjunctiveForm  LeftmostLinearForm  Literal
NamedConnective  Operator  SyntaxBranch  SyntaxTree  ⊤  ∧  ¬  atoms  alphabet
arity  children  conjuncts  disjuncts  dnf  dual  feature  grandchildren
hasdual  height  ispos  istop  name  nchildren  nconjuncts  nleaves
noperators  ntokens  normalize  op  operators  parseformula  relation
syntaxstring  threshold  token  tree  value  worldtype
```

The wildcard imports in dormant algorithm directories were included in this
conservative list; the loaded `SolePostHoc` module itself uses the syntax names
in `src/shared_utils.jl` and no SoleLogics name in its Orca path.

### SoleReasoners

Root imports and qualified references used by source, tests, and experiments:

```text
Atom  BooleanTruth  Formula  children (often aliased as subformulas)
¬  ∨  ∧  →  ⊥  height  isbot  istop
CL_N  CL_S  CL_E  CL_W  CL_NE  CL_NW  CL_SE  CL_SW
HS_A  HS_L  HS_B  HS_E  HS_D  HS_O  HS_Ai  HS_Li  HS_Bi  HS_Ei  HS_Di  HS_Oi
LRCC8_Rec_DC  LRCC8_Rec_EC  LRCC8_Rec_PO  LRCC8_Rec_TPP  LRCC8_Rec_TPPi
LRCC8_Rec_NTPP  LRCC8_Rec_NTPPi  LTLFP_F  LTLFP_P  Truth  syntaxstring  token
NamedConnective  BoxRelationalConnective  DiamondRelationalConnective
relation  arity  collatetruth  sample
```

The nested `ManyValuedLogics` imports:

```text
FiniteFLewAlgebra  FiniteTruth  succeedeq  precedeq  getdomain
maximalmembers  minimalmembers  booleanalgebra  G3  G4  G5  G6
H4  H6  H6_1  H6_2  H6_3  H9  Ł3  Ł4  α  β  BASE_MANY_VALUED_CONNECTIVES
```

## Where the remaining gaps are

The four consumers below were scanned for every name they take from
SoleLogics, and each name was checked against this module. The complete
unresolved enumeration is above; what those gaps mean is not one thing but
several different kinds of limitation.

### Genuinely SoleLogics, and now covered

Leftmost containers and `Literal`, `NamedConnective{:sym}()` construction,
alphabets, `randatom` and `randformula`. These are syntax-level concepts, so
this module can supply them over ordinary Aletheia formulas without the core
learning about them.

### Genuinely SoleLogics vocabulary, not yet covered

Examples of unresolved logic-level names are `SyntaxToken`, `CONJUNCTION`,
`composeformulas`, `ndisjuncts`, `nparameters`, `nworlds`, `frametype`,
`valuetype`, `AbstractKripkeStructure`, `AbstractInterpretation`,
`Full0DFrame`, `Full1DFrame`, `Full2DFrame`, `Point3D`, `intervals_in`,
`short_intervals_in`, and `intervals2D_in`.

### SoleData or SoleModels concepts reached through SoleLogics

`feature`, `condition`, `threshold`, and the alphabets a learner actually
builds — `UnionAlphabet`s of `Atom{ScalarCondition}` produced by
`alphabet(::AbstractLogiset)`. `AbstractInterpretationSet` and
`LogicalInstance` remain unresolved here; the other values do not come from a
logic library.
`ModalDecisionLists` imports `AbstractAlphabet`, `UnionAlphabet` and
`alphabet` from **SoleData**, not from SoleLogics, and
`ModalDecisionTrees` takes `OneWorld` and `Worlds` from SoleData as well.
Substituting under the learners is therefore a SoleData/SoleModels question,
not a question about this module.

### Left to the maintainer

`collatetruth` and the `normalize` rewriting profiles. Both are semantics, not
vocabulary: `collatetruth` asks for truth values that are formulas, and
`normalize` asks for a rewriting calculus that differs from Aletheia's. Either
would change the core, so both stay documented gaps above.

The import replay above is the authoritative list of unresolved names; the
consumer trials below show the practical effect for SoleReasoners and
SolePostHoc.

## Many-valued tableau bridge

The nested `ManyValuedLogics` namespace maps SoleLogics' finite tableau
protocol:

* `FiniteTruth(index)` is an immutable boundary carrier with SoleLogics'
  `.index`, `istop`, `isbot`, conversion, and syntax-display behavior;
* `FiniteFLewAlgebra` wraps an Aletheia integer-table algebra and exposes
  callable `join`, `meet`, `monoid`, and `implication` operations that return
  boundary `FiniteTruth` values;
* `getdomain`, `precedeq`, `succeedeq`, `maximalmembers`, and
  `minimalmembers` follow SoleLogics' `order-utilities.jl` threshold code;
  native Aletheia finite algebras are accepted by the same order helpers;
* named G/Ł/H algebras, `booleanalgebra`, `α`, `β`, and
  `BASE_MANY_VALUED_CONNECTIVES` are mapped to Aletheia's shipped tables and
  connective values.

The wrapper is deliberately confined to `Aletheia.SoleLogics`. Core
`Aletheia.FiniteFLewAlgebra` evaluation still carries `UInt8` indices. Truth
leaves are constants at the compatibility `check`/`interpret` boundary rather
than valuation keys, while formulas without truth leaves take the unchanged
core path. `ManyValuedLogics.FiniteTruth` retains SoleLogics' indexed carrier
identity while converting to Aletheia's `UInt8` tables only inside the
compatibility operation adapters, so the named finite FLew algebras and the
threshold/order protocol remain compatible without boxing Aletheia's core
evaluator values.

## Trials against real consumers

The trials use different harnesses. The SoleReasoners trial used a local copy
of the consumer package with only its `using SoleLogics` line changed to
`using Aletheia.SoleLogics`. SolePostHoc does not precompile against this module:
two type-position blockers remain, where `SyntaxBranch` and
`AbstractInterpretationSet` are used as types. Its subsection is a single-file
harness with SoleData/SoleModels test doubles, not a package trial. The copies
are not part of this repository.

### SoleReasoners

Precompilation of the modified copy is clean, including consumers that define
separate methods for `LTLFP_F` and `LTLFP_P`. Using the same six formulas as
the benchmark's differential suite, every result agrees with SoleLogics:

```text
p => true
¬p => true
p∨¬p => true
p∧¬p => false
(p→q)∧p∧¬q => false
(p∨q)∧(¬p∨q) => true
```

The many-valued Halpern–Shoham tableau was then compared decision by decision,
because it is the workload that exercises truth constants as formula leaves.
Formulas were generated once with SoleLogics' `randformula` using the upstream
experiment's own basecase (`aot = vcat(myalphabet, getdomain(algebra))`,
`experiments/alphasat/mvhs-tableau.jl:87-89`) and translated structurally, so
both substrates decide the identical formula; node selection is deterministic
(`roundrobin!`, `distancefromroot`, `formulaheight`), since the package default
seeds its own generator. 64 decisions over eight algebra/height configurations,
42 of them carrying at least one truth-constant leaf (68 such leaves, all handed
back as `Truth`):

| outcome | decisions |
| --- | ---: |
| both substrates returned a verdict | 42 |
| — of which the verdicts differ | **0** |
| both returned `nothing` (undetermined) | 17 |
| SoleLogics returned `nothing`, Aletheia a verdict | 5 |

`alphasat` returns `nothing` only from its wall-clock timeout and its
out-of-memory bail (`alphasat.jl:124`, `:134`, `:566`, `:571`, `:890`, `:895`);
the unsatisfiable answer is a distinct `false` at `alphasat.jl:137`. So
`nothing` means *undetermined within the budget*, never *no*. Each of the five
was re-run with a 600 s budget instead of 20 s, and SoleLogics then returned the
same verdict Aletheia had: `⟨L̅⟩p`, `⟨D̅⟩[L]r`, `⟨D⟩[E̅]p`, `⟨O̅⟩r ∧ [B](⊤)` and
`⟨D⟩[E̅]p` all `true` on both sides. **Every decision either substrate
determined agrees; none differ.**

Two limits on that sentence. The 17 undetermined decisions are evidence of
nothing either way — neither substrate answered. And which decisions fall in the
five is a wall-clock fact, not a capability difference: those cases needed
18.9–28.5 s against a 20 s budget on a box whose load average moved from 3.79 to
5.35 during the sweep, so under different load the membership of that set would
change. Nothing here supports a performance claim; a paired, load-controlled
measurement is a separate exercise.

### SolePostHoc

A local copy of `SolePostHoc/src/shared_utils.jl` was loaded in a small module
with SoleData/SoleModels test doubles and `using Aletheia.SoleLogics`; the
SolePostHoc checkout itself was not modified. The loaded consumer functions
`_element_to_string`, its `Atom`/`SyntaxBranch` traversal, and its parser
callback all ran successfully. Its `dnf_to_syntaxbranch` chain — `dnf`, then
`.grandchildren`, `.ispos`/`.atom`, and `SyntaxBranch(NamedConnective{:∨}(),
…)` — now runs as well; `test/compatibility.jl` keeps that chain verbatim in
shape. The tests add neither Sole package as a dependency.

## Where the compatibility layer spent its time

Allocation profiling over ten warm tableau decisions showed that the cost was
in traversal, not parsing: the compatibility `children` accessor was allocating
a fresh adapter object on every access. The wrapper now retains the payload,
the connective, and a precomputed child view, and per-pool caches let repeated
DAG access reuse the same immutable handles. The compatibility tests assert
both the inferred child-view types and a bounded allocation budget for 1,000
traversals.

The agreement-first 72-formula sweep was rerun with the same seed and
SoleReasoners propositional tableau. Both sides produced 72 decisions (36 SAT,
36 UNSAT); timing was discarded for no disagreement.

This table inverts the convention used on the [measured results](results.md)
page: here a time ratio is **Aletheia divided by SoleLogics**, so *below* `1×`
means Aletheia took less time. Allocation cells are **SoleLogics ; Aletheia**
medians from the paired child-process runs.

| section | before time (Aletheia ÷ SoleLogics) | after time (Aletheia ÷ SoleLogics) | before allocations | after allocations |
| --- | ---: | ---: | ---: | ---: |
| parse existing text | 0.185× | 0.117× | 645 ; 146 | 459.5 ; 96.5 |
| construct from recipe | 62.30× | 1.10× | 136 ; 1,427 | 94 ; 85 |
| pre-parsed tableau search | 2.38× | 0.78× | 340 ; 1,921.5 | 144 ; 116.5 |

The post-fix paired search median is below SoleLogics' (0.78×), rather than
quietly treating parity as success. Command shape, timeout and file isolation,
and the fixed seed match the benchmark protocol; the profile was collected
before changing the wrapper representation and repeated after it.
