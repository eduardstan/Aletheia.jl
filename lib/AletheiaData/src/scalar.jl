# Dependency-free scalar feature preparation and evaluation.
#
# The protocol in this file intentionally does not know about Tables.jl or
# SoleData.  Data packages can implement `feature_value` for their own source;
# `prepare_scalar` then gives the pooled evaluator a stable dense representation.

"""
Protocol marker for data prepared for scalar formula evaluation.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> store isa AbstractScalarDataset
true
```
"""
abstract type AbstractScalarDataset end
"""
Protocol marker for a feature readable at one world.

# Examples
```jldoctest
julia> using AletheiaData

julia> struct MyFeature <: AbstractScalarFeature end

julia> MyFeature() isa AbstractScalarFeature
true
```
"""
abstract type AbstractScalarFeature end
"""
Protocol marker for immutable scalar atom payloads.

# Examples
```jldoctest
julia> using AletheiaData

julia> cond = ThresholdCondition(:f1, >, 0.5);

julia> cond isa AbstractScalarCondition
true
```
"""
abstract type AbstractScalarCondition end
"""
Protocol marker for one-step aggregate memo stores.

# Examples
```jldoctest
julia> using AletheiaData

julia> memo = AggregateMemoStore();

julia> memo isa AbstractAggregateMemo
true
```
"""
abstract type AbstractAggregateMemo end

"""
An immutable feature threshold used as a scalar formula atom payload.

# Examples
```jldoctest
julia> using AletheiaData

julia> cond = ThresholdCondition(:f1, >, 0.5);

julia> cond.threshold
0.5
```
"""
struct ThresholdCondition{F,O,T} <: AbstractScalarCondition
    feature::F
    operator::O
    threshold::T
end

function ThresholdCondition(feature, operator::Function, threshold)
    return ThresholdCondition{typeof(feature),typeof(operator),typeof(threshold)}(
        feature, operator, threshold
    )
end
function ThresholdCondition(; feature, operator, threshold)
    return ThresholdCondition(feature, operator, threshold)
end

"""The feature read by a threshold condition."""
feature(condition::ThresholdCondition) = condition.feature
"""The binary predicate used by a threshold condition."""
test_operator(condition::ThresholdCondition) = condition.operator
"""The right-hand side of a threshold condition."""
threshold(condition::ThresholdCondition) = condition.threshold

# Explicit index maps are kept with the store.  This makes lookup independent
# of the concrete world and feature container, while preserving a documented
# world × instance × feature value layout.
"""
Dense world × instance × feature storage with explicit coordinate maps.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> size(store)
(1, 1, 1)
```
"""
struct DenseFeatureStore{U,W,A,F,I} <: AbstractScalarDataset
    values::A
    worlds::Any
    features::Any
    instances::Any
    world_positions::Any
    feature_positions::Any
    instance_positions::Any
    version::UInt64
end

function DenseFeatureStore(
    values::AbstractArray,
    worlds,
    features;
    instances=Base.OneTo(size(values, ndims(values) == 2 ? 1 : 2)),
    version::Integer=0,
)
    ndims(values) == 3 || throw(
        ArgumentError(
            "dense scalar feature values must have dimensions world × instance × feature",
        ),
    )
    ws, fs, ins = _immutable_copy((collect(worlds), collect(features), collect(instances)))
    values = _immutable_copy(values)
    size(values, 1) == length(ws) ||
        throw(ArgumentError("world index length does not match values"))
    size(values, 2) == length(ins) ||
        throw(ArgumentError("instance index length does not match values"))
    size(values, 3) == length(fs) ||
        throw(ArgumentError("feature index length does not match values"))
    length(unique(ws)) == length(ws) || throw(ArgumentError("worlds must be unique"))
    length(unique(fs)) == length(fs) || throw(ArgumentError("features must be unique"))
    length(unique(ins)) == length(ins) || throw(ArgumentError("instances must be unique"))
    wp = _immutable_copy(Dict{Any,Int}(world => i for (i, world) in enumerate(ws)))
    fp = _immutable_copy(Dict{Any,Int}(f => i for (i, f) in enumerate(fs)))
    ip = _immutable_copy(Dict{Any,Int}(instance => i for (i, instance) in enumerate(ins)))
    return DenseFeatureStore{
        eltype(values),eltype(ws),typeof(values),eltype(fs),eltype(ins)
    }(
        values, ws, fs, ins, wp, fp, ip, UInt64(version)
    )
end

# A positional form mirrors the API sketch and is convenient when a caller
# already has explicit instance labels.
function DenseFeatureStore(values::AbstractArray, worlds, features, version::Integer)
    return DenseFeatureStore(values, worlds, features; version=version)
end
function DenseFeatureStore(
    values::AbstractArray, worlds, instances, features, version::Integer=0
)
    return DenseFeatureStore(values, worlds, features; instances=instances, version=version)
end

Base.size(store::DenseFeatureStore) = size(store.values)
function Base.getindex(store::DenseFeatureStore, instance, world, feature)
    return store.values[
        store.world_positions[world],
        store.instance_positions[instance],
        store.feature_positions[feature],
    ]
end

