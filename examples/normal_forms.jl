using Aletheia

signature = Signature((¬, ∧, ∨))
pool = FormulaPool(signature)
p, q, r, s, t = (atom(pool, x) for x in ("p", "q", "r", "s", "t"))
formula = branch(pool, ∧, branch(pool, ∨, p, q),
    branch(pool, ∨, r, branch(pool, ∧, s, t)))
cnf, dnf = to_cnf(formula), to_dnf(formula)
println("formula: ", syntaxstring(formula))
println("CNF: ", syntaxstring(cnf), " (iscnf: ", iscnf(cnf), ")")
println("DNF: ", syntaxstring(dnf), " (isdnf: ", isdnf(dnf), ")")

base_frame = Frame((:a, :b, :c, :d), Dict(); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([:a, :d]), "q" => Set([:b]),
    "r" => Set([:b]), "s" => Set([:a, :d]), "t" => Set([:a])))
show(stdout, MIME"text/plain"(), model)
println()
show(stdout, MIME"text/plain"(), describe(extension(formula, model), model))
println()
println("extensions agree: ", extension(formula, model) == extension(cnf, model) == extension(dnf, model))
# BEGIN EXPECTED OUTPUT
# formula: (p ∨ q) ∧ (r ∨ s ∧ t)
# CNF: (p ∨ q) ∧ (r ∨ s) ∧ (r ∨ t) (iscnf: true)
# DNF: p ∧ r ∨ p ∧ s ∧ t ∨ q ∧ r ∨ q ∧ s ∧ t (isdnf: true)
# Model (4 worlds, 0 relations, BooleanAlgebra())
#   Worlds (4): :a, :b, :c, :d
#   Valuation:
#     p: {:a, :d}
#     q: {:b}
#     r: {:b}
#     s: {:a, :d}
#     t: {:a}
# Extension (2 of 4 worlds satisfy)
#   Satisfied at: :a, :b
#   Unsatisfied at: :c, :d
# extensions agree: true
#
# END EXPECTED OUTPUT
