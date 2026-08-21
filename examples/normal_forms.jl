using Aletheia

signature = Signature((¬, ∧, ∨))
pool = FormulaPool(signature)
p, q, r, s, t = (atom(pool, x) for x in ("p", "q", "r", "s", "t"))
formula = branch(pool, ∧, branch(pool, ∨, p, q),
    branch(pool, ∨, r, branch(pool, ∧, s, t)))
cnf, dnf = to_cnf(formula), to_dnf(formula)
println("formula: ", syntaxstring(formula))
println("CNF: ", syntaxstring(cnf), " (", iscnf(cnf), ")")
println("DNF: ", syntaxstring(dnf), " (", isdnf(dnf), ")")

base_frame = Frame((:a, :b, :c, :d), Dict(); index=true)
model = Model(base_frame, BOOLEAN, Dict("p" => Set([:a, :d]), "q" => Set([:b]),
    "r" => Set([:b]), "s" => Set([:a, :d]), "t" => Set([:a])))
println("extensions agree: ", extension(formula, model) == extension(cnf, model) == extension(dnf, model))
println("Demonstrated: classical CNF/DNF conversion, shape checks, and semantic preservation.")
