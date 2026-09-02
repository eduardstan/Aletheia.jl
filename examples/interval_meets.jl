using Aletheia

# interval_frame(n) contains closed intervals (i, j) with 1 ≤ i < j ≤ n+1.
# Its MEETS edge goes from (i, j) to every (j, k), so the source/target
# convention is explicit: the target starts where the source ends.
intervals = interval_frame(3)
signature = Signature((Diamond(MEETS),))
pool = FormulaPool(signature)
p = atom(pool, "p")
formula = branch(pool, Diamond(MEETS), p)
target = Interval(2, 3)
model = Model(intervals, BOOLEAN, Dict("p" => Set([target])))

println("Interval frame:")
show(stdout, MIME"text/plain"(), intervals)
println()
println("Model with p at the target interval:")
show(stdout, MIME"text/plain"(), model)
println()
println("worlds: ", collect(worlds(intervals)))
println(
    "MEETS successors of (1,2): ", collect(accessible(intervals, Interval(1, 2), MEETS))
)
println("target valuation: ", target)
println("check ⟨MEETS⟩p at (1,2): ", check(formula, model, Interval(1, 2)))
println("relation predicate agrees: ", relation_holds(MEETS, Interval(1, 2), target))
# BEGIN EXPECTED OUTPUT
# Interval frame:
# Frame (6 worlds, relations supplied on demand)
#   Worlds (6): (1−2), (1−3), (1−4), (2−3), (2−4), (3−4)
#   Relations: <callable>
# Model with p at the target interval:
# Model (6 worlds, relations supplied on demand, BooleanAlgebra())
#   Worlds (6): (1−2), (1−3), (1−4), (2−3), (2−4), (3−4)
#   Relations: <callable>
#   Valuation:
#     p: {(2−3)}
# worlds: Interval{Int64}[(1−2), (1−3), (1−4), (2−3), (2−4), (3−4)]
# MEETS successors of (1,2): Interval{Int64}[(2−3), (2−4)]
# target valuation: (2−3)
# check ⟨MEETS⟩p at (1,2): true
# relation predicate agrees: true
#
# END EXPECTED OUTPUT
