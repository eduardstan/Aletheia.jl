using BenchmarkTools
using Printf
using Random
using Statistics
using Aletheia
using SoleLogics

const DEEP = "--deep" in ARGS
const SEED = 0xA1E7_2024
const BENCH_SECONDS = DEEP ? 0.05 : 0.01
const BENCH_SAMPLES = DEEP ? 15 : 5
const CASE_TIMEOUT = DEEP ? 180 : 120
const SIGNATURE = Aletheia.Signature((Aletheia.NEGATION, Aletheia.CONJUNCTION,
    Aletheia.DISJUNCTION, Aletheia.IMPLICATION))
const MODAL_SIGNATURE = Aletheia.Signature((Aletheia.NEGATION, Aletheia.CONJUNCTION,
    Aletheia.DISJUNCTION, Aletheia.IMPLICATION, Aletheia.Diamond(:R), Aletheia.Box(:R)))
const MV_SIGNATURE = Aletheia.Signature((Aletheia.CONJUNCTION, Aletheia.DISJUNCTION,
    Aletheia.IMPLICATION))
const AOPS = Dict(:not => Aletheia.NEGATION, :and => Aletheia.CONJUNCTION,
    :or => Aletheia.DISJUNCTION, :implies => Aletheia.IMPLICATION,
    :diamond => Aletheia.Diamond(:R), :box => Aletheia.Box(:R))
const SOPS = Dict(:not => SoleLogics.:(¬), :and => SoleLogics.:(∧),
    :or => SoleLogics.:(∨), :implies => SoleLogics.:(→),
    :diamond => SoleLogics.◊, :box => SoleLogics.□)

struct Recipe
    op::Symbol
    children::Tuple
    atom::Union{Nothing,String}
end
atomrecipe(name) = Recipe(:atom, (), String(name))
recipe(op, children...) = Recipe(op, children, nothing)

function unshared(depth, counter = Ref(0))
    depth == 0 && begin
        counter[] += 1
        return atomrecipe("p$(1 + mod(counter[] - 1, 8))")
    end
    recipe(:and, unshared(depth - 1, counter), unshared(depth - 1, counter))
end
function shared(depth)
    depth == 0 && return atomrecipe("p")
    child = shared(depth - 1)
    recipe(:and, child, child)
end
function chain(n)
    result = atomrecipe("p")
    for _ in 1:n
        result = recipe(:not, result)
    end
    result
end
function modal_formula(depth)
    depth == 0 && return atomrecipe("p")
    choice = mod(depth, 4)
    choice == 0 && return recipe(:diamond, modal_formula(depth - 1))
    choice == 1 && return recipe(:box, modal_formula(depth - 1))
    choice == 2 && return recipe(:and, modal_formula(depth - 1), atomrecipe("q"))
    recipe(:or, modal_formula(depth - 1), atomrecipe("p"))
end
function random_recipe(rng, depth, counter=Ref(0); modal=true)
    if depth == 0 || rand(rng) < 0.22
        counter[] += 1
        return atomrecipe("p$(1 + mod(counter[] - 1, 6))")
    end
    if modal && rand(rng) < 0.30
        return recipe(rand(rng, (:diamond, :box)), random_recipe(rng, depth - 1, counter; modal=modal))
    end
    op = rand(rng, (:not, :and, :or, :implies))
    op === :not ? recipe(op, random_recipe(rng, depth - 1, counter; modal=modal)) :
        recipe(op, random_recipe(rng, depth - 1, counter; modal=modal),
            random_recipe(rng, depth - 1, counter; modal=modal))
end

function build_a(r::Recipe, pool)
    r.op === :atom && return Aletheia.atom(pool, r.atom)
    Aletheia.branch(pool, AOPS[r.op], (build_a(c, pool) for c in r.children)...)
end
function build_s(r::Recipe)
    r.op === :atom && return SoleLogics.Atom(r.atom)
    SoleLogics.SyntaxBranch(SOPS[r.op], (build_s(c) for c in r.children)...)
end
pool_a() = Aletheia.FormulaPool(SIGNATURE)
modal_pool_a() = Aletheia.FormulaPool(MODAL_SIGNATURE)
mv_pool_a() = Aletheia.FormulaPool(MV_SIGNATURE)

# Canonical structure is used only by the differential correctness command.
canonical(f::Aletheia.Atom) = (:atom, Aletheia.value(f))
canonical(f::Aletheia.Branch) = (:branch, Aletheia.notation(Aletheia.operator(f)), canonical.(Aletheia.children(f)))
canonical(f::SoleLogics.Atom) = (:atom, SoleLogics.value(f))
canonical(f::SoleLogics.SyntaxBranch) = (:branch, SoleLogics.syntaxstring(SoleLogics.token(f)), canonical.(SoleLogics.children(f)))

