using Pkg
Pkg.activate(@__DIR__)
repo = dirname(@__DIR__)
packages = (
    "AletheiaCore",
    "AletheiaData",
    "AletheiaCircuits",
    "AletheiaGraphs",
    "AletheiaLearn",
    "AletheiaSole",
    "AletheiaAudit",
    "AletheiaNeSy",
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
import AletheiaCore, AletheiaData, AletheiaCircuits, AletheiaGraphs, AletheiaLearn, AletheiaSole, AletheiaAudit, AletheiaNeSy
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
        AletheiaAudit,
        AletheiaNeSy,
        Aletheia.SoleLogics,
    ],
    pages = [
        "Overview" => "index.md",
        "One engine, many readings" => "engine.md",
        "Quick start" => "quickstart.md",
        "One-dataset showcase" => "showcase.md",
        "Packages" => [
            "AletheiaCore" => [
                "Syntax and design" => "design.md",
                "Semantics and evaluation" => "semantics.md",
                "Relations, frames, and frame classes" => "relations.md",
                "Finite FLew-algebras" => "algebras.md",
                "Theory utilities" => "theory.md",
            ],
            "AletheiaData" => [
                "Many models, one formula" => "families.md",
                "Scalar data" => "scalar.md",
            ],
            "AletheiaCircuits" => "circuits.md",
            "AletheiaGraphs" => "graphs.md",
            "AletheiaLearn" => "learning.md",
            "AletheiaSole" => "sole.md",
            "AletheiaAudit" => "audit.md",
            "AletheiaNeSy" => "nesy.md",
        ],
        "API reference" => "api.md",
        "Measured results" => "results.md",
        "Coming from SoleLogics" => "compatibility.md",
        "Design decisions" => "design-decisions.md",
        "Development and validation" => "development.md",
        "References" => "references.md",
    ],
    format = Documenter.HTML(size_threshold = 500 * 1024, size_threshold_warn = 400 * 1024),
    plugins = [bibliography],
)

deploydocs(
    repo = "github.com/eduardstan/Aletheia.jl.git",
    devbranch = "main",
)