worlds(store::DenseFeatureStore) = Tuple(store.worlds)
"""
Return the ordered feature labels in a dense store.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> features(store)
(:f1,)
```
"""
features(store::DenseFeatureStore) = Tuple(store.features)
"""
Return the ordered instance labels in a dense store.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> AletheiaData.instances(store)
(1,)
```
"""
instances(store::DenseFeatureStore) = Tuple(store.instances)
"""
Return the one-based world coordinate in a dense store.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> world_index(store, :w1)
1
```
"""
world_index(store::DenseFeatureStore, world) = store.world_positions[world]
"""
Return the one-based feature coordinate in a dense store.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> feature_index(store, :f1)
1
```
"""
feature_index(store::DenseFeatureStore, feature) = store.feature_positions[feature]
"""
Return the one-based instance coordinate in a dense store.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> instance_index(store, 1)
1
```
"""
instance_index(store::DenseFeatureStore, instance) = store.instance_positions[instance]
"""
Return the data version of a dense store.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> data_version(store)
0x0000000000000000
```
"""
data_version(store::DenseFeatureStore) = store.version

"""
Read one prepared feature value without consulting the source data.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> feature_value(store, 1, :w1, :f1)
0.0
```
"""
function feature_value(store::DenseFeatureStore, instance, world, feature)
    return _boundary_copy(store[instance, world, feature])
end

"""
Versioned global and relation-specific aggregate memo tables.

# Examples
```jldoctest
julia> using AletheiaData

julia> memo = AggregateMemoStore();

julia> memo.version
0x0000000000000000
```
"""
mutable struct AggregateMemoStore <: AbstractAggregateMemo
    global_values::Dict{Any,Any}
    relational_values::Dict{Any,Any}
    version::UInt64
    lock::ReentrantLock
end
function AggregateMemoStore(version::Integer=0)
    return AggregateMemoStore(
        Dict{Any,Any}(), Dict{Any,Any}(), UInt64(version), ReentrantLock()
    )
end

"""
Versioned cache for pooled scalar formula results.

# Examples
```jldoctest
julia> using AletheiaData

julia> cache = ScalarEvaluationCache();

julia> cache.version
0x0000000000000000
```
"""
mutable struct ScalarEvaluationCache
    version::UInt64
    values::Dict{Any,Any}
    lock::ReentrantLock
end
function ScalarEvaluationCache(version::Integer=0)
    return ScalarEvaluationCache(UInt64(version), Dict{Any,Any}(), ReentrantLock())
end

"""
Prepared frame list and declared relation vocabulary.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> index = ScalarRelationIndex([Frame([:w1], Dict(); index=true)], (globalrel,));

julia> index.relations
(global,)
```
"""
struct ScalarRelationIndex{F}
    frames::F
    relations::Tuple
    function ScalarRelationIndex(frames, relations)
        owned_frames = _immutable_copy(tuple(frames...))
        owned_relations = _immutable_copy(relations isa Tuple ? relations : tuple(relations...))
        return new{typeof(owned_frames)}(owned_frames, owned_relations)
    end
end

"""
Prepared source, dense feature store, relation index, and aggregate memos.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> prep isa PreparedScalarData
true
```
"""
struct PreparedScalarData{S,R} <: AbstractScalarDataset
    source_key::UInt
    store::S
    relation_index::R
    version::UInt64
end

# Source adapters and aggregate memo tables are evaluator state, not semantic
# payload. Neither registry is reachable through a prepared value's fields.
const _prepared_state_lock = ReentrantLock()
const _prepared_sources = Dict{UInt,Any}()
const _prepared_memos = Dict{UInt,AggregateMemoStore}()
const _next_source_key = Ref{UInt}(0)
function _register_source(source)
    lock(_prepared_state_lock)
    try
        _next_source_key[] += UInt(1)
        key = _next_source_key[]
        _prepared_sources[key] = source
        return key
    finally
        unlock(_prepared_state_lock)
    end
end
function _prepared_source(data::PreparedScalarData)
    lock(_prepared_state_lock)
    try
        return _prepared_sources[data.source_key]
    finally
        unlock(_prepared_state_lock)
    end
end
# Aggregate memo tables are keyed by the hash of the owned prepared record.
function _aggregate_memos(data::PreparedScalarData)
    key = hash(data)
    lock(_prepared_state_lock)
    try
        memo = get!(_prepared_memos, key) do
            AggregateMemoStore(data.version)
        end
        if memo.version != data.version
            memo = (_prepared_memos[key] = AggregateMemoStore(data.version))
        end
        return memo
    finally
        unlock(_prepared_state_lock)
    end
end

ScalarEvaluationCache(data::PreparedScalarData) = ScalarEvaluationCache(data.version)

function feature_value(data::PreparedScalarData, instance, world, feature)
    begin
        _check_scalar_version(data)
        value = feature_value(data.store, instance, world, feature)
        value === missing ? feature_value(_prepared_source(data), instance, world, feature) : value
    end
end

"""
Return the underlying source object of a prepared scalar dataset.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> source(prep) === store
true
```
"""
source(data::PreparedScalarData) = _prepared_source(data)
"""
Return the underlying dense feature store of a prepared scalar dataset.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> AletheiaData.store(prep) isa DenseFeatureStore
true
```
"""
store(data::PreparedScalarData) = data.store
"""
Return the scalar relation index of a prepared scalar dataset.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> relation_index(prep) isa ScalarRelationIndex
true
```
"""
relation_index(data::PreparedScalarData) = data.relation_index
data_version(data::PreparedScalarData) = data.version