struct Measurement
    time::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
    note::String
end
Measurement(time, allocs, memory) = Measurement(time, allocs, memory, "")

# A call is measured in a child Julia process.  Unlike BenchmarkTools' seconds
# sampling budget, GNU timeout kills a non-yielding call at CASE_TIMEOUT.
function guarded_measure(label, kind, side, argument, f=nothing; timeout=CASE_TIMEOUT)
    println("[case] ", label)
    flush(stdout)
    project = @__DIR__
    julia = Base.julia_cmd()
    helper = joinpath(@__DIR__, "warmup.jl")
    command = `timeout -k 1s $(timeout)s $julia --startup-file=no --project=$project $helper benchmark $kind $side $argument`
    path, io = mktemp(); close(io)
    process = run(pipeline(command, stdout=path, stderr=devnull); wait=false)
    wait(process)
    output = read(path, String); rm(path; force=true)
    process.exitcode == 124 && return Measurement(missing, missing, missing, "timeout ($(timeout)s)")
    process.exitcode == 137 && return Measurement(missing, missing, missing, "timeout ($(timeout)s; killed)")
    process.exitcode != 0 && return Measurement(missing, missing, missing, "unavailable (exit code $(process.exitcode))")
    values = try parse.(Float64, split(strip(output))) catch; Float64[] end
    length(values) == 3 || return Measurement(missing, missing, missing, "unavailable (invalid measurement)")
    Measurement(values[1], Int(round(values[2])), Int(round(values[3])))
end
# One warmed child handles a complete suite section. The process boundary
# remains the hard wall-clock kill switch while package loading is amortized.
function section_measure(label, cases, side; timeout=CASE_TIMEOUT)
    println("[section] ", label, " / ", side); flush(stdout)
    project = @__DIR__; julia = Base.julia_cmd(); helper = joinpath(@__DIR__, "warmup.jl")
    encoded = join((string(kind, "=", argument) for (kind, argument) in cases), ";")
    command = `timeout -k 1s $(timeout)s $julia --startup-file=no --project=$project $helper section $side $encoded`
    path, io = mktemp(); close(io)
    process = run(pipeline(command, stdout=path, stderr=devnull); wait=false)
    wait(process)
    output = read(path, String); rm(path; force=true)
    lines = [split(strip(line)) for line in split(output, '\n') if !isempty(strip(line))]
    if process.exitcode == 124 || process.exitcode == 137
        return [Measurement(missing, missing, missing, "section timeout ($(timeout)s)") for _ in cases]
    end
    result = Measurement[]
    for line in lines
        length(line) == 3 || continue
        parsed = try parse.(Float64, line) catch; nothing end
        if parsed === nothing
            push!(result, Measurement(missing, missing, missing, "invalid measurement"))
        else
            push!(result, Measurement(parsed[1], Int(round(parsed[2])), Int(round(parsed[3]))))
        end
    end
    while length(result) < length(cases)
        push!(result, Measurement(missing, missing, missing, "section unavailable (exit code $(process.exitcode))"))
    end
    result[1:length(cases)]
end

function measure(f; seconds=BENCH_SECONDS, samples=BENCH_SAMPLES)
    trial = run(@benchmarkable $f() seconds=seconds samples=samples evals=1)
    m = median(trial)
    Measurement(Float64(m.time), Int(m.allocs), Int(m.memory))
end
function fmt_time(x)
    x === missing && return "empty"
    x < 1_000 ? @sprintf("%.1f ns", x) : x < 1_000_000 ? @sprintf("%.2f μs", x / 1_000) : @sprintf("%.2f ms", x / 1_000_000)
end
function fmt_measure(m)
    m.time === missing ? m.note : isempty(m.note) ? fmt_time(m.time) : "$(fmt_time(m.time)) [$(m.note)]"
end
fmt_alloc(m::Measurement) = m.allocs === missing ? "—" : "$(m.allocs) / $(Base.format_bytes(m.memory))"

const rows = NamedTuple[]
function addrow!(suite, inc, ale; allocations=true, note="")
    ratio = inc.time === missing || ale.time === missing ? missing : inc.time / ale.time
    push!(rows, (suite=suite, incumbent=inc, aletheia=ale, ratio=ratio, allocations=allocations, note=note))
