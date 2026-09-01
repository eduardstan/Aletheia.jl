@testset "finite distribution-semantics front end" begin
    rain = ProbabilisticFact(:rain, 3//10)
    program = DSProgram([rain], [GroundRule(:wet, (:rain,))])
    @test length(choices(program)) == 1
    @test facts(program) == (rain,)
    @test rules(program)[1].head == :wet
    @test AletheiaCircuits.domain(program) == ()
    all_choices = total_choices(program)
    @test length(all_choices) == 2
    @test world(program, all_choices[1]) == Set([:rain, :wet])
    @test world(program, all_choices[2]) == Set{Any}()
    @test sum(choice_probability(program, selection) for selection in all_choices) == 1
    @test GroundRule(:certain, nothing).body == ()
    @test choice_probability(program, all_choices[1]) == 3//10
    @test choice_probability(program, all_choices[2]) == 7//10
    @test ground(program, :wet) === program
    @test validate_program(program) === nothing

    multi = ChoiceVariable(:weather, (:sun, :rain, nothing), (1//5, 3//10, 1//2))
    multi_program = DSProgram([multi])
    @test alternatives(multi) == (:sun, :rain, nothing)
    @test weights(multi) == (1//5, 3//10, 1//2)
    @test choice_id(multi) == :weather
    @test world(multi_program, Dict(:weather => :rain)) == Set([:rain])
    @test length(total_choices(multi_program)) == 3

    @test_throws UnnormalizedWeightsError ChoiceVariable(:bad, (:a, :b), (1//3, 1//3))
    @test_throws InvalidProbabilityError ProbabilisticFact(:a, 2)
    @test_throws ProgramValidationError ChoiceVariable(:bad, (:a, :a), (1, 0))
    @test_throws ProgramValidationError DSProgram([:not_a_choice])

    cyclic = DSProgram(
        ChoiceVariable(:x, (:on, nothing), (1//2, 1//2));
        rules=[GroundRule(:a, (:b,)), GroundRule(:b, (:a,))],
    )
    @test_throws ProgramValidationError validate_program(cyclic)
    @test_throws UnsupportedFeatureError validate_program(
        cyclic, DSProfile(; acyclic=false)
    )
    variable = AletheiaCore.Variable(:X)
    @test_throws GroundingError validate_program(
        DSProgram([ProbabilisticFact(:a, 1//2)], [GroundRule(:b, (variable,))])
    )
    function_term = AletheiaCore.FunctionTerm(:f, AletheiaCore.Constant(:a))
    @test_throws UnsupportedFeatureError validate_program(
        DSProgram([ProbabilisticFact(function_term, 1//2)])
    )
    @test_throws UnsupportedFeatureError ground(
        program, :wet; profile=DSProfile(; function_free=false)
    )

    negative = DSProgram(
        [ProbabilisticFact(:rain, 1//2)], [GroundRule(:dry, (Not(:rain),))]
    )
    @test world(negative, Dict((:probabilistic_fact, :rain) => nothing)) == Set([:dry])
end

@testset "grounding profile and event expressions" begin
    @test Not(:a).child == :a
    @test And(:a, :b).children == (:a, :b)
    @test Or((:a, :b)).children == (:a, :b)
    p = DSProgram([ProbabilisticFact(:a, 1//2)])
    @test_throws UnsupportedFeatureError compile_event(p, :a; backend=:cudd)
    @test_throws UnsupportedFeatureError query_event(
        p, :a; profile=DSProfile(; locally_stratified=true)
    )
    @test_throws GroundingError world(p, Dict())
end
