using Aletheia

signature = Signature((¬, ∧, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
q = atom(pool, "q")
formula = branch(pool, ∧, branch(pool, Diamond(:R), p), branch(pool, Box(:R), q))

println("formula: ", syntaxstring(formula))
parsed = parse(pool, "⟨R⟩p ∧ [R]q")
println("parse round-trip: ", parsed == formula)

base_frame = Frame((:w₁, :w₂),
    Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
model = Model(base_frame, BOOLEAN,
    Dict("p" => Set([:w₂]), "q" => Set([:w₁, :w₂])))
show(stdout, MIME"text/plain"(), model)
println()
println("successors of w₁: ", collect(accessible(base_frame, :w₁, :R)))
println("check at w₁: ", check(formula, model, :w₁))
show(stdout, MIME"text/plain"(), describe(extension(formula, model), model))
println()
# BEGIN EXPECTED OUTPUT
# formula: ⟨R⟩p ∧ [R]q
# parse round-trip: true
# Model (2 worlds, 1 relation, BooleanAlgebra())
#   Worlds (2): :w₁, :w₂
#   Relations:
#     :R: :w₁ → :w₂; :w₂ → :w₂
#   Valuation:
#     p: {:w₂}
#     q: {:w₁, :w₂}
# successors of w₁: [:w₂]
# check at w₁: true
# Extension (2 of 2 worlds satisfy)
#   Satisfied at: :w₁, :w₂
#   Unsatisfied at: (none)
#
# END EXPECTED OUTPUT