# Source-version protocol.  A source can provide `data_version(x)` itself;
# mutable tabular adapters commonly expose a `version` field instead.
"""Return a source version, defaulting to zero for unversioned values."""
function data_version(data)
    begin
        if hasproperty(data, :version) && getproperty(data, :version) isa Integer
            UInt64(getproperty(data, :version))
        else
            UInt64(0)
        end
    end
end

function _check_scalar_version(data::PreparedScalarData)
    current = data_version(_prepared_source(data))
    # A nonzero source version is an opt-in freshness contract.  Explicit
    # preparation versions remain usable for sources that do not expose one.
    (current == 0 && data.version != 0) ||
        current == data.version ||
        throw(
            ArgumentError(
                "prepared scalar data is stale (prepared version $(data.version), source version $current); re-run prepare_scalar",
            ),
        )
    _aggregate_memos(data).version == data.version ||
        throw(ArgumentError("scalar aggregate memos are stale; re-run prepare_scalar"))
    return nothing
end

function clear!(memos::AggregateMemoStore)
    lock(memos.lock)
    try
        empty!(memos.global_values)
        empty!(memos.relational_values)
    finally
        unlock(memos.lock)
    end
    return memos
end
function clear!(cache::ScalarEvaluationCache)
    lock(cache.lock)
    try
        empty!(cache.values)
    finally
        unlock(cache.lock)
    end
    return cache
end
function clear!(data::PreparedScalarData)
    clear!(_aggregate_memos(data))
    return data
end

# Generic raw feature protocol.  User data types should specialize this
# method; the fallback supports callable features, nested dictionaries, and
# dense arrays for small dependency-free datasets.
function _scalar_world_slice(data, instance, world)
    raw = if data isa AbstractVector
        if applicable(getindex, data, instance)
            candidate = data[instance]
            candidate isa AbstractArray ? candidate : (instance == 1 ? data : candidate)
        else
            nothing
        end
    elseif hasproperty(data, :values)
        values = getproperty(data, :values)
        applicable(getindex, values, instance) ? values[instance] : nothing
    elseif data isa AbstractArray && ndims(data) == 2 && instance == 1
        data
    elseif data isa AbstractArray &&
           ndims(data) >= 3 &&
           instance isa Integer &&
           instance <= size(data, 1)
        selectdim(data, 1, instance)
    else
        nothing
    end
    raw isa AbstractArray || return nothing
    if world isa Interval
        return raw[(world.x):(world.y - 1)]
    elseif world isa Rectangle
        return raw[(world.x.x):(world.x.y - 1), (world.y.x):(world.y.y - 1)]
    elseif world isa Point
        return raw[world.coordinates...]
    end
    return nothing
end

function _call_feature(feature, data, instance, world)
    applicable(feature, data, instance, world) && return feature(data, instance, world)
    applicable(feature, instance, world) && return feature(instance, world)
    applicable(feature, data, instance) && return feature(data, instance)
    slice = _scalar_world_slice(data, instance, world)
    slice !== nothing && applicable(feature, slice) && return feature(slice)
    applicable(feature, world) && return feature(world)
    return throw(MethodError(feature, (data, instance, world)))
end

function feature_value(data, instance, world, feature)
    if feature isa Function
        return _call_feature(feature, data, instance, world)
    elseif data isa AbstractDict
        for key in (
            (instance, world, feature),
            (instance, world),
            (world, instance, feature),
            (world, instance),
        )
            if haskey(data, key)
                value = data[key]
                value isa AbstractDict && haskey(value, feature) && return value[feature]
                return value
            end
        end
        haskey(data, instance) || throw(KeyError(instance))
        nested = data[instance]
        if nested isa AbstractDict
            haskey(nested, (world, feature)) && return nested[(world, feature)]
            haskey(nested, world) || throw(KeyError(world))
            worldvalue = nested[world]
            worldvalue isa AbstractDict &&
                haskey(worldvalue, feature) &&
                return worldvalue[feature]
            feature isa Integer &&
                worldvalue isa AbstractArray &&
                return worldvalue[feature]
        elseif nested isa AbstractArray
            return feature isa Integer ? nested[world, feature] : nested[world]
        end
    elseif data isa AbstractArray
        if ndims(data) == 3 &&
           instance isa Integer &&
           world isa Integer &&
           feature isa Integer
            return data[world, instance, feature]
        elseif ndims(data) == 2 && instance isa Integer && world isa Integer
            return feature isa Integer ? data[world, feature] : data[world, instance]
        end
    end
    # Feature objects may provide a callable protocol without subtyping the
    # marker; this final attempt gives a useful method error to the caller.
    return _call_feature(feature, data, instance, world)
end

# A source may expose worlds/instances/frames as properties.  Explicit
# keywords always take precedence.
function _property_or(data, name, default)
    return hasproperty(data, name) ? getproperty(data, name) : default
end

