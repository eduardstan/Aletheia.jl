normalize_eol(text) = replace(text, "\r\n" => "\n")
normalized_occurs(needle, haystack) = occursin(normalize_eol(needle), normalize_eol(haystack))

@testset "citation integrity" begin
    @test normalized_occurs("a\nb", "a\r\nb")
    semantics_source = read(joinpath(@__DIR__, "..", "src", "semantics.jl"), String)
    @test !normalized_occurs("chain operation; see Goranko", semantics_source)

    relations_source = read(joinpath(@__DIR__, "..", "src", "relations.jl"), String)
    @test !normalized_occurs("Halpern", relations_source)

    learning = read(joinpath(@__DIR__, "..", "docs", "src", "learning.md"), String)
    @test !normalized_occurs("§5.5.2", learning)
    @test normalized_occurs("§5.2.1", learning)
    @test normalized_occurs("§5.5", learning)
    @test normalized_occurs("tamaddoni2008", learning)

    refs = read(joinpath(@__DIR__, "..", "docs", "src", "refs.bib"), String)
    @test normalized_occurs("@incollection{tamaddoni2008,", refs)
    @test normalized_occurs("pages     = {297--314}", refs)

    algebras = read(joinpath(@__DIR__, "..", "docs", "src", "algebras.md"), String)
    @test normalized_occurs("[galatos2007; §2.2, pp. 91–94](@cite)", algebras)

    relation_docs = read(joinpath(@__DIR__, "..", "docs", "src", "relations.md"), String)
    @test normalized_occurs("transitivity with `4` [blackburn2001;", relation_docs)

    bisimulation_source = read(joinpath(@__DIR__, "..", "src", "bisimulation.jl"), String)
    @test normalized_occurs("derived implementation bounds", bisimulation_source)
    theory = read(joinpath(@__DIR__, "..", "docs", "src", "theory.md"), String)
    @test normalized_occurs("derived implementation bounds", theory)
end
