using Aletheia

pool = FormulaPool(Signature((¬, ∧, Diamond(:R))))
formula = branch(pool, Diamond(:R), atom(pool, "p"))

shared = Frame((:w₁, :w₂), Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [:w₂])); index=true)
family = ModelFamily([
    Model(shared, BOOLEAN, Dict("p" => Set([:w₂]))),
    Model(shared, BOOLEAN, Dict("p" => Set{Symbol}())),
])

println("instances: ", instance_count(family))
println("handles: ", collect(eachinstance(family)))
println("uniform: ", isuniform(family))
println("shared frame: ", uniform_frame(family) === shared)
println("extensions:")
for (i, result) in enumerate(extension(formula, family))
    print("  instance $i: ")
    println(join(result, ", "))
end
println("check instance 1 at :w₁: ", check(formula, family, 1, :w₁))
# BEGIN EXPECTED OUTPUT
# instances: 2
# handles: [1, 2]
# uniform: true
# shared frame: true
# extensions:
#   instance 1: true, true
#   instance 2: false, false
# check instance 1 at :w₁: true
#
# END EXPECTED OUTPUT
