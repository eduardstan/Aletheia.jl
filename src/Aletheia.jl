"""Umbrella package for Aletheia's focused packages."""
module Aletheia

using AletheiaCore
using AletheiaGraphs: AletheiaGraphs
using AletheiaGraphs:
    AbstractKGEntity,
    AbstractKGRelation,
    KGEntity,
    KGRelation,
    KGProvenance,
    KGEdge,
    KnowledgeGraph,
    KGPath,
    KGSubgraph,
    paths,
    subgraphs,
    path_valid,
    path_validity,
    path_provenance,
    concept_atoms,
    concept_extension
using AletheiaData
using AletheiaLearn
using AletheiaSole
using AletheiaCircuits: AletheiaCircuits
using AletheiaAudit
using AletheiaNeSy

const SoleLogics = AletheiaSole.SoleLogics
export SoleLogics

# Distribution-semantics circuits are an explicit optional layer.  The two
# names `domain` and `evaluate` remain owned by the historical umbrella API;
# use `AletheiaCircuits.domain` and `AletheiaCircuits.evaluate` when needed.
export AletheiaCircuits, AletheiaGraphs
export SymbolicArtifact, ArtifactState, ArtifactOperation, ArtifactCase, Provenance,
    TraceStep, ExecutionTrace, VerificationReport, MetricValue, MetricBundle, AuditRecord,
    ArtifactRule, RuleArtifact, TreeArtifact, eval_artifact, extract_artifact, inject!,
    verify_artifact, metric_bundle, audit, replay, serialize_trace, deserialize_trace,
    stable_hash, provenance, rules, nodes, test_interface
export NeSyContractError, InvalidNeuralValueError, MalformedCaseError, SemanticLossError,
    ChoiceLabelError, NeuralLeafValuation, SKERoundTrip, neural_valuation,
    neural_choice_labels, ske_roundtrip, semantic_loss
export AbstractKGEntity,
    AbstractKGRelation,
    KGEntity,
    KGRelation,
    KGProvenance,
    KGEdge,
    KnowledgeGraph,
    KGPath,
    KGSubgraph,
    paths,
    subgraphs,
    path_valid,
    path_validity,
    path_provenance,
    concept_atoms,
    concept_extension
const ChoiceVariable = AletheiaCircuits.ChoiceVariable
const AbstractChoiceVariable = AletheiaCircuits.AbstractChoiceVariable
const ChoiceAlternative = AletheiaCircuits.ChoiceAlternative
const ChoiceLiteral = AletheiaCircuits.ChoiceLiteral
const ProbabilisticFact = AletheiaCircuits.ProbabilisticFact
const GroundRule = AletheiaCircuits.GroundRule
const DSProgram = AletheiaCircuits.DSProgram
const AbstractDSProgram = AletheiaCircuits.AbstractDSProgram
const DSProfile = AletheiaCircuits.DSProfile
const DSQuery = AletheiaCircuits.DSQuery
const DSWorld = AletheiaCircuits.DSWorld
const alternatives = AletheiaCircuits.alternatives
const weights = AletheiaCircuits.weights
const choice_id = AletheiaCircuits.choice_id
const facts = AletheiaCircuits.facts
const choices = AletheiaCircuits.choices
const rules = AletheiaCircuits.rules
const total_choices = AletheiaCircuits.total_choices
const choice_probability = AletheiaCircuits.choice_probability
const ground = AletheiaCircuits.ground
const validate_program = AletheiaCircuits.validate_program
const world = AletheiaCircuits.world
const query_event = AletheiaCircuits.query_event
const compile_event = AletheiaCircuits.compile_event
const AbstractEvent = AletheiaCircuits.AbstractEvent
const EventSpec = AletheiaCircuits.EventSpec
const AbstractEventCircuit = AletheiaCircuits.AbstractEventCircuit
const CircuitNode = AletheiaCircuits.CircuitNode
const BDDNode = AletheiaCircuits.BDDNode
const BDD = AletheiaCircuits.BDD
const CircuitCertificate = AletheiaCircuits.CircuitCertificate
const CertifiedCircuit = AletheiaCircuits.CertifiedCircuit
const CompiledEvent = AletheiaCircuits.CompiledEvent
const support = AletheiaCircuits.support
const source_provenance = AletheiaCircuits.source_provenance
const validate = AletheiaCircuits.validate
const variable_order = AletheiaCircuits.variable_order
const roots = AletheiaCircuits.roots
const nodes = AletheiaCircuits.nodes
const EventNot = AletheiaCircuits.EventNot
const EventAnd = AletheiaCircuits.EventAnd
const EventOr = AletheiaCircuits.EventOr
const Not = AletheiaCircuits.Not
const And = AletheiaCircuits.And
const Or = AletheiaCircuits.Or
const not_event = AletheiaCircuits.not_event
const and_event = AletheiaCircuits.and_event
const or_event = AletheiaCircuits.or_event
const CircuitError = AletheiaCircuits.CircuitError
const UnsupportedFeatureError = AletheiaCircuits.UnsupportedFeatureError
const ProgramValidationError = AletheiaCircuits.ProgramValidationError
const UnnormalizedWeightsError = AletheiaCircuits.UnnormalizedWeightsError
const ZeroMassEvidenceError = AletheiaCircuits.ZeroMassEvidenceError
const UncertifiedCircuitError = AletheiaCircuits.UncertifiedCircuitError
const InvalidCircuitError = AletheiaCircuits.InvalidCircuitError
const InvalidProbabilityError = AletheiaCircuits.InvalidProbabilityError
const GroundingError = AletheiaCircuits.GroundingError
const AbstractCommutativeSemiring = AletheiaCircuits.AbstractCommutativeSemiring
const ProbabilitySemiring = AletheiaCircuits.ProbabilitySemiring
const ProbabilityProfile = AletheiaCircuits.ProbabilityProfile
const Float64Profile = AletheiaCircuits.Float64Profile
const RationalProfile = AletheiaCircuits.RationalProfile
const add = AletheiaCircuits.add
const mul = AletheiaCircuits.mul
const literal_label = AletheiaCircuits.literal_label
const neutral_sum = AletheiaCircuits.neutral_sum
const amc = AletheiaCircuits.amc
const wmc = AletheiaCircuits.wmc
const conditional_probability = AletheiaCircuits.conditional_probability
export ChoiceVariable,
    AbstractChoiceVariable,
    ChoiceAlternative,
    ChoiceLiteral,
    ProbabilisticFact,
    GroundRule,
    DSProgram,
    AbstractDSProgram,
    DSProfile,
    DSQuery,
    DSWorld