function _normalise_frames(data, frame_spec, instance_labels, world_spec)
    n = length(instance_labels)
    if frame_spec isa Frame
        return [frame_spec for _ in 1:n]
    elseif frame_spec !== nothing
        fs = collect(frame_spec)
        length(fs) == n ||
            throw(ArgumentError("frames must contain one frame per instance"))
        all(frame -> frame isa Frame, fs) ||
            throw(ArgumentError("frames must contain Frame values"))
        return fs
    end
    candidate = _property_or(data, :frames, nothing)
    candidate === nothing && (candidate = _property_or(data, :frame, nothing))
    if candidate isa Frame
        return [candidate for _ in 1:n]
    elseif candidate !== nothing
        fs = collect(candidate)
        length(fs) == n ||
            throw(ArgumentError("data frames must contain one frame per instance"))
        return fs
    end
    ws = world_spec === nothing ? _property_or(data, :worlds, nothing) : world_spec
    ws === nothing && (ws = (AnyWorld(),))
    world_values = ws isa Tuple ? ws : collect(ws)
    default_frame = Frame(world_values, Dict(); index=true)
    return [default_frame for _ in 1:n]
end

function _normalise_instances(data, instance_spec, features, values=nothing)
    instance_spec !== nothing && return collect(instance_spec)
    data isa DenseFeatureStore && return collect(data.instances)
    values !== nothing && return collect(Base.OneTo(size(values, 2)))
    candidate = _property_or(data, :instances, nothing)
    candidate !== nothing && return collect(candidate)
    n = _property_or(data, :ninstances, 1)
    n isa Integer ||
        throw(ArgumentError("instances must be indexable or have an integer count"))
    return collect(Base.OneTo(n))
end

function _normalise_worlds(frames, world_spec)
    if world_spec !== nothing
        requested = collect(world_spec)
        domains = [collect(worlds(frame)) for frame in frames]
        all(domain == requested for domain in domains) ||
            throw(ScalarWorldDomainError(requested, domains))
        return requested
    end
    isempty(frames) && return AnyWorld[]
    first_worlds = collect(worlds(first(frames)))
    all(frame -> collect(worlds(frame)) == first_worlds, frames) || throw(
        ArgumentError(
            "dense scalar preparation requires one shared world index; use separate preparations for non-uniform world domains",
        ),
    )
    return first_worlds
end

function _aggregate_specs(spec, features)
    spec === nothing && return Tuple{Any,Any}[]
    spec === true && return [(f, maximum) for f in features] # useful compact spelling
    spec === :all &&
        return vcat([(f, minimum) for f in features], [(f, maximum) for f in features])
    candidates =
        spec isa Tuple && length(spec) == 2 && spec[2] isa Function ? [spec] : collect(spec)
    result = Tuple{Any,Any}[]
    for item in candidates
        if item isa ThresholdCondition
            aggregate = _aggregate_for_threshold(test_operator(item), :diamond)
            aggregate === nothing || push!(result, (feature(item), aggregate))
        elseif item isa Pair
            push!(result, (item.first, item.second))
        elseif item isa Tuple && length(item) == 2
            push!(result, (item[1], item[2]))
        else
            throw(
                ArgumentError(
                    "aggregate precompute entries must be conditions or (feature, aggregate) pairs",
                ),
            )
        end
    end
    return unique(result)
end

"""
Prepare selected scalar features into a world × instance × feature store.

`features` are evaluated once per instance/world. `frames` may be one Frame or
one frame per instance. Global `minimum`/`maximum` values may be eagerly
prepared with `precompute_aggregates`; relation-specific values are filled on
first use. The source can expose an integer `version` (or specialize
`data_version`) to make stale prepared data fail closed.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> prep isa PreparedScalarData
true
```
"""
function prepare_scalar(
    data;
    features=(),
    frames=nothing,
    relations=(),
    precompute_features=true,
    precompute_aggregates=(),
    instances=nothing,
    worlds=nothing,
    version=nothing,
)
    if data isa PreparedScalarData
        isempty(features) && (features = data.store.features)
        isempty(relations) && (relations = data.relation_index.relations)
        frames === nothing && (frames = data.relation_index.frames)
        return prepare_scalar(
            _prepared_source(data);
            features=features,
            frames=frames,
            relations=relations,
            precompute_features=precompute_features,
            precompute_aggregates=precompute_aggregates,
            instances=instances,
            worlds=worlds,
            version=version,
        )
    end
    feature_list = collect(features)
    if data isa DenseFeatureStore
        isempty(feature_list) && (feature_list = data.features)
        instance_labels = _normalise_instances(data, instances, feature_list, data.values)
        world_list = worlds === nothing ? collect(data.worlds) : collect(worlds)
        all(world -> haskey(data.world_positions, world), world_list) ||
            throw(KeyError("world"))
        frames_list = _share_frames(
            _normalise_frames(data, frames, instance_labels, world_list)
        )
        _normalise_worlds(frames_list, world_list)
        # A store can be prepared with a subset of its dimensions, but values
        # remain source-authoritative and are copied into the requested order.
        dense_values = Array{eltype(data.values)}(
            undef, length(world_list), length(instance_labels), length(feature_list)
        )
        for (iw, world) in enumerate(world_list),
            (ii, instance) in enumerate(instance_labels),
            (iff, f) in enumerate(feature_list)

            dense_values[iw, ii, iff] = feature_value(data, instance, world, f)
        end
        source = data
    else
        instance_labels = _normalise_instances(data, instances, feature_list)
        frames_list = _share_frames(
            _normalise_frames(data, frames, instance_labels, worlds)
        )
        world_list = _normalise_worlds(frames_list, worlds)
        # Feature families may legitimately mix numeric and categorical
        # payloads.  `Any` keeps the generic store faithful and avoids a
        # speculative source read before the eager pass.
        dense_values = if precompute_features
            Array{Any}(undef, length(world_list), length(instance_labels), length(feature_list))
        else
            fill!(
                Array{Any}(
                    undef,
                    length(world_list),
                    length(instance_labels),
                    length(feature_list),
                ),
                missing,
            )
        end
        if precompute_features
            for (iw, world) in enumerate(world_list),
                (ii, instance) in enumerate(instance_labels),
                (iff, f) in enumerate(feature_list)

                dense_values[iw, ii, iff] = feature_value(data, instance, world, f)
            end
        end
        source = data
    end
    prepared_version = version === nothing ? data_version(source) : UInt64(version)
    dense = DenseFeatureStore(
        dense_values,
        world_list,
        feature_list;
        instances=instance_labels,
        version=prepared_version,
    )
    relation_tuple = relations isa Tuple ? relations : Tuple(collect(relations))
    index = ScalarRelationIndex(tuple(frames_list...), relation_tuple)
    prepared = PreparedScalarData(
        _register_source(source), dense, index, prepared_version
    )
    for (f, aggregator) in _aggregate_specs(precompute_aggregates, feature_list)
        for instance in instance_labels
            aggregate_value(prepared, instance, globalrel, globalrel, f, aggregator)
        end
    end
    return prepared
