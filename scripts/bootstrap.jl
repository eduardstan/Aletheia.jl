# Prepare local focused-package paths for all supported Julia versions.
using Pkg

const REPO = normpath(joinpath(@__DIR__, ".."))
const PACKAGES = (
    "AletheiaCore",
    "AletheiaData",
    "AletheiaLearn",
    "AletheiaSole",
    "AletheiaCircuits",
    "AletheiaGraphs",
    "AletheiaAudit",
    "AletheiaNeSy",
)
const DEPENDENCIES = Dict(
    "AletheiaCore" => (),
    "AletheiaData" => ("AletheiaCore",),
    "AletheiaLearn" => ("AletheiaCore",),
    "AletheiaSole" => ("AletheiaCore", "AletheiaData"),
    "AletheiaCircuits" => ("AletheiaCore",),
    "AletheiaGraphs" => ("AletheiaCore",),
    "AletheiaAudit" => ("AletheiaCore",),
    "AletheiaNeSy" => ("AletheiaCore", "AletheiaData", "AletheiaAudit"),
)

if VERSION < v"1.11"
    # Julia 1.10 does not honor the local [sources] entries when preparing
    # environments. Explicitly develop each local dependency instead.
    for package in PACKAGES
        Pkg.activate(joinpath(REPO, "lib", package))
        specs = [
            Pkg.PackageSpec(; path=joinpath(REPO, "lib", dependency)) for
            dependency in DEPENDENCIES[package]
        ]
        isempty(specs) || Pkg.develop(specs)
    end

    Pkg.activate(REPO)
    Pkg.develop([
        Pkg.PackageSpec(; path=joinpath(REPO, "lib", package)) for package in PACKAGES
    ])
else
    # Modern Pkg resolves the relative [sources] entries without rewriting
    # the tracked project files.
    for project in (REPO, (joinpath(REPO, "lib", package) for package in PACKAGES)...)
        Pkg.activate(project)
        # Resolve first so a fresh checkout can add local [sources] entries
        # without requiring a generated manifest in version control.
        Pkg.resolve()
        Pkg.instantiate()
    end
end
