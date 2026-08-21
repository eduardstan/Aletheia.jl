using BenchmarkTools
using Random
using Statistics
using Aletheia
using SoleData
using SoleLogics
using Graphs

include(joinpath(@__DIR__, "dataset_protocol_adapter.jl"))

const DATASET_SEED = 0xDADA_2024

struct DRecipe
    op::Symbol
    children::Tuple
    condition::Any
end

atomrecipe(condition) = DRecipe(:atom, (), condition)
recipe(op, children...) = DRecipe(op, children, nothing)

function make_dataset(ninstances, nworlds; uniform=false)
    rng = MersenneTwister(DATASET_SEED + ninstances * 1009 + nworlds * 9176 + (uniform ? 1 : 0))
    features = SoleData.Feature.("f" .* string.(1:6))
    W = typeof(SoleLogics.World(1))
    F = typeof(features[1])
    rows = nothing
    shared_edges = [(i, j) for i in 1:nworlds for j in 1:nworlds if rand(rng) < 0.30]
    for i_instance in 1:ninstances
        worlds = SoleLogics.World.(1:nworlds)
        graph = Graphs.SimpleDiGraph(nworlds)
        edges = uniform ? shared_edges :
            [(i, j) for i in 1:nworlds for j in 1:nworlds if rand(rng) < 0.30]
        for edge in edges
            Graphs.add_edge!(graph, edge[1], edge[2])
        end
        values = Dict{W,Dict{F,Float64}}()
        for world in worlds
            values[world] = Dict{F,Float64}(feature => rand(rng) for feature in features)
        end
        row = (values, SoleLogics.SimpleModalFrame(worlds, graph))
        rows = rows === nothing ? [row] : push!(rows, row)
    end
    SoleData.ExplicitModalLogiset(rows)
end

function make_conditions(rng)
    features = SoleData.Feature.("f" .* string.(1:6))
    operators = (>, <, >=, <=)
    [
        SoleData.ScalarCondition(
            features[1 + mod(i - 1, length(features))],
            operators[1 + mod(i - 1, length(operators))],
            rand(rng),
        ) for i in 1:12
    ]
end

function random_recipe(rng, depth, modal_probability, conditions)
    if depth == 0 || rand(rng) < 0.20
        return atomrecipe(rand(rng, conditions))
    end
    if rand(rng) < modal_probability
        return recipe(rand(rng, (:diamond, :box)),
            random_recipe(rng, depth - 1, modal_probability, conditions))
    end
    op = rand(rng, (:not, :and, :or, :implies))
    op === :not ? recipe(op, random_recipe(rng, depth - 1, modal_probability, conditions)) :
        recipe(op, random_recipe(rng, depth - 1, modal_probability, conditions),
            random_recipe(rng, depth - 1, modal_probability, conditions))
end

const AOPS = Dict(:not => Aletheia.NEGATION, :and => Aletheia.CONJUNCTION,
    :or => Aletheia.DISJUNCTION, :implies => Aletheia.IMPLICATION,
    :diamond => Aletheia.Diamond(:R), :box => Aletheia.Box(:R))
const SOPS = Dict(:not => SoleLogics.:(¬), :and => SoleLogics.:(∧),
    :or => SoleLogics.:(∨), :implies => SoleLogics.:(→),
    :diamond => SoleLogics.◊, :box => SoleLogics.□)

function build_a(recipe, pool)
    recipe.op === :atom && return Aletheia.atom(pool, recipe.condition)
    Aletheia.branch(pool, AOPS[recipe.op], (build_a(child, pool) for child in recipe.children)...)
end

function build_s(recipe)
    recipe.op === :atom && return SoleLogics.Atom(recipe.condition)
    SoleLogics.SyntaxBranch(SOPS[recipe.op], (build_s(child) for child in recipe.children)...)
end

function make_pair(depth, modal_probability, seed)
    rng = MersenneTwister(seed)
    conditions = make_conditions(rng)
    recipe = random_recipe(rng, depth, modal_probability, conditions)
    pool = Aletheia.FormulaPool(Aletheia.Signature((Aletheia.NEGATION,
        Aletheia.CONJUNCTION, Aletheia.DISJUNCTION, Aletheia.IMPLICATION,
        Aletheia.Diamond(:R), Aletheia.Box(:R))))
    build_a(recipe, pool), build_s(recipe)
end

function parse_case(argument)
    fields = split(argument, ':')
    length(fields) == 5 || error("case must be ninstances:nworlds:depth:modal:uniform")
    (parse(Int, fields[1]), parse(Int, fields[2]), parse(Int, fields[3]),
        parse(Float64, fields[4]), parse(Int, fields[5]) == 1)
end

function measure(f)
    trial = run(@benchmarkable $f() seconds=0.01 samples=5 evals=1)
    m = median(trial)
    println(Float64(m.time), " ", m.allocs, " ", m.memory)
end
