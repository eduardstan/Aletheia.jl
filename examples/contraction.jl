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
println("Bisimulation quotient:")
show(stdout, MIME"text/plain"(), quotient)
println()
println("Original extension:")
show(stdout, MIME"text/plain"(), describe(extension(formula, model), model))
println()
println("Quotient extension:")
show(stdout, MIME"text/plain"(), describe(extension(formula, quotient), Aletheia.model(quotient)))
println()
preserved = all(check(formula, model, world) == check(formula, quotient, world)
    for world in worlds(base_frame))
println("values preserved through world map: ", preserved)
