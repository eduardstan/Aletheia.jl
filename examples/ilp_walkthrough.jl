using Aletheia

X = Variable(:X)
a = Constant(:a)
general = HornClause(Predicate(:father, X), Predicate(:parent, X))
specific = Clause(Predicate(:father, a), Literal(Predicate(:parent, a), false))
println("General and specific clauses:")
show(stdout, MIME"text/plain"(), ClauseSet([general, specific]))
println()
println("general subsumes specific: ", subsumes(general, specific))
println("reverse subsumption: ", subsumes(specific, general))

base = Clause(Predicate(:p, X))
refined = collect(downward_refinements(base; literals=[Predicate(:q, X)]))
println("One downward refinement:")
show(stdout, MIME"text/plain"(), ClauseSet(refined))
println()

base_frame = Frame((:w₁, :w₂), Dict(:R => Dict(:w₁ => [:w₂], :w₂ => [])); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([:w₁])))
example = learning_from_interpretations(model; positive=true)
println("Learning example:")
show(stdout, MIME"text/plain"(), example)
println()
println("accessible(w₁,R): ", collect(accessible(base_frame, :w₁, :R)))
# BEGIN EXPECTED OUTPUT
# General and specific clauses:
# ClauseSet (2 clauses)
#   father(X) :- parent(X)
#   father(a) :- parent(a)
# general subsumes specific: true
# reverse subsumption: false
# One downward refinement:
# ClauseSet (1 clause)
#   p(X) ∨ q(X)
# Learning example:
# InterpretationExample (+): Model(2 worlds, BooleanAlgebra())
# accessible(w₁,R): [:w₂]
#
# END EXPECTED OUTPUT