export alternatives,
    weights,
    choice_id,
    facts,
    choices,
    rules,
    total_choices,
    choice_probability,
    ground,
    validate_program,
    world,
    query_event,
    compile_event
export AbstractEvent,
    EventSpec,
    AbstractEventCircuit,
    CircuitNode,
    BDDNode,
    BDD,
    CircuitCertificate,
    CertifiedCircuit,
    CompiledEvent,
    support,
    source_provenance,
    validate,
    variable_order,
    roots,
    nodes
export EventNot, EventAnd, EventOr, Not, And, Or, not_event, and_event, or_event
export CircuitError,
    UnsupportedFeatureError,
    ProgramValidationError,
    UnnormalizedWeightsError,
    ZeroMassEvidenceError,
    UncertifiedCircuitError,
    InvalidCircuitError,
    InvalidProbabilityError,
    GroundingError
export AbstractCommutativeSemiring,
    ProbabilitySemiring,
    ProbabilityProfile,
    Float64Profile,
    RationalProfile,
    add,
    mul,
    literal_label,
    neutral_sum,
    amc,
    wmc,
    conditional_probability

export Signature,
    Formula,
    FormulaPool,
    Atom,
    Branch,
    DEFAULT_SIGNATURE,
    DEFAULT_POOL,
    atom,
    branch,
    children,
    nchildren,
    value
export operator,
    head,
    pool,
    id,
    isatom,
    isbranch,
    dag,
    subterms,
    nsubterms,
    signature,
    connectives,
    arity
export dual,
    hasconnective,
    hasdual,
    precedence,
    associativity,
    iscommutative,
    ismodal,
    isunary,
    isdiamond,
    isbox,
    isgrounded,
    notation
export relation,
    syntaxstring,
    AbstractRelationalConnective,
    Negation,
    Conjunction,
    Fusion,
    Disjunction,
    Implication,
    Diamond,
    Box,
    NEGATION,
    CONJUNCTION
export FUSION,
    DISJUNCTION,
    IMPLICATION,
    ¬,
    ∧,
    ⊗,
    ∨,
    →,
    TruthAlgebra,
    BooleanAlgebra,
    GodelAlgebra,
    LukasiewiczAlgebra
export FiniteTruth,
    FiniteFLewAlgebra, BooleanFLewAlgebra, G3, G4, G5, G6, Ł3, Ł4, H4, H6, H6_1
export H6_2,
    H6_3,
    H9,
    RelationFamily,
    IntervalRelation,
    PointRelation,
    RCCRelation,
    RectangleRelation,
    relation_holds,
    relation_successors,
    inverse,
    converse
