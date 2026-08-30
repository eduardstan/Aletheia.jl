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

@testset "published claim integrity" begin
    root = joinpath(@__DIR__, "..")
    readme = read(joinpath(root, "README.md"), String)
    results = read(joinpath(root, "docs", "src", "results.md"), String)
    index = read(joinpath(root, "docs", "src", "index.md"), String)
    compatibility = read(joinpath(root, "docs", "src", "compatibility.md"), String)
    families = read(joinpath(root, "docs", "src", "families.md"), String)
    quickstart = read(joinpath(root, "docs", "src", "quickstart.md"), String)
    semantics = read(joinpath(root, "docs", "src", "semantics.md"), String)
    algebras = read(joinpath(root, "docs", "src", "algebras.md"), String)
    docs_sources = join(read.(filter(p -> endswith(p, ".md"), readdir(joinpath(root, "docs", "src"); join=true)), String))

    for retracted in ("6" * ".81×", "9" * ".67×", "0" * ".92×", "45" * ".70×")
        @test !normalized_occurs(retracted, readme)
        @test !normalized_occurs(retracted, docs_sources)
    end
    @test normalized_occurs("five-seed medians", readme)
    @test normalized_occurs("4.60×", results)
    @test normalized_occurs("1.02×–1.15×", results)
    @test normalized_occurs("5.6 worlds out of 1,326", results)
    @test normalized_occurs("238×", results)
    @test normalized_occurs("ModalDecisionTrees cannot accept a quotient", results)
    @test normalized_occurs("height-8 formulas", results)
    @test normalized_occurs("≈16.8× more allocations", results)
    @test normalized_occurs("workload-specific", results)
    @test !normalized_occurs("expect pooled identity and DAG sharing to matter", results)
    @test normalized_occurs("data/benchmark-run/run.txt", results)
    @test normalized_occurs("data/benchmark-run/corrections.md", results)
    @test normalized_occurs("range", results)
    @test normalized_occurs("[no clear winner]", results)
    @test normalized_occurs("scores four hypotheses against eight seeded models", results)
    artifact = read(joinpath(root, "data", "benchmark-run", "run.txt"), String)
    @test normalized_occurs("seed_count=5", artifact)
    @test normalized_occurs("uptime_start=", artifact)
    @test normalized_occurs("uptime_end=", artifact)
    @test normalized_occurs("seed_ratios=", artifact)
    @test normalized_occurs("seed_loads=", artifact)
    @test normalized_occurs("range ", artifact)
    @test !normalized_occurs("[UNSTABLE]", artifact)
    @test normalized_occurs("[no clear winner]", artifact)

    @test !normalized_occurs("changing one import line", index)
    @test normalized_occurs("selected\nSoleLogics consumers", index)
    @test normalized_occurs("107 of 142", compatibility)
    @test normalized_occurs("64 decisions over eight algebra/height configurations", compatibility)
    @test normalized_occurs("42 of them carrying at least one truth-constant leaf", compatibility)
    @test normalized_occurs("verdicts differ | **0**", compatibility)
    @test normalized_occurs("wall-clock fact, not a capability difference", compatibility)
    @test !normalized_occurs("Both sides produced 72 decisions", compatibility)
    @test !normalized_occurs("pre-parsed tableau search", compatibility)
    for name in ("AbstractAssignment", "AbstractDimensionalFrame", "AbstractInterpretation",
                 "AbstractKripkeStructure", "CONJUNCTION", "CheckAlgorithm", "Full0DFrame",
                 "Full1DFrame", "Full2DFrame", "LogicalInstance", "OneWorld", "Point3D",
                 "SyntaxToken", "X", "Y", "Z", "composeformulas", "frametype",
                 "intervals2D_in", "intervals_in", "ndisjuncts", "nparameters", "nworlds",
                 "short_intervals_in", "valuetype")
        @test normalized_occurs(name, compatibility)
    end
    @test normalized_occurs("Extension results are not cached across instances", families)
    @test normalized_occurs("relation adjacency\non a shared `Frame` may be cached and reused", families)
    @test !normalized_occurs("one or more named accessibility relations", quickstart)
    @test !normalized_occurs("one or more\nnamed accessibility relations", semantics)
    @test normalized_occurs("zero or more", quickstart)
    @test normalized_occurs("zero or more", semantics)
    @test normalized_occurs("square integer matrix", algebras)
    @test normalized_occurs("Flat\ninteger vectors or tuples", algebras)
end
