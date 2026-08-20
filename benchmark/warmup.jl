# One-operation preflight used by run.jl's wall-clock guard.  Do not remove the
# process boundary: Julia tasks cannot preempt a non-yielding incumbent call.
include(joinpath(@__DIR__, "common.jl"))
kind, side, argument = ARGS
parts = split(argument, ':')

function selected(f_inc, f_a)
    side == "incumbent" ? f_inc : f_a
end
function timed(f)
    start = time_ns()
    f()
    println((time_ns() - start) / 1_000_000)
end
function timed_pair(f)
    start = time_ns()
    f()
    middle = time_ns()
    f()
    finish = time_ns()
    println((middle - start) / 1_000_000, " ", (finish - middle) / 1_000_000)
end

if kind == "construction"
    label, depth_text = parts
    depth = parse(Int, depth_text)
    r = label == "shared" ? shared(depth) : unshared(depth)
    timed(selected(() -> build_s(r), () -> build_a(r, pool_a())))
elseif kind in ("parsing", "printing", "roundtrip")
    depth = parse(Int, argument)
    r = unshared(depth)
    pa = build_a(r, pool_a()); ps = build_s(r); text = Aletheia.syntaxstring(pa)
    if kind == "parsing"
        timed(selected(() -> SoleLogics.parseformula(SoleLogics.SyntaxTree, text),
            () -> Aletheia.parse(pool_a(), text)))
    elseif kind == "printing"
        timed(selected(() -> SoleLogics.syntaxstring(ps), () -> Aletheia.syntaxstring(pa)))
    else
        timed(selected(() -> SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, text)),
            () -> Aletheia.syntaxstring(Aletheia.parse(pool_a(), text))))
    end
elseif kind == "interval"
    n = parse(Int, argument)
    af = Aletheia.interval_frame(n)
    aw = first(Aletheia.worlds(af))
    sf = SoleLogics.FullDimensionalFrame((n,), SoleLogics.Interval{Int})
    sw = first(SoleLogics.allworlds(sf))
    timed(selected(() -> collect(SoleLogics.accessibles(sf, sw, SoleLogics.IA_L)),
        () -> collect(Aletheia.accessible(af, aw, Aletheia.BEFORE))))
elseif kind in ("equality", "equality_eq")
    n = parse(Int, argument)
    r = chain(n)
    if side == "incumbent"
        s = build_s(r); t = build_s(r)
        kind == "equality" ? timed(() -> isequal(s, t)) : timed_pair(() -> s == t)
    else
        ap = pool_a(); a = build_a(r, ap); b = build_a(r, ap)
        kind == "equality" ? timed(() -> isequal(a, b)) : timed_pair(() -> a == b)
    end
else
    error("unknown warm-up case: $kind")
end
