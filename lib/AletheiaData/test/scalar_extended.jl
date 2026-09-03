@testset "scalar data preparation and evaluation" begin
    mutable struct VersionedScalarSource
        values::Dict{Tuple{Int,Int},Float64}
        version::UInt64
    end
    source = VersionedScalarSource(Dict((1, 1) => 0.2, (1, 2) => 0.8,
        (1, 3) => 0.4, (2, 1) => 0.9, (2, 2) => 0.1, (2, 3) => 0.6), 1)
    AletheiaData.feature_value(x::VersionedScalarSource, i, w, ::Val{:x}) = x.values[(i, w)]
    AletheiaData.feature_value(x::VersionedScalarSource, i, w, ::Val{:twice}) = 2x.values[(i, w)]
    fr1 = Frame((1, 2, 3), Dict(:R => Dict(1 => [2, 2], 2 => [3], 3 => Int[])); index=true)
    fr2 = Frame((1, 2, 3), Dict(:R => Dict(1 => [1], 2 => [1, 3], 3 => [2])); index=true)
    prepared = prepare_scalar(source; features=[Val(:x), Val(:twice)],
        frames=[fr1, fr2], instances=[1, 2], relations=(:R,),
        precompute_aggregates=[(Val(:x), maximum)])
    @test prepared isa PreparedScalarData
    @test size(prepared.store.values) == (3, 2, 2)
    @test feature_index(prepared.store, Val(:twice)) == 2
    @test instance_index(prepared.store, 2) == 2
    @test Aletheia.world_index(prepared.store, 3) == 3
    @test feature_value(prepared, 2, 3, Val(:x)) == 0.6
    c = ThresholdCondition(Val(:x), >=, 0.5)
    @test scalar_check(c, prepared, 1, 2)
    @test scalar_atom_values(c, prepared, 1, (1, 2, 3)) == BitVector([0, 1, 0])
    @test aggregate_value(prepared, 1, 1, :R, Val(:x), maximum) == 0.8
    @test aggregate_value(prepared, 1, 2, :R, Val(:x), minimum) == 0.4
    @test aggregate_value(prepared, 1, 3, :R, Val(:x), maximum) === nothing
    @test aggregate_value(prepared, 1, (1, 2), :R, Val(:x), sum) == 1.0
    @test representative_worlds(prepared, 1, 1, :R, Val(:x), maximum) == [2, 2]
    @test aggregate_value(prepared, 1, globalrel, globalrel, Val(:x), maximum) == 0.8

    sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    atom_c = atom(pool, c)
    modal = branch(pool, Diamond(:R), atom_c)
    universal = branch(pool, Box(:R), atom_c)
    repeated = branch(pool, ∧, atom_c, atom_c)
    results = batch_apply([atom_c, modal, universal, repeated], prepared)
    @test results[1] == [BitVector([0, 1, 0]), BitVector([1, 0, 1])]
    @test results[2] == [BitVector([1, 0, 0]), BitVector([1, 1, 0])]
    @test results[3] == [BitVector([1, 0, 1]), BitVector([1, 1, 0])]
    @test results[4] == results[1]
    @test check(modal, prepared, 1, 1) == true
    @test extension(modal, prepared, 2) == BitVector([1, 1, 0])
    family = scalar_family(prepared; vectorized=false)
    @test extension(modal, family, 1) == results[2][1]
    @test check(modal, family, 2, 2) == true

    cache = ScalarEvaluationCache(prepared)
    @test batch_apply([modal], prepared; cache=cache) == [ [BitVector([1, 0, 0]), BitVector([1, 1, 0])] ]
    @test clear!(cache) === cache
    traced = batch_apply([modal], prepared; trace=true)
    @test any(entry -> entry.kind == :aggregate_memo_hit, traced.traces)
    clear!(prepared)
    traced_cold = batch_apply([modal], prepared; trace=true)
    @test any(entry -> entry.kind == :representative_aggregation, traced_cold.traces)
    source.version = 2
    @test_throws ArgumentError feature_value(prepared, 1, 1, Val(:x))

    lazy = prepare_scalar(source; features=[Val(:x)], frames=[fr1, fr2],
        instances=[1, 2], precompute_features=false)
    @test scalar_check(ThresholdCondition(Val(:x), >, 0.5), lazy, 1, 2)
    @test batch_apply([atom(FormulaPool(Signature((¬,))), ThresholdCondition(Val(:x), >, 0.5))], lazy)[1][1] == BitVector([0, 1, 0])
    @test_throws ArgumentError batch_apply([modal], prepared; cache=EvaluationCache(instance_model(family, 1)))
end


struct ScalarPropertySource
    values::Dict{Tuple{Int,Symbol},Float64}
    frames::Vector{Frame}
    instances::Vector{Int}
end
AletheiaData.feature_value(s::ScalarPropertySource, i, w, ::Val{:x}) = s.values[(i, w)]

