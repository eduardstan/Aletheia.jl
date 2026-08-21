using Coverage
using Printf

root = normpath(joinpath(@__DIR__, ".."))
files = process_folder(joinpath(root, "src"))
# The package entrypoint is a module/export manifest; Julia's package test
# subprocess does not emit a coverage file for it, so count executable source
# files rather than treating that manifest as entirely uncovered.
files = filter(file -> !endswith(file.filename, joinpath("src", "Aletheia.jl")), files)
covered, total = get_summary(files)
percentage = total == 0 ? 0.0 : 100 * covered / total
@printf("Line coverage: %d/%d (%.2f%%)\n", covered, total, percentage)
percentage >= 95.0 || error("line coverage $(round(percentage; digits=2))%% is below the required 95%%")