end

function _frame(data::PreparedScalarData, instance)
    positions = findfirst(x -> isequal(x, instance), data.store.instances)
    positions === nothing && throw(KeyError(instance))
    return data.relation_index.frames[positions]
end

function _feature_values(data::PreparedScalarData, instance, world_values, f)
    return [feature_value(data, instance, world, f) for world in world_values]
end

# Aggregate identity is deliberately restricted to the well-defined generic
# folds.  Other callables remain supported and get `nothing` on empty input.
_aggregate_name(::typeof(maximum)) = :maximum
_aggregate_name(::typeof(max)) = :maximum
_aggregate_name(::typeof(minimum)) = :minimum
_aggregate_name(::typeof(min)) = :minimum
_aggregate_name(::typeof(sum)) = :sum
_aggregate_name(::typeof(prod)) = :prod
_aggregate_name(::typeof(any)) = :any
_aggregate_name(::typeof(all)) = :all
_aggregate_name(aggregate) = aggregate

function _aggregate_values(values, aggregate)
    isempty(values) && return nothing
    aggregate === maximum && return maximum(values)
    aggregate === max && return maximum(values)
    aggregate === minimum && return minimum(values)
    aggregate === min && return minimum(values)
    aggregate === sum && return sum(values)
    aggregate === prod && return prod(values)
    aggregate === any && return any(values)
    aggregate === all && return all(values)
    return aggregate(values)
end

function _successors(data::PreparedScalarData, instance, world, relation)
    frame = _frame(data, instance)
    relation isa GlobalRelation && return collect(worlds(frame))
    return collect(accessible(frame, world, relation))
end

"""
Return exact representative worlds for a scalar aggregate.

The generic implementation uses every accessible world. A feature/data
adapter may specialize this method to return a smaller set only when its
representative proof is exact; no approximation is performed here.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> representative_worlds(prep, 1, :w1, globalrel, :f1, maximum)
1-element Vector{Symbol}:
 :w1
```
"""
function representative_worlds(
    data::PreparedScalarData, instance, world, relation, feature, aggregate
)
    _check_scalar_version(data)
    return if relation isa GlobalRelation
        collect(worlds(_frame(data, instance)))
    else
        _successors(data, instance, world, relation)
    end
end
function representative_worlds(
    data::DenseFeatureStore, instance, world, relation, feature, aggregate
)
    return if relation isa GlobalRelation
        collect(data.worlds)
    else
        (world isa AbstractVector || world isa Tuple ? collect(world) : Any[])
    end
end
function representative_worlds(
    data::AbstractScalarDataset, instance, world, relation, feature, aggregate
)
    return if world isa AbstractVector || world isa Tuple || world isa AbstractSet
        collect(world)
    else
        (
            if relation isa GlobalRelation && hasproperty(data, :worlds)
                collect(getproperty(data, :worlds))
            else
                Any[]
            end
        )
    end
end

function _metacondition_key(feature, aggregate)
    return (feature, _aggregate_name(aggregate))
end
function _global_memo_key(instance, feature, aggregate)
    return (instance, _metacondition_key(feature, aggregate), globalrel)
end
function _memo_key(instance, world, relation, feature, aggregate)
    return (instance, _metacondition_key(feature, aggregate), relation, world)
end

