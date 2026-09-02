@testset "choice label normalization property" begin
    @check function normalized_binary_choice(p=Supposition.Data.Integers{Int8}())
        numerator = abs(Int(p)) % 101
        a = numerator//100
        choice = ChoiceVariable(:generated, (:yes, nothing), (a, 1 - a))
        return sum(choice.weights) == 1
    end
end

@testset "certified diagram properties" begin
    @check function reduced_ordered_certificate(p=Supposition.Data.Integers{Int8}())
        numerator = abs(Int(p)) % 9
        probability = numerator//8
        choice = ChoiceVariable(:generated, (:yes, nothing), (probability, 1 - probability))
        event = compile_event(DSProgram([choice]), :yes)
        certificate = validate(event.circuit)
        return certificate.determinism &&
                   certificate.smoothness &&
                   all(
                       node.var == 0 || node.var in eachindex(event.circuit.variables) for
                       node in event.circuit.nodes
                   )
    end
end