end
function print_report()
    println("suite | SoleLogics median | Aletheia median | ratio (S/A) | allocations (Sole/Aletheia) | note")
    println("------|--------------------|-----------------|--------------|--------------------------|-----")
    for row in rows
        if row.incumbent.time === missing
            println("$(row.suite) | unsupported/$(fmt_measure(row.incumbent)) | $(fmt_measure(row.aletheia)) | — | — | $(row.note)")
        else
            inc, ale = row.incumbent, row.aletheia
            alloc = row.allocations ? "$(fmt_alloc(inc))/$(fmt_alloc(ale))" : "—/—"
            println("$(row.suite) | $(fmt_measure(inc)) | $(fmt_measure(ale)) | $(row.ratio === missing ? "—" : @sprintf("%.2fx", row.ratio)) | $alloc | $(row.note)")
        end
    end
end

# Shared deterministic finite-model builders used by both the timed child and
# the differential/correctness commands.
function edge_data(n, density, seed)
    rng = MersenneTwister(seed)
    [(i, j) for i in 1:n for j in 1:n if rand(rng) < density]
end
function a_boolean_model(n, edges; sets=nothing)
    worlds_a = Tuple(1:n)
    adjacency = Dict(w => Int[] for w in worlds_a)
    for (i, j) in edges; push!(adjacency[i], j); end
    frame = Aletheia.Frame(worlds_a, Dict(:R => adjacency); index=true)
    sets === nothing && (sets = Dict("p" => Set(w for w in worlds_a if isodd(w)),
        "q" => Set(w for w in worlds_a if mod(w, 3) == 0)))
    Aletheia.Model(frame, Aletheia.BOOLEAN, sets)
end
function s_boolean_model(n, edges; sets=nothing)
    worlds_s = SoleLogics.World.(1:n)
    graph = SoleLogics.Graphs.SimpleDiGraph(n)
    for (i, j) in edges; SoleLogics.Graphs.add_edge!(graph, i, j); end
    frame = SoleLogics.SimpleModalFrame(worlds_s, graph)
    sets === nothing && (sets = Dict("p" => Set(w for w in 1:n if isodd(w)),
        "q" => Set(w for w in 1:n if mod(w, 3) == 0)))
    atom_names = collect(keys(sets))
    assignment = Dict(w => SoleLogics.TruthDict(Dict(atom => (w.name in sets[atom]) for atom in atom_names)) for w in worlds_s)
    SoleLogics.KripkeStructure(frame, assignment)
end

function interval_adjacency_a(frame, relation_name, frame_worlds)
    positions = Aletheia.world_index(frame)
    positions === nothing && (positions = Dict(world => position for (position, world) in enumerate(frame_worlds)))
    Aletheia._relation_adjacency(frame, relation_name, positions)
end
function interval_adjacency_s(frame, frame_worlds)
    world_count = length(frame_worlds)
    rows = Vector{Vector{Int}}(undef, world_count)
    columns = [falses(world_count) for _ in 1:world_count]
    for (source_position, source) in enumerate(frame_worlds)
        targets = Int[]
        for target in SoleLogics.accessibles(frame, source, SoleLogics.IA_L)
            target_position = findfirst(==(target), frame_worlds)
            push!(targets, target_position); columns[target_position][source_position] = true
        end
        rows[source_position] = targets
    end
    rows, columns
end

function interval_subset_a(frame, relation_set, frame_worlds)
    sum(length(collect(Aletheia.accessible(frame, source, relation)))
        for relation in relation_set for source in frame_worlds)
end
function interval_subset_s(frame, relation_set, frame_worlds)
    sum(length(collect(SoleLogics.accessibles(frame, source, relation)))
        for relation in relation_set for source in frame_worlds)
end
function interval_check_a_setup(n)
    frame = Aletheia.interval_frame(n)
    frame_worlds = collect(Aletheia.worlds(frame))
    pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.Diamond(Aletheia.BEFORE),)))
    p = Aletheia.atom(pool, "p")
    formula = Aletheia.branch(pool, Aletheia.Diamond(Aletheia.BEFORE), p)
    valuation = Dict("p" => Set(frame_worlds))
    frame, frame_worlds, formula, valuation
end
function interval_check_s_setup(n)
    frame = SoleLogics.FullDimensionalFrame((n,), SoleLogics.Interval{Int})
    frame_worlds = collect(SoleLogics.allworlds(frame))
    p = SoleLogics.Atom("p")
    formula = SoleLogics.SyntaxBranch(SoleLogics.DiamondRelationalConnective(SoleLogics.IA_L), p)
    valuation = Dict(world => SoleLogics.TruthDict([p => true]) for world in frame_worlds)
    frame, frame_worlds, formula, valuation
