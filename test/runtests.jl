using Test
using Random
using Aqua
using JET
using Aletheia

@testset "compatibility remains opt-in" begin
    @test !hasmethod(Aletheia.Atom, Tuple{Any})
    @test !applicable(Aletheia.Atom, :p)
    @test !hasmethod(Aletheia.Branch, Tuple{Any,Tuple})
    @test !applicable(Aletheia.Branch, Aletheia.:∧, ())
end

struct TestXor end
Aletheia.arity(::TestXor) = 2
Aletheia.precedence(::TestXor) = 15
Aletheia.associativity(::TestXor) = :left
Aletheia.notation(::TestXor) = "⊻"

struct TestNullary end
Aletheia.arity(::TestNullary) = 0
Aletheia.notation(::TestNullary) = "z"

struct TestTernary end
Aletheia.arity(::TestTernary) = 3
Aletheia.precedence(::TestTernary) = 40
Aletheia.notation(::TestTernary) = "T"

struct TestWhitespaceNotation end
Aletheia.arity(::TestWhitespaceNotation) = 1
Aletheia.notation(::TestWhitespaceNotation) = "bad op"

struct TestEmptyNotation end
Aletheia.arity(::TestEmptyNotation) = 1
Aletheia.notation(::TestEmptyNotation) = ""

struct TestDelimiterNotation end
Aletheia.arity(::TestDelimiterNotation) = 1
Aletheia.notation(::TestDelimiterNotation) = "("

struct TestUnspecified end
struct TestUnionPayload
    value::Union{Int,Vector{Int}}
end

@testset "syntax" begin
    diamond = Diamond(:G)
    box = Box(:G)
    sig = Signature((¬, ∧, ⊗, ∨, →, diamond, box, TestXor()))
    pool = FormulaPool(sig)

    p = atom(pool, "p")
    q = atom(pool, "q")
    @test p isa Formula
    @test id(atom(pool, "p")) == id(p)
    @test atom(pool, "p") == p
    quoted = atom(pool, "a→b\"c")
    @test parse(pool, string(quoted)) == quoted

    modal = parse(pool, "⟨G⟩p → [G]q")
    @test string(modal) == "⟨G⟩p → [G]q"
    @test parse(pool, string(modal)) == modal
    fusion_formula = branch(pool, ⊗, p, q)
    @test string(fusion_formula) == "p ⊗ q"
    @test parse(pool, string(fusion_formula)) == fusion_formula
    @test string(parse(pool, "¬1→0"; atom_parser=x -> Base.parse(Float64, x))) == "¬1.0 → 0.0"
    @test string(parse(pool, "¬a → b ∧ c")) == "¬a → b ∧ c"

    left_nested = branch(pool, ∧, branch(pool, →, p, q), q)
    @test string(left_nested) == "(p → q) ∧ q"
    @test string(branch(pool, ¬, branch(pool, ∧, p, q))) == "¬(p ∧ q)"
    @test string(branch(pool, →, p, branch(pool, →, q, p))) == "p → q → p"
    @test string(branch(pool, →, branch(pool, →, p, q), p)) == "(p → q) → p"

    repeated = branch(pool, ∧, branch(pool, TestXor(), p, q), branch(pool, TestXor(), p, q))
    @test id(children(repeated)[1]) == id(children(repeated)[2])
    shallow = branch(pool, ∧, p, q)
    deep = branch(pool, ∧, shallow, q)
    @test typeof(shallow) == typeof(deep)
    @test fieldtype(typeof(shallow), 4) == NTuple{2,Int}
    @test nchildren(deep) == arity(deep) == 2
    @test children(deep)[1] == shallow
    @test nsubterms(repeated) == 4
    ids = subterms(repeated)
    @test ids == sort(ids)
    @test [node.id for node in dag(repeated)] == ids
    @test all(all(child < node.id for child in node.children) for node in dag(repeated))
    @test all(node isa Aletheia.DAGNode for node in dag(repeated))

    other_pool = FormulaPool(sig)
    @test atom(other_pool, "p") != p
    @test nsubterms(pool) == length(subterms(pool))
    @test arity(sig, TestXor()) == 2

