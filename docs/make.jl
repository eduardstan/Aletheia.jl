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
    modules = [Aletheia, Aletheia.SoleLogics],
    pages = ["Home" => "index.md", "Migration" => "compatibility.md"],
    plugins = [bibliography],
)
