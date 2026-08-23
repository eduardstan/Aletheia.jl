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
    checkdocs = :exports,
    modules = [Aletheia, Aletheia.SoleLogics],
    pages = [
        "Home" => "index.md",
        "Quick start" => "quickstart.md",
        "Syntax and design" => "design.md",
        "Semantics and evaluation" => "semantics.md",
        "Finite FLew-algebras" => "algebras.md",
        "Relations and frame classes" => "relations.md",
        "Theory" => "theory.md",
        "Learning from interpretations" => "learning.md",
        "Measured results" => "results.md",
        "Development and validation" => "development.md",
        "Migration" => "compatibility.md",
        "API reference" => "api.md",
    ],
    format = Documenter.HTML(size_threshold = 300 * 1024, size_threshold_warn = 300 * 1024),
    plugins = [bibliography],
)

deploydocs(
    repo = "github.com/eduardstan/Aletheia.jl.git",
    devbranch = "main",
)
