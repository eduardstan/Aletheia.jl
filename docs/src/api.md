# API reference

```@meta
CurrentModule = Aletheia
```

```@docs
Aletheia.Aletheia
```

This page lists every exported name, grouped by layer. If you are looking for a
place to start, the ten names that carry most usage are `Signature`,
`FormulaPool`, `atom`, `branch`, `parse`, `syntaxstring`, `Frame`, `Model`,
`check`, and `extension`; the [Quick start](quickstart.md) uses all of them.

Migration spellings from SoleLogics are available under the opt-in
`Aletheia.SoleLogics` namespace. In the core API, `meet` is the lattice
infimum, while `fusion`/`⊗` is the monoid operation.

## Syntax and parsing

```@docs
Signature
Formula
FormulaPool
DEFAULT_SIGNATURE
DEFAULT_POOL
Atom
Branch
atom
branch
children
nchildren
value
operator
head
pool
id
isatom
isbranch
dag
subterms
nsubterms
signature
connectives
arity
dual
hasconnective
hasdual
precedence
associativity
iscommutative
ismodal
isunary
isdiamond
isbox
isgrounded
notation
relation
syntaxstring
AbstractRelationalConnective
Negation
Conjunction
Fusion
Disjunction
Implication
Diamond
Box
NEGATION
CONJUNCTION
FUSION
DISJUNCTION
IMPLICATION
(¬)
(∧)
(⊗)
(∨)
(→)
```

## Semantics and algebras

```@docs
TruthAlgebra
BooleanAlgebra
GodelAlgebra
LukasiewiczAlgebra
FiniteTruth
FiniteFLewAlgebra
BooleanFLewAlgebra
G3
G4
G5
G6
Ł3
Ł4
H4
H6
H6_1
H6_2
H6_3
H9
BOOLEAN
truth_type
carrier
top
bottom
bot
meet
join
fusion
domain
implication
negation
levels
isfinitechain
precedeq
precedes
succeedeq
succeeds
maximalmembers
minimalmembers
```

## Frames, relations, and evaluation

```@docs
RelationFamily
IntervalRelation
PointRelation
RCCRelation
RectangleRelation
relation_holds
relation_successors
inverse
converse
rectangle_relation
globalrel
identityrel
GlobalRelation
IdentityRelation
AtWorldRelation
ToCenterRelation
tocenterrel
centralworld
emptyworld
isgrounding
Interval
Rectangle
Point
interval_frame
rectangle_frame
point_frame
BEFORE
MEETS
OVERLAPS
STARTS
DURING
FINISHES
EQUALS
AFTER
MET_BY
OVERLAPPED_BY
STARTED_BY
CONTAINS
FINISHED_BY
ALLEN_RELATIONS
IDENTITY
MINIMUM
MAXIMUM
SUCCESSOR
PREDECESSOR
GREATER
LESSER
POINT_RELATIONS
DC
EC
PO
TPP
TPPi
NTPP
NTPPi
RCC_EQ
RCC8_RELATIONS
RCC8_BASICS
DR
PP
PPi
RCC5_RELATIONS
RCC5Relation
FrameClass
K
T
S4
S5
REFLEXIVE
TRANSITIVE
SYMMETRIC
SERIAL
isreflexive
istransitive
issymmetric
isserial
reflexive
transitive
symmetric
serial
satisfies
axioms
axiom
validates
AbstractFrame
AbstractUniModalFrame
AbstractMultiModalFrame
AbstractWorld
AbstractWorlds
AnyWorld
Frame
worlds
relations
hasworldindex
world_position
accessible
collateworlds
check
extension
describe
EvaluationCache
clear!
Valuation
Model
frame
algebra
valuation
interpret
AbstractModelFamily
ModelFamily
instance_count
eachinstance
instance_model
instance_frame
uniform_frame
isuniform
```

## First-order logic and theory

```@docs
FirstOrderTerm
FirstOrderFormula
Variable
Constant
FunctionTerm
Predicate
Equality
FONegation
FOConjunction
FODisjunction
FOImplication
Exists
Forall
FirstOrderInterpretation
evaluate
standard_translation
first_order_interpretation
iscnf
isdnf
to_cnf
to_dnf
bisimilar
BisimulationClass
BisimulationContraction
QuotientModel
bisimulation_contraction
contraction_world
model
classes
world_map
AbstractProver
ProverResult
PropositionalProver
FiniteModelProver
BoundedFiniteProver
prove
prove_valid
prove_entails
issatisfiable
isvalid
entails
```

## Inductive logic programming

```@docs
Literal
literal
positive_literal
negative_literal
atoms
literals
clauses
Clause
HornClause
ClauseSet
Substitution
substitute
subsumes
more_general
more_specific
equivalent_under_subsumption
ishorn
downward_refinements
upward_refinements
generalizations
ILPExample
EntailmentExample
InterpretationExample
ProofExample
learning_from_entailment
learning_from_interpretations
learning_from_proofs
interpretation_example
model_example
HypothesisScore
score
```

## Compatibility boundary

The opt-in `Aletheia.SoleLogics` module provides migration names without changing the top-level vocabulary.

```@docs
Aletheia.SoleLogics
Aletheia.SoleLogics.ManyValuedLogics.FiniteFLewAlgebra
```

```@autodocs
Modules = [Aletheia.SoleLogics]
Public = true
Private = false
Order = [:type, :function, :constant]
```