end

@testset "syntax edge cases and API" begin
    invoke_trait(f, x) = Base.invokelatest(f, x)
    invoke_trait3(f, x, y) = Base.invokelatest(f, x, y)
    @test invoke_trait(hasdual, TestUnspecified()) == false
    @test invoke_trait(precedence, TestUnspecified()) == 0
    @test invoke_trait(associativity, TestUnspecified()) == :none
    @test invoke_trait(Aletheia.commutative, TestUnspecified()) == false
    @test invoke_trait(Aletheia.modality, TestUnspecified()) == false
    @test invoke_trait(Aletheia.iscommutative, TestUnspecified()) == false
    @test invoke_trait(Aletheia.ismodality, TestUnspecified()) == false
    @test_throws MethodError arity(TestUnspecified())
    @test_throws ArgumentError dual(TestUnspecified())
    @test precedence(TestUnspecified()) == 0
    @test associativity(TestUnspecified()) == :none
    @test !Aletheia.commutative(TestUnspecified())
    @test !Aletheia.modality(TestUnspecified())
    @test !hasdual(TestUnspecified())
    @test !Aletheia.iscommutative(TestUnspecified())
    @test !Aletheia.ismodality(TestUnspecified())
    @test notation(TestUnspecified()) isa String

    @test Signature([¬, ∧, ⊗]).arities == (1, 2, 2)
    @test Signature([¬, ∧, ⊗], [1, 2, 2]).arities == (1, 2, 2)
    @test_throws ArgumentError Signature(())
    @test_throws ArgumentError Signature((¬, ∧), (1,))
    @test_throws ArgumentError Signature((¬,), (2,))
    @test_throws ArgumentError Signature((∧, Conjunction()))
    @test_throws ArgumentError Signature((TestWhitespaceNotation(),))
    @test_throws ArgumentError Signature((TestEmptyNotation(),))
    @test_throws ArgumentError Signature((TestDelimiterNotation(),))

    nullary = TestNullary()
    ternary = TestTernary()
    sig = Signature((¬, ∧, ⊗, nullary, ternary))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    q = atom(pool, "q")
    r = atom(pool, "r")
    z = branch(pool, nullary)
    @test branch(pool, nullary, ()) == z
    @test string(z) == "z"
    @test parse(pool, "z()") == z
    @test parse("z()", pool) == z
    @test parse(pool, "(p)") == p
    @test parse(pool, "¬(p)") == branch(pool, ¬, p)
    t = parse(pool, "T(p,q,r)")
    @test t == branch(pool, ternary, p, q, r)
    @test string(t) == "T(p, q, r)"
    @test nchildren(p) == 0
    @test nchildren(t) == arity(t) == 3
    @test children(p) == ()
    @test children(t) == (p, q, r)
    @test signature(pool) == sig
    @test signature(p) == sig
    @test signature(t) == sig
    @test connectives(sig) == sig.connectives
    @test hasconnective(sig, ternary)
    @test !hasconnective(sig, TestXor())
    @test_throws ArgumentError arity(sig, TestXor())

    @test Aletheia._formula(pool, id(p)) == p
    @test Aletheia._formula(pool, id(t)) == t
    @test Atom(pool, id(p), "p") == p
    @test_throws ArgumentError Atom(pool, id(p), "evil")
    @test_throws ArgumentError Atom(pool, 999, "q")
    @test_throws ArgumentError Branch(pool, id(p), ¬, (id(p),))
    @test_throws ArgumentError Branch(pool, id(t), ¬, (id(p),))
    mutable_atom_payload = [1]
    @test_throws ArgumentError atom(pool, mutable_atom_payload)
    # A union field is value-dependent: its immutable alternative is accepted,
    # while the mutable alternative remains rejected.
    @test Aletheia._payload_is_immutable(TestUnionPayload(1))
    @test !Aletheia._payload_is_immutable(TestUnionPayload([1]))
    mutable_relation = [:R]
    mutable_pool = FormulaPool(Signature((Diamond(mutable_relation),)))
    mutable_p = atom(mutable_pool, "p")
    @test_throws ArgumentError branch(mutable_pool, Diamond(mutable_relation), mutable_p)
    @test_throws BoundsError Aletheia._formula(pool, 0)
    @test dag(pool) isa Vector{Aletheia.DAGNode}
    @test dag(pool, id(t)).id == id(t)
    @test_throws BoundsError dag(pool, 0)
    @test subterms(p) == [id(p)]
    @test dag(p)[1].kind == :atom
    @test nsubterms(p) == 1
    @test nsubterms(pool) == length(subterms(pool))

    other = FormulaPool(sig)
    otherp = atom(other, "p")
    @test Aletheia.pool(p) === pool
    @test id(p) == id(otherp)
    @test !isequal(p, otherp)
    @test !(p == otherp)
    @test !isequal(p, t)
    @test !isequal(t, p)
    @test !(p == t)
    @test !(t == p)
    @test hash(p) isa UInt
    @test hash(t) isa UInt
    @test operator(t) === ternary
    @test head(t) === ternary
    @test value(p) == "p"
    @test isatom(p) && !isatom(t)
    @test !isbranch(p) && isbranch(t)
    @test invoke_trait(Aletheia.pool, t) === pool
    @test invoke_trait(nchildren, p) == 0
    @test invoke_trait(arity, p) == 0
    @test invoke_trait(isatom, p) && !invoke_trait(isatom, t)
    @test !invoke_trait(isbranch, p) && invoke_trait(isbranch, t)
    @test Base.invokelatest(Atom, pool, "new") == atom(pool, "new")
    @test Base.invokelatest(Branch, pool, ∧, (p, q)) == branch(pool, ∧, p, q)
    @test :_TrustedFormulaHandle ∉ names(Aletheia, all=false)
    @test :_trusted_formula_handle ∉ names(Aletheia, all=false)
    @test Base.invokelatest(Branch, pool, ∧, p, q) == branch(pool, ∧, p, q)
    @test invoke_trait3(isequal, t, t)
    @test !invoke_trait3(isequal, p, t) && !invoke_trait3(isequal, t, p)
    @test !Base.invokelatest((==), p, t) && !Base.invokelatest((==), t, p)

    @test arity(¬) == 1
    @test arity(∧) == 2
    @test arity(∨) == 2
    @test arity(→) == 2
    @test arity(Diamond(:G)) == 1
    @test arity(Box(:G)) == 1
    @test precedence(¬) > precedence(∧) > precedence(∨) > precedence(→)
    @test associativity(∧) == :left && associativity(→) == :right
    @test Aletheia.commutative(∧) && Aletheia.commutative(∨)
    @test Aletheia.modality(Diamond(:G)) && Aletheia.modality(Box(:G))
    @test Aletheia.ismodality(Diamond(:G))
    @test relation(Diamond(:G)) == :G && relation(Box(:G)) == :G
    @test dual(¬) === ¬
    @test dual(∧) === (∨) && dual(∨) === (∧)
    @test dual(Diamond(:G)) == Box(:G)
    @test dual(Box(:G)) == Diamond(:G)
    @test hasdual(Diamond(:G))
    for c in (¬, ∧, ∨, →, Diamond(:G), Box(:G))
        @test invoke_trait(arity, c) == arity(c)
        @test invoke_trait(precedence, c) == precedence(c)
        @test invoke_trait(associativity, c) == associativity(c)
    end
    for c in (∧, ∨)
        @test invoke_trait(Aletheia.commutative, c)
    end
    for c in (Diamond(:G), Box(:G))
        @test invoke_trait(Aletheia.modality, c)
        @test invoke_trait(hasdual, c)
    end
    @test invoke_trait(hasdual, ¬)
    @test sprint(show, p) == "p"
    @test sprint(show, t) == "T(p, q, r)"
    @test sprint(show, ∧) == "∧"
    @test sprint(show, ⊗) == "⊗"
    @test sprint(show, ∨) == "∨"
    @test sprint(show, →) == "→"
    @test sprint(show, ¬) == "¬"
    @test sprint(show, Diamond(:G)) == "⟨G⟩"
    @test sprint(show, Box(:G)) == "[G]"

    @test_throws ArgumentError parse(pool, "")
    @test_throws ArgumentError parse(pool, "(")
    @test_throws ArgumentError parse(pool, "T p")
    @test_throws ArgumentError parse(pool, "T(p,q)")
    @test_throws ArgumentError parse(pool, "T(p,q,r,s)")
    @test_throws ArgumentError parse(pool, "T(p,q,r")
    @test_throws ArgumentError parse(pool, "¬(p")
    @test_throws ArgumentError parse(pool, "¬(p,q)")
    @test_throws ArgumentError parse(pool, "z(p)")
