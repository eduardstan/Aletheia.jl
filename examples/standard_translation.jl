using Aletheia

signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
formula = branch(pool, Diamond(:R), p)
base_frame = Frame((1, 2), Dict(:R => Dict(1 => [2], 2 => [2])); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([2])))
translation = standard_translation(formula)
first_order = first_order_interpretation(model)

show(stdout, MIME"text/plain"(), model)
println()
modal_value = check(formula, model, 1)
translated_value = evaluate(translation, first_order, Dict(:x => 1))
println("modal formula: ", syntaxstring(formula))
println("standard translation: ", translation)
println("direct / translated at world 1: ", modal_value, " / ", translated_value)
println("agree: ", modal_value == translated_value)
# BEGIN EXPECTED OUTPUT
# Model (2 worlds, 1 relation, Aletheia.BooleanAlgebra())
#   Worlds (2): 1, 2
#   Relations:
#     :R: 1 → 2; 2 → 2
#   Valuation:
#     p: {2}
# modal formula: ⟨R⟩p
# standard translation: ∃x_1. R(x, x_1) ∧ p(x_1)
# direct / translated at world 1: true / true
# agree: true
#
# END EXPECTED OUTPUT