end

# Finite FLew comparison. Both packages expose finite truth tables; the
# benchmark uses the designated-value check endpoint for a comparable question.
function finite_truth(index)
    SoleLogics.ManyValuedLogics.FiniteTruth(index)
end
finite_truth_value(index) = UInt8(index)
function mv_setup(side, algebra_name, depth)
    r = unshared(depth)
    algebra_name in ("godel", "lukasiewicz", "h4") || error("unknown finite algebra $algebra_name")
    if side == "aletheia"
        pool = mv_pool_a(); f = build_a(r, pool)
        algebra = algebra_name == "godel" ? Aletheia.G3 : algebra_name == "lukasiewicz" ? Aletheia.Ł3 : Aletheia.H4
        n = algebra_name == "h4" ? 4 : 3
        values = Dict(("p$(i)", 1) => finite_truth_value(1 + mod(i, n)) for i in 1:8)
        return f, Aletheia.Model(Aletheia.Frame((1,); index=true), algebra, values), algebra
    end
    f = build_s(r); n = algebra_name == "h4" ? 4 : 3
    values = Dict("p$(i)" => finite_truth(1 + mod(i, n)) for i in 1:8)
    alg = algebra_name == "godel" ? SoleLogics.ManyValuedLogics.G3 : algebra_name == "lukasiewicz" ? SoleLogics.ManyValuedLogics.Ł3 : SoleLogics.ManyValuedLogics.H4
    f, SoleLogics.TruthDict(values), alg
end

# ILP's interpretation-example bridge is intentionally in this benchmark:
# scoring a hypothesis set is a loop of eval/check over many interpretations.
function score_a(hypotheses, examples)
    sum(Aletheia.check(h, example.interpretation, 1) == example.positive for h in hypotheses for example in examples)
end
function score_s(hypotheses, examples)
    sum(SoleLogics.check(h, example[1], example[2]; perform_normalization=false) == example[3]
        for h in hypotheses for example in examples)
end

# Quotient models span q/n from high collapse to no collapse.  Binary labels
# distinguish q classes; each class has identical successors to every world.
function contraction_model(n, q)
    atoms = ["p$(i)" for i in 1:max(1, ceil(Int, log2(max(q, 2))))]
    labels = Dict(atom => Set(w for w in 1:n if ((div(w - 1, max(1, n ÷ q)) >> (i - 1)) & 1) == 1)
                   for (i, atom) in enumerate(atoms))
    adjacency = Dict(w => collect(1:n) for w in 1:n)
    model = Aletheia.Model(Aletheia.Frame(Tuple(1:n), Dict(:R => adjacency); index=true),
        Aletheia.BOOLEAN, labels)
    model, atoms
end
function contraction_formulas(pool, atoms, count)
    p = Aletheia.atom(pool, first(atoms))
    q = length(atoms) > 1 ? Aletheia.atom(pool, atoms[2]) : p
    formulas = Aletheia.Formula[p, Aletheia.branch(pool, Aletheia.Box(:R), p),
        Aletheia.branch(pool, Aletheia.Diamond(:R), q)]
    while length(formulas) < count
        i = length(formulas)
        push!(formulas, isodd(i) ? Aletheia.branch(pool, Aletheia.Box(:R), formulas[end]) :
            Aletheia.branch(pool, Aletheia.Diamond(:R), formulas[end]))
    end
    formulas
end

function parse_ratio_measurements(measurements)
    valid = filter(m -> m.time !== missing, measurements)
    isempty(valid) && return Measurement(missing, missing, missing, "all cases unavailable")
    Measurement(median(getfield.(valid, :time)), round(Int, median(getfield.(valid, :allocs))),
        round(Int, median(getfield.(valid, :memory))))
end

function external_measure(code; reps=DEEP ? 2 : 1)
    project = @__DIR__; julia = Base.julia_cmd(); values = Tuple{Float64,Float64}[]
    for _ in 1:reps
        command = `timeout -k 1s $(CASE_TIMEOUT)s $julia --startup-file=no --project=$project -e $code`
        path, io = mktemp(); close(io)
        process = run(pipeline(ignorestatus(command), stdout=path, stderr=devnull); wait=true)
        wait(process)
        output = read(path, String); rm(path; force=true)
        process.exitcode == 0 || return nothing
        parts = split(strip(output)); length(parts) >= 2 || return nothing
        parsed = try (parse(Float64, parts[1]), parse(Float64, parts[2])) catch; return nothing end
        push!(values, parsed)
    end
    isempty(values) ? nothing : (median(first.(values)), median(last.(values)))
end
