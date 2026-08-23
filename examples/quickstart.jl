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