end

include("defaultpool.jl")
include("semantics.jl")
include("evaluation.jl")
include("dataset.jl")
include("algebras.jl")
include("relations.jl")
include("relation_properties.jl")
include("theory.jl")
include("compatibility.jl")
include("citations.jl")
include("vocabulary.jl")
include("ilp.jl")
include("presentation.jl")
include("examples.jl")
include("benchmark_load_gate.jl")
include("benchmark_measurement.jl")
@testset "Aletheia" begin
    Aqua.test_all(Aletheia)
    if pkgversion(JET) < v"0.11"
        JET.test_package(Aletheia; target_defined_modules=true)
    else
        JET.test_package(Aletheia; target_modules=(Aletheia,), analyze_from_definitions=true)
    end
end


@testset "scalar data preparation and evaluation" begin
    mutable struct VersionedScalarSource
        values::Dict{Tuple{Int,Int},Float64}
        version::UInt64
    end
    source = VersionedScalarSource(Dict((1, 1) => 0.2, (1, 2) => 0.8,
        (1, 3) => 0.4, (2, 1) => 0.9, (2, 2) => 0.1, (2, 3) => 0.6), 1)
    Aletheia.feature_value(x::VersionedScalarSource, i, w, ::Val{:x}) = x.values[(i, w)]
    Aletheia.feature_value(x::VersionedScalarSource, i, w, ::Val{:twice}) = 2x.values[(i, w)]
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
Aletheia.feature_value(s::ScalarPropertySource, i, w, ::Val{:x}) = s.values[(i, w)]

@testset "scalar protocol edge cases" begin
    fr = Frame((:a, :b), Dict(:R => Dict(:a => [:b], :b => [])); index=true)
    props = ScalarPropertySource(Dict((1, :a) => 1.0, (1, :b) => 2.0), [fr], [1])
    prep = prepare_scalar(props; features=[Val(:x)])
    @test prep.store.worlds == [:a, :b]
    @test Aletheia.instances(prep.store) == (1,)
    @test worlds(prep.store) == (:a, :b)
    @test Aletheia.features(prep.store) == (Val(:x),)
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
Aletheia.feature_value(::CountScalarSource, i, w, ::Val{:x}) = i + w
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
    @test Aletheia._aggregate_name(maximum) == :maximum
    @test Aletheia._aggregate_name(max) == :maximum
    @test Aletheia._aggregate_name(minimum) == :minimum
    @test Aletheia._aggregate_name(min) == :minimum
    @test Aletheia._aggregate_name(sum) == :sum
    @test size(dense) == (2, 2, 1)
    @test feature_value(dense, 20, :b, Val(:x)) == 4
    @test Aletheia.features(dense) == (Val(:x),)
    @test Aletheia.instances(dense) == (10, 20)
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
