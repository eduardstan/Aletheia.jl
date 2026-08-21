using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__))
Pkg.instantiate()

using Aletheia
using Documenter
using DocumenterCitations

bibliography = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"))

makedocs(
    sitename = "Aletheia.jl",
    checkdocs = :none,
    modules = [Aletheia, Aletheia.SoleLogics],
    pages = [
        "Home" => "index.md",
        "Quick start" => "quickstart.md",
        "Syntax and design" => "design.md",
        "Semantics and evaluation" => "semantics.md",
        "Relations and frame classes" => "relations.md",
        "Theory" => "theory.md",
        "Learning from interpretations" => "learning.md",
        "Measured results" => "results.md",
        "Development and validation" => "development.md",
        "Migration" => "compatibility.md",
    ],
    plugins = [bibliography],
)