"""
Aggregate a prepared feature over a world or relation's successors.

A global relation is memoized without a world. Relational values are memoized
by `(instance, world, relation, feature, aggregate)`. Empty successor sets
return `nothing`, so callers can apply the appropriate existential or
universal identity without inventing a numeric sentinel.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> aggregate_value(prep, 1, :w1, globalrel, :f1, maximum)
0.0
```
"""
function aggregate_value(
    data::PreparedScalarData, instance, world_or_worlds, relation, feature, aggregate
)
    _check_scalar_version(data)
    is_worlds =
        world_or_worlds isa AbstractVector ||
        world_or_worlds isa Tuple ||
        world_or_worlds isa AbstractSet
    if relation isa GlobalRelation
        key = _global_memo_key(instance, feature, aggregate)
        lock(_aggregate_memos(data).lock)
        try
            haskey(_aggregate_memos(data).global_values, key) &&
                return _aggregate_memos(data).global_values[key]
        finally
            unlock(_aggregate_memos(data).lock)
        end
        ws = collect(worlds(_frame(data, instance)))
        reps = representative_worlds(
            data, instance, globalrel, globalrel, feature, aggregate
        )
        result = _aggregate_values(
            _feature_values(data, instance, reps, feature), aggregate
        )
        lock(_aggregate_memos(data).lock)
        try
            _aggregate_memos(data).global_values[key] = result
        finally
            unlock(_aggregate_memos(data).lock)
        end
        return result
    elseif is_worlds
        ws = collect(world_or_worlds)
        reps = ws
        return _aggregate_values(_feature_values(data, instance, reps, feature), aggregate)
    end
    key = _memo_key(instance, world_or_worlds, relation, feature, aggregate)
    lock(_aggregate_memos(data).lock)
    try
        haskey(_aggregate_memos(data).relational_values, key) &&
            return _aggregate_memos(data).relational_values[key]
    finally
        unlock(_aggregate_memos(data).lock)
    end
    reps = representative_worlds(
        data, instance, world_or_worlds, relation, feature, aggregate
    )
    result = _aggregate_values(_feature_values(data, instance, reps, feature), aggregate)
    lock(_aggregate_memos(data).lock)
    try
        _aggregate_memos(data).relational_values[key] = result
    finally
        unlock(_aggregate_memos(data).lock)
    end
    return result
end

function aggregate_value(
    data::DenseFeatureStore, instance, world_or_worlds, relation, feature, aggregate
)
    begin
        ws = if relation isa GlobalRelation
            collect(data.worlds)
        else
            (
                if world_or_worlds isa AbstractVector || world_or_worlds isa Tuple
                    collect(world_or_worlds)
                else
                    collect(world_or_worlds)
                end
            )
        end
        _aggregate_values(
            [feature_value(data, instance, world, feature) for world in ws], aggregate
        )
    end
end
function aggregate_value(
    data::AbstractScalarDataset, instance, world_or_worlds, relation, feature, aggregate
)
    worlds_value =
        if world_or_worlds isa AbstractVector ||
           world_or_worlds isa Tuple ||
           world_or_worlds isa AbstractSet
            collect(world_or_worlds)
        else
            (
                if relation isa GlobalRelation && hasproperty(data, :worlds)
                    collect(getproperty(data, :worlds))
                else
                    throw(
                        ArgumentError(
                            "an unprepared scalar dataset needs an explicit world collection",
                        ),
                    )
                end
            )
        end
    return _aggregate_values(
        [feature_value(data, instance, world, feature) for world in worlds_value], aggregate
    )
end

# Threshold dispatch for modal folds.  Equality and arbitrary operators need
# the child predicate itself, so they intentionally use the fallback iterator.
function _aggregate_for_threshold(operator, modal)
    if modal === :diamond
        if operator === (>) || operator === (>=)
            maximum
        elseif operator === (<) || operator === (<=)
            minimum
        else
            nothing
        end
    else
        if operator === (>) || operator === (>=)
            minimum
        elseif operator === (<) || operator === (<=)
            maximum
        else
            nothing
        end
    end
end

"""
Evaluate one threshold condition using prepared or source feature lookup.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> cond = ThresholdCondition(:f1, ==, 0.0);

julia> scalar_check(cond, store, 1, :w1)
true
```
"""
function scalar_check(condition::ThresholdCondition, data, instance, world)
    return test_operator(condition)(
        feature_value(data, instance, world, feature(condition)), threshold(condition)
    )
end
function scalar_check(condition::AbstractScalarCondition, data, instance, world)
    return throw(MethodError(scalar_check, (condition, data, instance, world)))
end

"""
Evaluate one condition over an explicit world order.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> cond = ThresholdCondition(:f1, ==, 0.0);

julia> scalar_atom_values(cond, store, 1, [:w1])
1-element BitVector:
 1
```
"""
function scalar_atom_values(condition, data, instance, worlds)
    return BitVector(scalar_check(condition, data, instance, world) for world in worlds)
end

"""
Build a scalar `ValuationCallback` for one prepared instance.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> scalar_valuation(prep, 1) isa AletheiaCore.ValuationCallback
true
```
"""
function scalar_valuation(data::PreparedScalarData, instance; vectorized::Bool=true)
    _check_scalar_version(data)
    scalar = (condition, world) -> begin
        scalar_check(condition, data, instance, world)
    end
    batch = if vectorized
        (
            (condition, world_values) ->
                scalar_atom_values(condition, data, instance, world_values)
        )
    else
        nothing
    end
    return ValuationCallback(scalar; vectorized=batch)
end

