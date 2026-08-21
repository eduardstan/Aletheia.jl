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
println("classes: ", classes(quotient))
original = [check(formula, model, w) for w in worlds(base_frame)]
via_quotient = [check(formula, quotient, w) for w in worlds(base_frame)]
println("original values: ", original)
println("quotient values via world map: ", via_quotient)
println("preserved: ", original == via_quotient)
println("Demonstrated: bisimulation contraction removes redundant worlds while preserving checks.")
