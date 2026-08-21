using Aletheia

signature = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
pool = FormulaPool(signature)
p = atom(pool, "p")
separator = branch(pool, Diamond(:R), p)

one = Frame((:r,), Dict(:R => Dict(:r => [:r])); index=true)
two = Frame((:s, :t), Dict(:R => Dict(:s => [:t], :t => [:t])); index=true)
m₁ = Model(one, BOOLEAN, Dict("p" => Set{Symbol}()))
m₂ = Model(two, BOOLEAN, Dict("p" => Set{Symbol}()))
m₂_bad = Model(two, BOOLEAN, Dict("p" => Set([:t])))

println("unperturbed roots bisimilar: ", bisimilar(m₁, :r, m₂, :s))
println("separator: ", syntaxstring(separator))
println("unperturbed values: ", check(separator, m₁, :r), "/", check(separator, m₂, :s))
println("after labelling t=p: ", bisimilar(m₁, :r, m₂_bad, :s))
println("separating values: ", check(separator, m₁, :r), "/", check(separator, m₂_bad, :s))
println("Demonstrated: bisimulation preserves observations until ◇p separates relabelled roots.")