"""
Build a `ModelFamily` whose models read prepared scalar conditions.

# Examples
```jldoctest
julia> using AletheiaData

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> scalar_family(prep) isa ModelFamily
true
```
"""
function scalar_family(
    data::PreparedScalarData; algebra::TruthAlgebra=BOOLEAN, vectorized::Bool=true
)
    _check_scalar_version(data)
    models = [
        Model(
            _frame(data, instance),
            algebra,
            scalar_valuation(data, instance; vectorized=vectorized),
        ) for instance in data.store.instances
    ]
    return ModelFamily(models)
end

# Data-backed methods retain the ordinary evaluator as the callback reference.
# Fused scalar traversal.  This uses the union DAG and applies a threshold
# modal leaf through aggregate memos rather than scanning source slices.
function _scalar_modal_leaf(
    condition::AbstractScalarCondition, data, instance, relation, worlds, modal
)
    condition isa ThresholdCondition || return nothing
    aggregate = _aggregate_for_threshold(test_operator(condition), modal)
    aggregate === nothing && return nothing
    result = falses(length(worlds))
    for (slot, world) in enumerate(worlds)
        value = aggregate_value(
            data, instance, world, relation, feature(condition), aggregate
        )
        result[slot] = if value === nothing
            modal === :box
        else
            test_operator(condition)(value, threshold(condition))
        end
    end
    return result
end

function _scalar_evaluate(
    formulas::AbstractVector{<:Formula},
    data::PreparedScalarData,
    instance;
    trace::Bool=false,
)
    isempty(formulas) && return BitVector[]
    _check_scalar_version(data)
    nodes, positions = _batch_evaluation_nodes(formulas)
    worlds_tuple = worlds(_frame(data, instance))
    worlds_vector = collect(worlds_tuple)
    values = Vector{BitVector}(undef, length(nodes))
    entries = NamedTuple[]
    for (slot, node) in enumerate(nodes)
        if node.kind === :atom
            condition = node.payload
            world_probe = isempty(worlds_vector) ? nothing : first(worlds_vector)
            applicable(scalar_check, condition, data, instance, world_probe) || throw(
                ArgumentError(
                    "scalar formula atom payload does not implement scalar_check"
                ),
            )
            values[slot] = scalar_atom_values(condition, data, instance, worlds_vector)
            if trace
                condition_feature =
                    condition isa ThresholdCondition ? feature(condition) : nothing
                for world in worlds_vector
                    if condition_feature === nothing
                        push!(
                            entries,
                            (
                                kind=:scalar_callback,
                                instance=instance,
                                world=world,
                                condition=condition,
                                source=:callback,
                            ),
                        )
                    else
                        source_kind =
                            if feature_value(
                                data.store, instance, world, condition_feature
                            ) === missing
                                :fallback
                            else
                                :dense_store
                            end
                        push!(
                            entries,
                            (
                                kind=if source_kind === :fallback
                                    :fallback
                                else
                                    :dense_feature_lookup
                                end,
                                instance=instance,
                                world=world,
                                feature=condition_feature,
                                source=source_kind,
                            ),
                        )
                    end
                end
            end
        else
            connective = node.payload
            if connective isa Diamond || connective isa Box
                childslot = node.children[1]
                childnode = nodes[childslot]
                leaf = childnode.kind === :atom ? childnode.payload : nothing
                aggregate = if leaf isa ThresholdCondition
                    _aggregate_for_threshold(
                        test_operator(leaf), connective isa Diamond ? :diamond : :box
                    )
                else
                    nothing
                end
                prior_hits = if trace && aggregate !== nothing
                    [
                        if relation(connective) isa GlobalRelation
                            haskey(
                                _aggregate_memos(data).global_values,
                                _global_memo_key(instance, feature(leaf), aggregate),
                            )
                        else
                            haskey(
                                _aggregate_memos(data).relational_values,
                                _memo_key(
                                    instance,
                                    world,
                                    relation(connective),
                                    feature(leaf),
                                    aggregate,
                                ),
                            )
                        end for world in worlds_vector
                    ]
                else
                    Bool[]
                end
                reduced = if leaf isa AbstractScalarCondition
                    _scalar_modal_leaf(
                        leaf,
                        data,
                        instance,
                        relation(connective),
                        worlds_vector,
                        connective isa Diamond ? :diamond : :box,
                    )
                else
                    nothing
                end
                if reduced !== nothing
                    values[slot] = reduced
                    if trace
                        for (world, hit) in zip(worlds_vector, prior_hits)
                            push!(
                                entries,
                                (
                                    kind=if hit
                                        :aggregate_memo_hit
                                    else
                                        :representative_aggregation
                                    end,
                                    instance=instance,
                                    world=world,
                                    relation=relation(connective),
                                    feature=feature(leaf),
                                ),
                            )
                        end
                    end
                else
                    child = values[childslot]
                    adjacency = [
                        if relation(connective) isa GlobalRelation
                            worlds_vector
                        else
                            collect(
                                accessible(
                                    _frame(data, instance), world, relation(connective)
                                ),
                            )
                        end for world in worlds_vector
                    ]
                    values[slot] = BitVector(
                        if connective isa Diamond
                            any(
                                target -> child[findfirst(
                                    x -> isequal(x, target), worlds_vector
                                )],
                                targets,
                            )
                        else
                            all(
                                target -> child[findfirst(
                                    x -> isequal(x, target), worlds_vector
                                )],
                                targets,
                            )
                        end for targets in adjacency
                    )
                    trace && push!(
                        entries,
                        (
                            kind=:fallback,
                            operation=:modal_iterator,
                            relation=relation(connective),
                        ),
                    )
                end
            elseif connective isa Negation
                values[slot] = .~values[node.children[1]]
            elseif connective isa Conjunction || connective isa Fusion
                values[slot] = values[node.children[1]] .& values[node.children[2]]
            elseif connective isa Disjunction
                values[slot] = values[node.children[1]] .| values[node.children[2]]
            elseif connective isa Implication
                values[slot] = (.~values[node.children[1]]) .| values[node.children[2]]
            else
                throw(
                    ArgumentError("no scalar evaluator for connective $(repr(connective))")
                )
            end
        end
    end
    roots = [positions[id(formula)] for formula in formulas]
    result = [copy(values[root]) for root in roots]
    return result, entries
