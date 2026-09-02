@testset "scalar data preparation" begin
    struct TestSource
        values::Dict{Tuple{Int,Symbol},Float64}
    end
    AletheiaData.feature_value(s::TestSource, i, w, ::Val{:x}) = s.values[(i, w)]
    fr = Frame((:a, :b), Dict(:R => Dict(:a => [:b], :b => [])); index=true)
    data = prepare_scalar(
        TestSource(Dict((1, :a) => 0.2, (1, :b) => 0.8));
        features=[Val(:x)],
        frames=[fr],
        instances=[1],
        relations=(:R,),
    )
    @test feature_value(data, 1, :b, Val(:x)) == 0.8
    condition = ThresholdCondition(Val(:x), >=, 0.5)
    @test scalar_check(condition, data, 1, :b)
    @test scalar_atom_values(condition, data, 1, (:a, :b)) == BitVector([0, 1])
    sig = Signature((¬, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    atom_condition = atom(pool, condition)
    @test check(branch(pool, Diamond(:R), atom_condition), data, 1, :a)
    @test check(branch(pool, Box(:R), atom_condition), data, 1, :a)
    @test batch_apply([atom_condition], data)[1][1] == BitVector([0, 1])
end
