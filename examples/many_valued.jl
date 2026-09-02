using Aletheia

signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p, q = atom(pool, "p"), atom(pool, "q")
conjunction = branch(pool, ∧, p, q)
single_world = Frame((:w,), Dict(:R => Dict(:w => [])); index=true)

godel = Model(
    single_world, GodelAlgebra(), Dict("p" => Dict(:w => 0.4), "q" => Dict(:w => 0.8))
)
lukasiewicz = Model(
    single_world, LukasiewiczAlgebra(), Dict("p" => Dict(:w => 0.4), "q" => Dict(:w => 0.8))
)
println("Gödel model:")
show(stdout, MIME"text/plain"(), godel)
println()
println("Łukasiewicz model:")
show(stdout, MIME"text/plain"(), lukasiewicz)
println()
println("p ∧ q under Gödel: ", check(conjunction, godel, :w))
println("p ∧ q under Łukasiewicz: ", check(conjunction, lukasiewicz, :w))

# Box and Diamond are primitive algebraic folds; they need not be Boolean duals.
boxp = branch(pool, Box(:R), p)
diamondp = branch(pool, Diamond(:R), p)
println(
    "dead-end Gödel Box/Diamond: ", check(boxp, godel, :w), "/", check(diamondp, godel, :w)
)
# BEGIN EXPECTED OUTPUT
# Gödel model:
# Model (1 world, 1 relation, GodelAlgebra (unit interval [0.0, 1.0]))
#   Worlds (1): :w
#   Relations:
#     :R: (none)
#   Valuation:
#     p: {:w => 0.4}
#     q: {:w => 0.8}
# Łukasiewicz model:
# Model (1 world, 1 relation, LukasiewiczAlgebra (unit interval [0.0, 1.0]))
#   Worlds (1): :w
#   Relations:
#     :R: (none)
#   Valuation:
#     p: {:w => 0.4}
#     q: {:w => 0.8}
# p ∧ q under Gödel: 0.4
# p ∧ q under Łukasiewicz: 0.4
# dead-end Gödel Box/Diamond: 1.0/0.0
#
# END EXPECTED OUTPUT