@testset "scalar protocol edge cases" begin
    fr = Frame((:a, :b), Dict(:R => Dict(:a => [:b], :b => [])); index=true)
    props = ScalarPropertySource(Dict((1, :a) => 1.0, (1, :b) => 2.0), [fr], [1])
    prep = prepare_scalar(props; features=[Val(:x)])
    @test prep.store.worlds == [:a, :b]
    @test AletheiaData.instances(prep.store) == (1,)
    @test worlds(prep.store) == (:a, :b)
    @test AletheiaData.features(prep.store) == (Val(:x),)
    @test source(prep) === props
    @test store(prep) === prep.store
    @test one_step_memos(prep) === prep.one_step_memos
    @test relation_index(prep) === prep.relation_index
    @test data_version(prep) == 0
    @test size(prep.store) == (2, 1, 1)
    @test prep.store[1, :a, Val(:x)] == 1.0
    @test DenseFeatureStore(reshape([1, 2], 2, 1, 1), [:a, :b], [Val(:x)], 4).version == 4
    @test DenseFeatureStore(reshape([1, 2], 2, 1, 1), [:a, :b], [1], [Val(:x)], 5).version == 5
    @test ThresholdCondition(feature=Val(:x), operator=(>=), threshold=1).threshold == 1

    dict_data = Dict((1, :a, :f) => 3, (1, :b) => Dict(:f => 4))
    @test feature_value(dict_data, 1, :a, :f) == 3
    @test feature_value(dict_data, 1, :b, :f) == 4
    @test feature_value(Dict(1 => Dict(:a => Dict(:f => 5))), 1, :a, :f) == 5
    @test feature_value(Dict(1 => Dict(1 => [6])), 1, 1, 1) == 6
    @test feature_value(Dict(1 => [[6]]), 1, 1, 1) == [6]
    @test feature_value(reshape([7], 1, 1, 1), 1, 1, 1) == 7
    @test feature_value(reshape([8], 1, 1), 1, 1, 1) == 8
    @test feature_value((1, 2), 1, :a, (d, i, w) -> 9) == 9
    @test feature_value(nothing, 1, :a, (i, w) -> 10) == 10
    @test feature_value(nothing, 1, :a, (d, i) -> 11) == 11
    @test feature_value(nothing, 1, :a, w -> 12) == 12
    @test_throws MethodError feature_value(nothing, 1, :a, :bad)

    @test aggregate_value(prep, 1, (:a, :b), :R, Val(:x), prod) == 2.0
    @test aggregate_value(prep, 1, (:a, :b), :R, Val(:x), max) == 2.0
    @test aggregate_value(prep, 1, (:a, :b), :R, Val(:x), min) == 1.0
    @test aggregate_value(prep, 1, (:a, :b), :R, Val(:x), sum) == 3.0
    @test aggregate_value(prep, 1, (:a, :b), :R, Val(:x), x -> maximum(x) + 1) == 3.0
    @test aggregate_value(prep.store, 1, (:a, :b), :R, Val(:x), maximum) == 2.0
    @test aggregate_value(prep.store, 1, globalrel, globalrel, Val(:x), minimum) == 1.0
    @test aggregate_value(prep, 1, (:a, :b), :R, Val(:x), maximum) == 2.0
    @test clear!(prep) === prep
    @test clear!(AggregateMemoStore()) isa AggregateMemoStore

    sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    p = FormulaPool(sig)
    cgt = atom(p, ThresholdCondition(Val(:x), >, 1.5))
    ceq = atom(p, ThresholdCondition(Val(:x), ==, 1.0))
    fallback = branch(p, Diamond(:R), ceq)
    connective = branch(p, →, branch(p, ∧, cgt, ceq), branch(p, ∨, cgt, ceq))
    @test batch_apply(Formula[], prep) == Vector{Any}[]
    @test batch_apply([fallback, connective], prep)[1][1] == BitVector([0, 0])
    @test scalar_valuation(prep, 1; vectorized=false)(ThresholdCondition(Val(:x), >, 0), :a)
    @test_throws MethodError scalar_valuation(prep, 1)(:not_condition, :a)
    @test extension([cgt, ceq], prep, 1) == [BitVector([0, 1]), BitVector([1, 0])]
    @test batch_apply([cgt], prep; instances=[1], trace=true).cache_state.features == :dense
    @test_throws ArgumentError batch_apply([cgt], prep; cache=ScalarEvaluationCache(1))

    empty_frame = Frame((:a, :b), Dict(:R => Dict(:a => [], :b => [])); index=true)
    empty_prep = prepare_scalar(props; features=[Val(:x)], frames=[empty_frame])
    empty_diamond = branch(p, Diamond(:R), atom(p, ThresholdCondition(Val(:x), >=, 1.0)))
    empty_box = branch(p, Box(:R), atom(p, ThresholdCondition(Val(:x), >=, 1.0)))
    @test batch_apply([empty_diamond, empty_box], empty_prep) ==
        [[BitVector([0, 0])], [BitVector([1, 1])]]
end


struct CountScalarSource
    ninstances::Int
end
AletheiaData.feature_value(::CountScalarSource, i, w, ::Val{:x}) = i + w
struct OtherScalarCondition <: AbstractScalarCondition end

