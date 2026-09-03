"""Scalar data preparation and model-family protocols for Aletheia."""
module AletheiaData

using AletheiaCore
import AletheiaCore: extension, check, clear!, worlds, world_index,
    _batch_evaluation_nodes, _batch_formulas, _batch_evaluate, _evaluation_plan,
    ValuationCallback

"""Raised when requested scalar worlds do not match frame domains."""
struct ScalarWorldDomainError <: Exception
    requested::Vector{Any}
    frame_domains::Vector{Vector{Any}}
end

"""Raised when a concrete model family mixes truth algebras."""
struct MixedAlgebraError <: Exception
    expected::Any
    actual::Any
    instance::Int
end
function Base.showerror(io::IO, error::MixedAlgebraError)
    print(io, "model family requires one truth algebra; instance ", error.instance,
        " has ", repr(error.actual), " instead of ", repr(error.expected))
end
function Base.showerror(io::IO, error::ScalarWorldDomainError)
    print(io, "scalar worlds do not match frame domains: requested ", repr(error.requested),
        ", frames ", repr(error.frame_domains))
end

include("dataset.jl")
include("scalar.jl")

export AbstractModelFamily, ModelFamily, instance_count, eachinstance, instance_model, AbstractScalarDataset, AbstractScalarFeature, AbstractScalarCondition, AbstractAggregateMemo, ThresholdCondition, DenseFeatureStore, PreparedScalarData
export AggregateMemoStore, ScalarEvaluationCache, ScalarRelationIndex, prepare_scalar, feature_value, scalar_check, scalar_atom_values, scalar_valuation, scalar_family, aggregate_value, representative_worlds, data_version
export batch_apply, source, store, one_step_memos, relation_index, feature_index, instance_index, features, instances, world_index, instance_frame, uniform_frame
export isuniform, ScalarWorldDomainError, MixedAlgebraError

end
