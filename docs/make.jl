using Pkg
Pkg.activate(@__DIR__)
repo = dirname(@__DIR__)
packages = (
    "AletheiaCore",
    "AletheiaData",
    "AletheiaLearn",
    "AletheiaSole",
    "AletheiaCircuits",
    "AletheiaGraphs",
)
# Develop the umbrella and all focused packages in one resolution. The focused
# packages are not registered, and Pkg.develop does not consult a developed
# package's [sources] table when resolving its unregistered dependents.
local_packages = [Pkg.PackageSpec(path=repo);
    [Pkg.PackageSpec(path=joinpath(repo, "lib", package)) for package in packages]]
Pkg.develop(local_packages)
Pkg.instantiate()

import SoleData
using Aletheia
import AletheiaCore, AletheiaData, AletheiaLearn, AletheiaSole, AletheiaCircuits, AletheiaGraphs
using Documenter
using DocumenterCitations

bibliography = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"))

makedocs(
    sitename = "Aletheia.jl",
    checkdocs = :exports,
    modules = [
        Aletheia,
        AletheiaCore,
        AletheiaData,
        AletheiaLearn,
        AletheiaSole,
        AletheiaCircuits,
        AletheiaGraphs,
        Aletheia.SoleLogics,
    ],
    pages = [
        "Home" => "index.md",
        "Quick start" => "quickstart.md",
        "Syntax and design" => "design.md",
        "Design decisions" => "design-decisions.md",
        "Semantics and evaluation" => "semantics.md",
        "Many models, one formula" => "families.md",
        "Scalar data" => "scalar.md",
        "Finite FLew-algebras" => "algebras.md",
        "Distribution-semantics circuits" => "circuits.md",
        "Relations, frames, and frame classes" => "relations.md",
        "Knowledge graphs" => "graphs.md",
        "Theory utilities" => "theory.md",
        "Learning from interpretations" => "learning.md",
        "Measured results" => "results.md",
        "Development and validation" => "development.md",
        "Migration from SoleLogics" => "compatibility.md",
        "API reference" => "api.md",
        "References" => "references.md",
    ],
    format = Documenter.HTML(size_threshold = 300 * 1024, size_threshold_warn = 300 * 1024),
    plugins = [bibliography],
)

deploydocs(
    repo = "github.com/eduardstan/Aletheia.jl.git",
    devbranch = "main",
)
