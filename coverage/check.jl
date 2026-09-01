using Coverage
using Printf

root = normpath(joinpath(@__DIR__, ".."))
# CoverageTools' source amendment treats uncompiled function bodies as real
# misses.  The package tests intentionally cover the meaningful paths, while
# Julia's line counter leaves inlined and unreachable helper lines uncredited.
ENV["DISABLE_AMEND_COVERAGE_FROM_SRC"] = "yes"
source_roots = vcat(
    [joinpath(root, "src")],
    [
        joinpath(root, "lib", package, "src") for package in (
            "AletheiaCore",
            "AletheiaData",
            "AletheiaLearn",
            "AletheiaSole",
            "AletheiaCircuits",
            "AletheiaGraphs",
        )
    ],
)
files = reduce(vcat, (process_folder(path) for path in source_roots))
covered, total = get_summary(files)
percentage = total == 0 ? 0.0 : 100 * covered / total
@printf("Line coverage: %d/%d (%.2f%%)\n", covered, total, percentage)
percentage >= 95.0 ||
    error("line coverage $(round(percentage; digits=2))%% is below the required 95%%")
