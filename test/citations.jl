@testset "citation integrity" begin
    semantics_source = read(joinpath(@__DIR__, "..", "src", "semantics.jl"), String)
    @test occursin("Goranko, *Logic as a Tool*, §§1.1.2–1.1.5 (pp. 3–6) [goranko2016](@cite)", semantics_source)
    @test occursin("§2.2 (printed pp. 91–94), with the residuation law stated in the\nIntroduction (printed p. 2) [galatos2007](@cite)", semantics_source)
    @test occursin("specific many-valued logics\noutside the book's scope (Introduction, printed p. 7)", semantics_source)
    @test occursin("this named Gödel table awaits a dedicated source", semantics_source)
    @test occursin("this named Łukasiewicz table awaits a dedicated source", semantics_source)
    @test !occursin("chain operation; see Goranko", semantics_source)

    relations_source = read(joinpath(@__DIR__, "..", "src", "relations.jl"), String)
    @test occursin("\"\"\"Allen interval relations.\"\"\"", relations_source)
    @test !occursin("Halpern", relations_source)

    learning = read(joinpath(@__DIR__, "..", "docs", "src", "learning.md"), String)
    @test occursin("first appears in §5.2.1 (p. 643) and is\nrevisited in §5.5 (p. 648)", learning)
    @test occursin("[muggleton1994; §5.2.1, p. 643; §5.5, p. 648](@cite)", learning)
    @test !occursin("§5.5.2 (pp. 648–649)", learning)
    @test occursin("[tamaddoni2008; pp. 297–314](@cite)", learning)
    @test !occursin("[zelezny2008;", learning)

    refs = read(joinpath(@__DIR__, "..", "docs", "src", "refs.bib"), String)
    @test occursin("@incollection{tamaddoni2008,", refs)
    @test occursin("author    = {Alireza Tamaddoni-Nezhad and Stephen Muggleton}", refs)
    @test occursin("editor    = {Filip Železný and Nada Lavrač}", refs)
    @test occursin("series    = {Lecture Notes in Artificial Intelligence}", refs)
    @test occursin("volume    = {5194}", refs)
    @test occursin("pages     = {297--314}", refs)

    algebras = read(joinpath(@__DIR__, "..", "docs", "src", "algebras.md"), String)
    @test occursin("[galatos2007; §2.2, pp. 91–94](@cite)", algebras)

    relation_docs = read(joinpath(@__DIR__, "..", "docs", "src", "relations.md"), String)
    @test occursin("reflexivity with `T`, transitivity with `4` [blackburn2001; §3.1, Definitions\n3.1–3.5 and Example 3.6, pp. 125–129](@cite)", relation_docs)

    bisimulation_source = read(joinpath(@__DIR__, "..", "src", "bisimulation.jl"), String)
    @test occursin("These are derived implementation bounds, not bounds stated\nby the cited literature.", bisimulation_source)
    @test occursin("this implementation's partition refinement costs", bisimulation_source)
    theory = read(joinpath(@__DIR__, "..", "docs", "src", "theory.md"), String)
    @test occursin("derived implementation bounds for Aletheia, not bounds stated\nby the cited literature", theory)
end