@testset "scalar protocol dispatch coverage" begin
    fr2 = Frame((:a, :b), Dict(:R => Dict(:a => [:b], :b => [])); index=true)
    props2 = ScalarPropertySource(Dict((1, :a) => 1.0, (1, :b) => 2.0), [fr2], [1])
    prep2 = prepare_scalar(props2; features=[Val(:x)])
    sig2 = Signature((¬, Diamond(:R)))
    pool2 = FormulaPool(sig2)
    cgt2 = atom(pool2, ThresholdCondition(Val(:x), >, 1.5))
    dense = DenseFeatureStore(reshape([1, 2, 3, 4], 2, 2, 1), [:a, :b], [Val(:x)]; instances=[10, 20], version=7)
    @test data_version(dense) == 7
    @test AletheiaData._aggregate_name(maximum) == :maximum
    @test AletheiaData._aggregate_name(max) == :maximum
    @test AletheiaData._aggregate_name(minimum) == :minimum
    @test AletheiaData._aggregate_name(min) == :minimum
    @test AletheiaData._aggregate_name(sum) == :sum
    @test size(dense) == (2, 2, 1)
    @test feature_value(dense, 20, :b, Val(:x)) == 4
    @test AletheiaData.features(dense) == (Val(:x),)
    @test AletheiaData.instances(dense) == (10, 20)
    @test Aletheia.worlds(dense) == (:a, :b)
    @test aggregate_value(dense, 10, (:a, :b), :R, Val(:x), max) == 2
    @test aggregate_value(dense, 10, (:a, :b), :R, Val(:x), min) == 1
    dense_prep2 = prepare_scalar(dense; frames=Frame((:a, :b), Dict(); index=true))
    @test dense_prep2.store.values == dense.values
    @test prepare_scalar(dense_prep2).store.values == dense.values

    @test prepare_scalar(props2; features=[Val(:x)], frames=fr2).store.values[1, 1, 1] == 1.0
    @test prepare_scalar(props2; features=[Val(:x)], frames=[fr2]).store.values[2, 1, 1] == 2.0
    count_source = CountScalarSource(2)
    count_prep2 = prepare_scalar(count_source; features=[Val(:x)], worlds=[1, 2], instances=nothing)
    @test count_prep2.store.values[:, 2, 1] == Any[3, 4]
    @test prepare_scalar(props2; features=[Val(:x)], precompute_aggregates=true).one_step_memos.global_values !== nothing
    @test prepare_scalar(props2; features=[Val(:x)], precompute_aggregates=:all).one_step_memos.global_values !== nothing
    @test prepare_scalar(props2; features=[Val(:x)], precompute_aggregates=[Val(:x) => maximum]).one_step_memos.global_values !== nothing
    @test_throws ArgumentError prepare_scalar(props2; features=[Val(:x)], precompute_aggregates=[:bad])
    @test_throws ArgumentError prepare_scalar(props2; features=[Val(:x)], precompute_aggregates=[(:x, maximum, :extra)])

    @test batch_apply([cgt2], prep2; cache=ScalarEvaluationCache(prep2)) isa Vector
    warm_cache = ScalarEvaluationCache(prep2)
    batch_apply([cgt2], prep2; cache=warm_cache)
    warm = batch_apply([cgt2], prep2; cache=warm_cache, trace=true)
    @test any(entry -> entry.kind == :formula_cache_hit, warm.traces)
    @test_throws MethodError scalar_check(OtherScalarCondition(), prep2, 1, :a)

    interval_worlds = (Interval(1, 2), Interval(1, 3), Interval(2, 3))
    interval_frame = Frame(interval_worlds, Dict(); index=true)
    interval_prep = prepare_scalar([[2.0, 5.0]]; features=[v -> minimum(v)],
        frames=[interval_frame], instances=[1])
    @test interval_prep.store.values[:, 1, 1] == Any[2.0, 2.0, 5.0]
    rectangle_world = Rectangle((1, 3), (1, 3))
    rectangle_frame = Frame((rectangle_world,), Dict(); index=true)
    rectangle_prep = prepare_scalar([reshape([1.0, 2.0, 3.0, 4.0], 2, 2);
        ]; features=[v -> sum(v)], frames=[rectangle_frame], instances=[1])
    @test feature_value(rectangle_prep, 1, rectangle_world, first(rectangle_prep.store.features)) == 10.0
    point_world = Point(2)
    point_frame = Frame((point_world,), Dict(); index=true)
    point_prep = prepare_scalar([[3.0, 7.0]]; features=[identity], frames=[point_frame], instances=[1])
    @test feature_value(point_prep, 1, point_world, identity) == 7.0
end


@testset "explicit scalar worlds match frame domains" begin
    f1 = Frame((1, 2), Dict(); index=true); f2 = Frame((1, 2, 3), Dict(); index=true)
    @test_throws ScalarWorldDomainError prepare_scalar(nothing;
        features=[(data, instance, world) -> world], frames=[f1, f2],
        instances=[1, 2], worlds=[1, 2])
end
