using Coverage
using Printf

root = normpath(joinpath(@__DIR__, ".."))
files = process_folder(joinpath(root, "src"))
covered, total = get_summary(files)
percentage = total == 0 ? 0.0 : 100 * covered / total
@printf("Line coverage: %d/%d (%.2f%%)\n", covered, total, percentage)
percentage >= 95.0 || error("line coverage $(round(percentage; digits=2))%% is below the required 95%%")
