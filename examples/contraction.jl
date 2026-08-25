using Aletheia

signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
formula = branch(pool, Diamond(:R), p)
base_frame = Frame((1, 2, 3),
    Dict(:R => Dict(1 => [1], 2 => [2], 3 => [3])); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([3])))
quotient = bisimulation_contraction(model)

println("world count: ", length(worlds(base_frame)), " -> ",
    length(worlds(frame(quotient))))
show(stdout, MIME"text/plain"(), quotient)
println()
show(stdout, MIME"text/plain"(), describe(extension(formula, model), model))
println()
show(stdout, MIME"text/plain"(), describe(extension(formula, quotient), Aletheia.model(quotient)))
println()
preserved = all(check(formula, model, world) == check(formula, quotient, world)
    for world in worlds(base_frame))
println("values preserved through world map: ", preserved)
# BEGIN EXPECTED OUTPUT
# world count: 3 -> 2
# BisimulationContraction (3 → 2 worlds, 33% collapse ratio)
#   Classes (2):
#     Class 1: 2, 1
#     Class 2: 3
# Extension (1 of 3 worlds satisfy)
#   Satisfied at: 3
#   Unsatisfied at: 1, 2
# Extension (1 of 2 worlds satisfy)
#   Satisfied at: Class(3)
#   Unsatisfied at: Class(2, 1)
# values preserved through world map: true
#
# END EXPECTED OUTPUT
