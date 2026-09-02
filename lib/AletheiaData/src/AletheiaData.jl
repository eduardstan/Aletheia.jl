"""Scalar data preparation and model-family protocols for Aletheia."""
module AletheiaData

using AletheiaCore
import AletheiaCore:
    extension,
    check,
    clear!,
    worlds,
    world_index,
    _batch_evaluation_nodes,
    _batch_formulas,
    ValuationCallback
include("dataset.jl")
include("scalar.jl")

export AbstractModelFamily,
    ModelFamily,
    instance_count,
    eachinstance,
    instance_model,
    AbstractScalarDataset,
    AbstractScalarFeature,
    AbstractScalarCondition,
    AbstractAggregateMemo,
    ThresholdCondition,
    DenseFeatureStore,
    PreparedScalarData
export AggregateMemoStore,
    ScalarEvaluationCache,
    ScalarRelationIndex,
    prepare_scalar,
    feature_value,
    scalar_check,
    scalar_atom_values,
    scalar_valuation,
    scalar_family,
    aggregate_value,
    representative_worlds,
    data_version
export batch_apply,
    source,
    store,
    one_step_memos,
    relation_index,
    feature_index,
    instance_index,
    features,
    instances,
    world_index,
    instance_frame,
    uniform_frame
export isuniform

end