end

function _selected_instances(data::PreparedScalarData, requested)
    requested === nothing && return collect(data.store.instances)
    return collect(requested)
end

function _cached_scalar_apply(formulas, data, instance, cache::ScalarEvaluationCache, trace)
    cache.version == data.version ||
        throw(ArgumentError("scalar formula cache has stale data version"))
    key = (instance, Tuple(id.(formulas)), pool(first(formulas)))
    lock(cache.lock)
    try
        if haskey(cache.values, key)
            result = cache.values[key]
            return [copy(value) for value in result],
            NamedTuple[(kind=:formula_cache_hit, instance=instance)]
        end
    finally
        unlock(cache.lock)
    end
    result, entries = _scalar_evaluate(formulas, data, instance; trace=trace)
    lock(cache.lock)
    try
        cache.values[key] = [copy(value) for value in result]
    finally
        unlock(cache.lock)
    end
    return result, entries
end

"""
Evaluate pooled scalar formulas for selected instances in one union-DAG pass.

The default result is one vector per formula, each vector containing one
extension per selected instance. With `trace=true`, a named tuple additionally
reports lookup/aggregation provenance and cache state. `ScalarEvaluationCache`
is a formula cache and is independent from feature storage and aggregate memos.

# Examples
```jldoctest
julia> using AletheiaData, AletheiaCore

julia> store = DenseFeatureStore(zeros(1, 1, 1), [:w1], [:f1]);

julia> prep = prepare_scalar(store);

julia> cond = ThresholdCondition(:f1, ==, 0.0);

julia> f = atom(cond);

julia> res = batch_apply([f], prep);

julia> length(res)
1
```
"""
function batch_apply(
    formulas::AbstractVector{<:Formula},
    data::PreparedScalarData;
    instances=nothing,
    cache=nothing,
    trace::Bool=false,
)
    normalized = collect(formulas)
    isempty(normalized) && return if trace
        (
            values=Vector{Any}[],
            traces=NamedTuple[],
            cache_state=(formula=:empty, features=:empty, aggregates=:empty),
        )
    else
        Vector{Any}[]
    end
    formula_pool = pool(first(normalized))
    all(pool(formula) === formula_pool for formula in normalized) ||
        throw(ArgumentError("batch_apply requires formulas from one FormulaPool"))
    selected = _selected_instances(data, instances)
    per_instance = Vector{Vector{BitVector}}()
    traces = NamedTuple[]
    for instance in selected
        if cache === nothing
            result, entries = _scalar_evaluate(normalized, data, instance; trace=trace)
        elseif cache isa ScalarEvaluationCache
            result, entries = _cached_scalar_apply(normalized, data, instance, cache, trace)
        else
            throw(ArgumentError("cache must be nothing or a ScalarEvaluationCache"))
        end
        push!(per_instance, result)
        trace && append!(traces, entries)
    end
    values = [
        BitVector[per_instance[i][j] for i in eachindex(per_instance)] for
        j in eachindex(normalized)
    ]
    if !trace
        return values
    end
    cache_state = (
        formula=cache === nothing ? :cold : :available,
        features=:dense,
        aggregates=(
            if isempty(_aggregate_memos(data).global_values) &&
               isempty(_aggregate_memos(data).relational_values)
                :cold
            else
                :warm
            end
        ),
    )
    return (values=values, traces=traces, cache_state=cache_state)
end

"""Evaluate one scalar formula using the prepared scalar callback family."""
function check(formula::Formula, data::PreparedScalarData, instance, world; kwargs...)
    result = batch_apply([formula], data; instances=[instance], kwargs...)
    # Preserve the ordinary check scalar result, rather than an extension.
    values = result isa NamedTuple ? result.values : result
    position = world_position(_frame(data, instance), world)
    return values[1][1][position]
end

"""Evaluate a prepared scalar formula and return its world extension."""
function extension(formula::Formula, data::PreparedScalarData, instance)
    begin
        values = batch_apply([formula], data; instances=[instance])
        values[1][1]
    end
end
function extension(formulas::AbstractVector, data::PreparedScalarData, instance)
    return [result[1] for result in batch_apply(formulas, data; instances=[instance])]
end
extension(formulas::AbstractVector, data::PreparedScalarData) = batch_apply(formulas, data)
