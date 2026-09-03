@testset "BDD certificates and weighted model counting" begin
    p = DSProgram(
        [
            ChoiceVariable(:x, (:x, nothing), (3//10, 7//10)),
            ChoiceVariable(:y, (:y, nothing), (1//2, 1//2)),
        ],
        [GroundRule(:shared, (:x, :y))],
    )
    repeated_or = compile_event(p, Or(:x, :x))
    repeated_and = compile_event(p, And(:x, :x))
    shared = compile_event(p, :shared)
    both = compile_event(p, And(:x, :y))
    skipped = compile_event(p, :x)
    @test wmc(repeated_or; semiring=RationalProfile()) == 3//10
    @test wmc(repeated_and; semiring=RationalProfile()) == 3//10
    @test wmc(shared; semiring=RationalProfile()) == 3//20
    @test wmc(both; semiring=RationalProfile()) == 3//20
    @test isapprox(wmc(shared), 0.15; atol=eps(Float64) * 8)
    @test abs(wmc(shared) - Float64(wmc(shared; semiring=RationalProfile()))) < 1e-12
    @test length(skipped.circuit.nodes) < length(compile_event(p, Or(:x, :y)).circuit.nodes)
    @test wmc(skipped.circuit; labels=skipped.labels, semiring=RationalProfile()) == 3//10

    @testset "diagram against total-choice oracle" begin
        expressions = (:x, :y, And(:x, :y), Or(:x, :y), Not(:x), :shared)
        for expression in expressions
            event = compile_event(p, expression)
            oracle = sum(
                choice_probability(p, selection; T=Rational{Int}) for
                selection in total_choices(p) if
                AletheiaCircuits._expression_value(expression, world(p, selection));
                init=0//1,
            )
            @test wmc(event; semiring=RationalProfile()) == oracle
        end
    end

    circuit = repeated_or.circuit
    @test validate(circuit) === circuit.certificate
    @test variable_order(circuit) == (:x, :y)
    @test support(circuit, circuit.roots[1]) == (:x,)
    @test source_provenance(circuit, circuit.roots[1]).source.query == Or(:x, :x)
    @test circuit.certificate.determinism
    @test circuit.certificate.smoothness
    raw = BDD(
        circuit.nodes,
        circuit.roots;
        variables=circuit.variables,
        alternatives=circuit.alternatives,
    )
    @test_throws UncertifiedCircuitError validate(raw)
    @test_throws UncertifiedCircuitError AletheiaCircuits.evaluate(
        raw, Float64Profile(); labels=raw
    )

    @test zero(Float64Profile()) == 0.0
    @test one(RationalProfile()) == 1//1
    @test add(Float64Profile(), 0.2, 0.3) == 0.5
    @test mul(RationalProfile(), 2//3, 3//4) == 1//2
    labels = Dict(:x => 0.3)
    @test literal_label(Float64Profile(), ChoiceLiteral(:x, true), labels) == 0.3
    @test literal_label(Float64Profile(), ChoiceLiteral(:x, false), labels) == 0.7
    @test literal_label(
        Float64Profile(), ChoiceLiteral(ChoiceAlternative(:x, 1), true), labels
    ) == 0.3
    @test literal_label(
        Float64Profile(), ChoiceLiteral(ChoiceAlternative(:x, 2), true), labels
    ) == 0.7
    @test neutral_sum(Float64Profile(), :x, Dict(:x => (0.3, 0.7))) == 1.0
    @test_throws InvalidProbabilityError literal_label(
        Float64Profile(), ChoiceLiteral(:missing, true), labels
    )

    evidence = compile_event(p, :y)
    query = compile_event(p, :x)
    @test conditional_probability(query, evidence; semiring=RationalProfile()) == 3//10
    @test conditional_probability(query, evidence) ≈ 0.3
    joint_with_evidence = compile_event(p, :x; evidence=:y)
    @test wmc(compile_event(p, DSQuery(:x; evidence=:y)); semiring=RationalProfile()) ==
          3//20
    @test wmc(joint_with_evidence; semiring=RationalProfile()) == 3//20
    @test conditional_probability(
        joint_with_evidence, evidence; semiring=RationalProfile()
    ) == 3//10

    impossible = DSProgram([ProbabilisticFact(:never, 0//1)])
    @test_throws ZeroMassEvidenceError compile_event(impossible, :never; evidence=:never)
    impossible_event = compile_event(p, :absent)
    @test_throws ZeroMassEvidenceError conditional_probability(query, impossible_event)
    @test_throws ProgramValidationError conditional_probability(
        query, compile_event(DSProgram([ProbabilisticFact(:other, 1//2)]), :other)
    )
    altered = DSProgram(
        [
            ChoiceVariable(:x, (:x, nothing), (1//2, 1//2)),
            ChoiceVariable(:y, (:y, nothing), (1//2, 1//2)),
        ],
        [GroundRule(:shared, (:x, :y))],
    )
    @test_throws ProgramValidationError conditional_probability(
        query, compile_event(altered, :y)
    )
end

@testset "rational profile converts Float64 weights" begin
    p = DSProgram(choices=[ChoiceVariable(:c, (:yes, :no), (0.1, 0.9))])
    @test wmc(compile_event(p, :yes); semiring=RationalProfile()) == 1//10
end

@testset "finite containers and rational normalization" begin
    cyclic = Dict{Symbol,Any}(); cyclic[:self] = cyclic
    @test_throws UnsupportedFeatureError ChoiceVariable(
        :c, (cyclic, nothing), (1//2, 1//2)
    )
    weights = (0.123456789, 0.234567891, 0.64197532)
    pfloat = DSProgram(choices=[ChoiceVariable(:c, Tuple(Symbol.("a", 1:3)), weights)])
    tautology = compile_event(pfloat, Or(:a1, :a2, :a3))
    @test wmc(tautology; semiring=RationalProfile()) == 1 // 1
    @test wmc(tautology; semiring=RationalProfile()) isa Rational
end

@testset "finite ground values are checked and queryable" begin
    values = Any[
        :atom, 'x', "text", 7, 1//2,
        (:left, :right),
        (tag=:record,),
        Set([:member]),
        Dict(:key => :value),
    ]
    for value in values
        choice = ChoiceVariable(:value, (value, nothing), (1//2, 1//2))
        program = DSProgram(choices=[choice])
        @test validate_program(program) === nothing
        @test wmc(compile_event(program, value); semiring=RationalProfile()) == 1//2
    end
    for cyclic in (Any[], Dict{Symbol,Any}())
        if cyclic isa AbstractVector
            push!(cyclic, cyclic)
        else
            cyclic[:self] = cyclic
        end
        @test_throws UnsupportedFeatureError ChoiceVariable(
            :cyclic, (cyclic, nothing), (1//2, 1//2)
        )
    end
end
