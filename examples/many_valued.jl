using Aletheia

signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p, q = atom(pool, "p"), atom(pool, "q")
conjunction = branch(pool, ∧, p, q)
single_world = Frame((:w,), Dict(:R => Dict(:w => [])); index=true)

godel = Model(single_world, GodelAlgebra(), Dict("p" => 0.4, "q" => 0.8))
lukasiewicz = Model(single_world, LukasiewiczAlgebra(), Dict("p" => 0.4, "q" => 0.8))
println("p ∧ q under Gödel: ", check(conjunction, godel, :w))
println("p ∧ q under Łukasiewicz: ", check(conjunction, lukasiewicz, :w))

# Box and Diamond are primitive algebraic folds; they need not be Boolean duals.
boxp = branch(pool, Box(:R), p)
diamondp = branch(pool, Diamond(:R), p)
println("dead-end Gödel Box/Diamond: ", check(boxp, godel, :w), "/", check(diamondp, godel, :w))
println("Demonstrated: the same formula genuinely differs across Gödel and Łukasiewicz semantics.")