export rectangle_relation,
    globalrel,
    identityrel,
    GlobalRelation,
    IdentityRelation,
    AtWorldRelation,
    ToCenterRelation,
    tocenterrel,
    centralworld,
    emptyworld,
    isgrounding,
    Interval
export Rectangle,
    Point,
    interval_frame,
    rectangle_frame,
    point_frame,
    BEFORE,
    MEETS,
    OVERLAPS,
    STARTS,
    DURING,
    FINISHES,
    EQUALS
export AFTER,
    MET_BY,
    OVERLAPPED_BY,
    STARTED_BY,
    CONTAINS,
    FINISHED_BY,
    ALLEN_RELATIONS,
    IDENTITY,
    MINIMUM,
    MAXIMUM,
    SUCCESSOR,
    PREDECESSOR
export GREATER,
    LESSER, POINT_RELATIONS, DC, EC, PO, TPP, TPPi, NTPP, NTPPi, RCC_EQ, RCC8_RELATIONS
export RCC8_BASICS,
    DR, PP, PPi, RCC5_RELATIONS, RCC5Relation, FrameClass, K, T, S4, S5, REFLEXIVE
export TRANSITIVE,
    SYMMETRIC,
    SERIAL,
    isreflexive,
    istransitive,
    issymmetric,
    isserial,
    reflexive,
    transitive,
    symmetric,
    serial,
    satisfies
export axioms,
    axiom, validates, BOOLEAN, truth_type, carrier, top, bottom, bot, meet, join, fusion
export domain,
    implication,
    negation,
    levels,
    isfinitechain,
    precedeq,
    precedes,
    succeedeq,
    succeeds,
    maximalmembers,
    minimalmembers,
    AbstractFrame
export AbstractUniModalFrame,
    AbstractMultiModalFrame,
    AbstractWorld,
    AbstractWorlds,
    AnyWorld,
    Frame,
    worlds,
    relations,
    hasworldindex,
    world_position,
    accessible,
    collateworlds
export check,
    extension,
    describe,
    EvaluationCache,
    clear!,
    Valuation,
    ValuationCallback,
    Model,
    frame,
    algebra,
    valuation,
    interpret,
    AbstractModelFamily
export ModelFamily,
    instance_count,
    eachinstance,
    instance_model,
    AbstractScalarDataset,
    AbstractScalarFeature,
    AbstractScalarCondition,
    AbstractAggregateMemo,
    ThresholdCondition,
    DenseFeatureStore,
    PreparedScalarData,
    AggregateMemoStore
export ScalarEvaluationCache,
    ScalarRelationIndex,
    prepare_scalar,
    feature_value,
    scalar_check,
    scalar_atom_values,
    scalar_valuation,
    scalar_family,
    aggregate_value,
    representative_worlds,
    data_version,
    batch_apply
export source,
    store,
    one_step_memos,
    relation_index,
    feature_index,
    instance_index,
    features,
    instances,
    world_index,
    instance_frame,
    uniform_frame,
    isuniform
export FirstOrderTerm,
    FirstOrderFormula,
    Variable,
    Constant,
    FunctionTerm,
    Predicate,
    Equality,
    FONegation,
    FOConjunction,
    FODisjunction,
    FOImplication,
    Exists
export Forall,
    FirstOrderInterpretation,
    evaluate,
    standard_translation,
    first_order_interpretation,
    Literal,
    literal,
    positive_literal,
    negative_literal,
    atoms,
    literals,
    clauses
export Clause,
    HornClause,
    ClauseSet,
    Substitution,
    substitute,
    subsumes,
    more_general,
    more_specific,
    equivalent_under_subsumption,
    ishorn,
    downward_refinements,
    upward_refinements
export generalizations,
    HypothesisScore,
    score,
    ILPExample,
    EntailmentExample,
    InterpretationExample,
    ProofExample,
    learning_from_entailment,
    learning_from_interpretations,
    learning_from_proofs,
    interpretation_example,
    model_example
export iscnf,
    isdnf,
    to_cnf,
    to_dnf,
    bisimilar,
    BisimulationClass,
    BisimulationContraction,
    QuotientModel,
    bisimulation_contraction,
    contraction_world,
    model,
    classes
export world_map,
    AbstractProver,
    ProverResult,
    PropositionalProver,
    FiniteModelProver,
    BoundedFiniteProver,
    prove,
    prove_valid,
    prove_entails,
    issatisfiable,
    isvalid,
    entails

# Keep qualified access to the historical, non-exported display helpers.
const Extension = AletheiaCore.Extension
const ValuationCallback = AletheiaCore.ValuationCallback
const truthlabel = AletheiaCore.truthlabel
const _chain_flew = AletheiaCore._chain_flew
const _display_truth = AletheiaCore._display_truth
const instances = AletheiaData.instances

end
