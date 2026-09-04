module AletheiaShowcase

using Random
using Aletheia

const SEED = 0x5EED_2025
const DATASET_PATH = joinpath(@__DIR__, "records.csv")
const FEATURES = (:hot, :dry, :cool)

"""Read the committed synthetic records without a tabular dependency."""
function read_records(path=DATASET_PATH)
    lines = [strip(line) for line in readlines(path) if !isempty(strip(line))]
    header = split(first(lines), ',')
    header == ["id", "hot", "dry", "cool", "target"] || error("unexpected dataset header")
    rows = NamedTuple[]
    for line in Iterators.drop(lines, 1)
        fields = split(line, ',')
        length(fields) == 5 || error("unexpected dataset row: $line")
        push!(
            rows,
            (
                id=Symbol(fields[1]),
                hot=parse(Int, fields[2]),
                dry=parse(Int, fields[3]),
                cool=parse(Int, fields[4]),
                target=Symbol(fields[5]),
            ),
        )
    end
    return rows
end

struct FixedNetwork
    weights::NTuple{3,Float64}
    bias::Float64
end

function (network::FixedNetwork)(x::NTuple{3,Float64})
    return sum(network.weights[i] * x[i] for i in 1:3) + network.bias > 0
end

row_values(row) = (row.hot / 100, row.dry / 100, row.cool / 100)

function finite_value(percent::Int)
    percent in (0, 25, 50, 75, 100) || error("finite showcase values must be quarter steps")
    # G5's public carrier is ordered as top, bottom, then its three middle values.
    return if percent == 100
        UInt8(1)
    elseif percent == 0
        UInt8(2)
    else
        UInt8(percent ÷ 25 + 2)
    end
end

function metric_line(name, metric)
    return "  $name: value=$(metric.value), population=$(metric.numerator)/$(metric.denominator), applicable=$(metric.applicable), scope=$(metric.scope)"
end

function run_showcase(; io=stdout)
    Random.seed!(SEED)
    rows = read_records()
    worlds_ = Tuple(row.id for row in rows)
    println(io, "one-dataset showcase (seed=0x5EED_2025)")
    println(io, "dataset: $(length(rows)) records; source=$(basename(DATASET_PATH))")

    # Materialise the same records through the scalar-data boundary.
    frame_ = Frame(worlds_, Dict(); index=true)
    values = Array{Float64}(undef, length(rows), 1, length(FEATURES))
    for (world_position, row) in enumerate(rows)
        values[world_position, 1, :] = collect(row_values(row))
    end
    store_ = DenseFeatureStore(
        values, collect(worlds_), collect(FEATURES); instances=[:dataset]
    )
    prepared = prepare_scalar(
        store_; features=FEATURES, frames=frame_, instances=[:dataset]
    )
    println(io, "prepared scalar store: ", size(store_), " (world × instance × feature)")

    # a. The familiar crisp decision-list reading.
    pool_ = FormulaPool(Signature((∧, ∨)))
    hot_condition = ThresholdCondition(:hot, >=, 75 / 100)
    dry_condition = ThresholdCondition(:dry, >=, 50 / 100)
    cool_condition = ThresholdCondition(:cool, >=, 50 / 100)
    hot = atom(pool_, hot_condition)
    dry = atom(pool_, dry_condition)
    cool = atom(pool_, cool_condition)
    alert_formula = branch(pool_, ∧, hot, dry)
    calm_formula = cool
    decision_list = ((alert_formula, :alert), (calm_formula, :calm))

    plain_valuation = Dict(
        hot_condition => Set(
            row.id for
            row in rows if scalar_check(hot_condition, prepared, :dataset, row.id)
        ),
        dry_condition => Set(
            row.id for
            row in rows if scalar_check(dry_condition, prepared, :dataset, row.id)
        ),
        cool_condition => Set(
            row.id for
            row in rows if scalar_check(cool_condition, prepared, :dataset, row.id)
        ),
    )
    plain_model = Model(frame_, BOOLEAN, plain_valuation)
    plain_extensions = [extension(formula, plain_model) for (formula, _) in decision_list]
    scalar_results = batch_apply([alert_formula, calm_formula], prepared)
    scalar_extensions = [scalar_results[1][1], scalar_results[2][1]]
    raw_extensions = [
        BitVector(check(formula, plain_model, world) for world in worlds_) for
        (formula, _) in decision_list
    ]
    @assert plain_extensions == raw_extensions "plain extension/check mismatch"
    @assert plain_extensions == scalar_extensions "plain evaluator/scalar evaluator mismatch"
    crisp_labels = Symbol[]
    for row in rows
        selected = :review
        for (formula, label) in decision_list
            check(formula, plain_model, row.id) && (selected = label; break)
        end
        push!(crisp_labels, selected)
    end
    @assert crisp_labels == [row.target for row in rows] "decision list labels mismatch"
    println(io, "a. crisp decision list: ", crisp_labels)
    println(io, "   formulas: [hot ∧ dry, cool]")
    println(io, "   extension/check cross-check: true; scalar-data cross-check: true")

    # b. Keep the same formulas and change only the truth algebra and valuation.
    algebra = G5
    graded_valuation = Dict(
        hot_condition => Dict(row.id => finite_value(row.hot) for row in rows),
        dry_condition => Dict(row.id => finite_value(row.dry) for row in rows),
        cool_condition => Dict(row.id => finite_value(row.cool) for row in rows),
    )
    graded_model = Model(frame_, algebra, graded_valuation)
    graded = [
        (
            row.id,
            Aletheia.truthlabel(
                algebra, check(alert_formula, graded_model, row.id)
            ),
            Aletheia.truthlabel(
                algebra, check(calm_formula, graded_model, row.id)
            ),
        ) for row in rows
    ]
    @assert extension(alert_formula, graded_model) ==
            [check(alert_formula, graded_model, world) for world in worlds_]
    @assert extension(calm_formula, graded_model) ==
            [check(calm_formula, graded_model, world) for world in worlds_]
    @assert isfinitechain(algebra) && algebra isa FiniteFLewAlgebra
    println(io, "b. G5 graded (alert, calm): ", graded)
    println(io, "   algebra cross-check: validated finite FLew chain = true")
    println(
        io,
        "   theory: finite many-valued conjunction uses the algebra meet [hajek1998; cignoli2000; galatos2007].",
    )

    # c. Distribution semantics is compiled separately from TruthAlgebra.
    programs = DSProgram[]
    for row in rows
        facts = [
            ProbabilisticFact(Symbol("hot_", row.id), row.hot//100),
            ProbabilisticFact(Symbol("dry_", row.id), row.dry//100),
            ProbabilisticFact(Symbol("cool_", row.id), row.cool//100),
        ]
        rules = [
            GroundRule(
                Symbol("alert_", row.id), (Symbol("hot_", row.id), Symbol("dry_", row.id))
            ),
            GroundRule(Symbol("calm_", row.id), Symbol("cool_", row.id)),
        ]
        push!(programs, DSProgram(; probabilistic_facts=facts, rules=rules))
    end
    profile = DSProfile()
    all(validate_program(program, profile) === nothing for program in programs) ||
        error("invalid DS program")
    probability_rows = Tuple{Symbol,Rational{Int},Rational{Int}}[]
    circuit_checks = Bool[]
    for (row, program) in zip(rows, programs)
        all_choices = total_choices(program)
        row_probabilities = Rational{Int}[]
        for kind in (:alert, :calm)
            query = Symbol("$(kind)_", row.id)
            event = compile_event(program, query; profile=profile)
            compiled_probability = wmc(event; semiring=RationalProfile())
            oracle_probability = sum(
                choice_probability(program, selection; T=Rational{Int}) for
                selection in all_choices if query in world(program, selection);
                init=0//1,
            )
            @assert validate(event.circuit) === event.circuit.certificate
            @assert event.circuit.certificate.determinism &&
                    event.circuit.certificate.smoothness
            @assert compiled_probability == oracle_probability "circuit/oracle mismatch"
            push!(circuit_checks, compiled_probability == oracle_probability)
            push!(row_probabilities, compiled_probability)
        end
        push!(probability_rows, (row.id, row_probabilities[1], row_probabilities[2]))
    end
    println(io, "c. compiled (alert, calm) probabilities: ", probability_rows)
    println(io, "   certified-circuit/total-choice cross-check: ", all(circuit_checks))
    println(io, "   declared fragment: finite, function-free, ground, acyclic")
    println(
        io,
        "   refused: function symbols, cycles, unnormalized choices, and zero-mass evidence",
    )
    println(
        io,
        "   theory: distribution semantics assigns mass to two-valued program worlds and WMC uses a semiring [riguzzi2023; kimmig2017; darwiche2002].",
    )

    # d. Read the records' concepts as a typed graph and then as a Kripke frame.
    function concepts(row)
        return Set(
            filter(
                !isnothing,
                (
                    row.hot >= 75 ? :hot : nothing,
                    row.dry >= 50 ? :dry : nothing,
                    row.cool >= 50 ? :cool : nothing,
                    if row.target == :alert
                        :alert
                    elseif row.target == :calm
                        :calm
                    else
                        nothing
                    end,
                ),
            ),
        )
    end
    record_entities = [
        KGEntity(row.id; kind=:record, metadata=(concepts=concepts(row),)) for row in rows
    ]
    concept_names = [:hot, :dry, :cool, :alert, :calm]
    concept_entities = [
        KGEntity(name; kind=:concept, metadata=(concepts=Set{Symbol}(),)) for
        name in concept_names
    ]
    has_concept = KGRelation(:has_concept; domain=:record, range=:concept)
    similar = KGRelation(:similar; domain=:record, range=:record)
    graph_edges = KGEdge[]
    for row in rows
        source = only(entity for entity in record_entities if entity.id == row.id)
        for concept in sort!(collect(concepts(row)); by=string)
            target = only(entity for entity in concept_entities if entity.id == concept)
            push!(
                graph_edges,
                KGEdge(
                    source,
                    has_concept,
                    target,
                    KGProvenance(
                        :showcase_csv;
                        locator="$(row.id)/$concept",
                        content_hash=stable_hash((row.id, concept)),
                    ),
                ),
            )
        end
    end
    push!(
        graph_edges,
        KGEdge(
            record_entities[1],
            similar,
            record_entities[2],
            KGProvenance(
                :showcase_csv; locator="r1~r2", content_hash=stable_hash((:r1, :r2))
            ),
        ),
    )
    graph = KnowledgeGraph(
        vcat(record_entities, concept_entities),
        [has_concept, similar],
        graph_edges;
        provenance=(dataset=basename(DATASET_PATH), seed=SEED),
    )
    alert_path = only(paths(graph, :r1; relation=:has_concept, target=:alert, max_hops=1))
    similar_path = only(paths(graph, :r1; relation=:similar, target=:r2, max_hops=1))
    path_oracle = any(
        edge ->
            edge.source.id == :r1 &&
                edge.relation.id == :has_concept &&
                edge.target.id == :alert,
        Aletheia.AletheiaGraphs.edges(graph),
    )
    similar_oracle = any(
        edge ->
            edge.source.id == :r1 && edge.relation.id == :similar && edge.target.id == :r2,
        Aletheia.AletheiaGraphs.edges(graph),
    )
    @assert path_valid(alert_path, graph) && path_oracle
    @assert path_valid(similar_path, graph) && similar_oracle
    concept_formula = atom(:alert)
    concept_valuation =
        (concept, entity) -> entity.kind == :record && concept in entity.metadata.concepts
    concept_values = concept_extension(
        concept_formula, graph; concept_valuation=concept_valuation
    )
    concept_oracle = BitVector(
        entity.kind == :record && :alert in entity.metadata.concepts for
        entity in Aletheia.AletheiaGraphs.entities(graph)
    )
    @assert concept_values == concept_oracle "graph concept oracle mismatch"
    graph_trace_provenance = Provenance(;
        sources=(dataset=basename(DATASET_PATH),), hashes=(graph=stable_hash(graph),)
    )
    graph_trace = ExecutionTrace(
        [
            TraceStep(
                :graph_path,
                (
                    query=:r1_to_alert,
                    relation=:has_concept,
                    provenance=path_provenance(alert_path),
                    path=alert_path,
                ),
                :r1,
                alert_path.entities,
            ),
        ],
        graph_trace_provenance,
        alert_path.entities,
        stable_hash(:r1),
        stable_hash(alert_path.entities),
        :global;
        artifact=graph,
    )
    graph_replay = replay(graph_trace, :r1)
    @assert graph_replay.valid
    println(
        io,
        "d. typed paths: r1→alert=",
        length(alert_path.relations),
        ", r1→r2=",
        length(similar_path.relations),
    )
    println(io, "   concept(:alert) extension: ", collect(concept_values))
    println(
        io,
        "   graph/path-oracle cross-check: true; provenance trace replay: ",
        graph_replay.valid,
    )
    println(
        io,
        "   theory: a Kripke frame supplies worlds and accessibility for modal evaluation [blackburn2001].",
    )

    # e. A fixed neural boundary, exact finite extraction, and an honest metric population.
    network = FixedNetwork((1.0, 1.0, 0.0), -0.8)
    row_by_id = Dict(row.id => row for row in rows)
    encoder = x -> x isa Symbol ? row_values(row_by_id[x]) : row_values(x)
    neural = neural_valuation(network, encoder; algebra=BOOLEAN)
    direct_outputs = [network(encoder(row)) for row in rows]
    neural_scalar = [neural(:prediction, row) for row in rows]
    neural_batch = neural.vectorized(:prediction, rows)
    neural_formula = atom(:prediction)
    neural_model = Model(frame_, BOOLEAN, neural)
    neural_extension = extension(neural_formula, neural_model)
    @assert neural_scalar == direct_outputs && neural_batch == direct_outputs
    @assert neural_extension == BitVector(direct_outputs)
    cases = [
        ArtifactCase(row, nothing, direct_outputs[i], iseven(i) ? :local : :global) for
        (i, row) in enumerate(rows)
    ]
    provenance = Provenance(;
        versions=(showcase=1,),
        sources=(dataset=basename(DATASET_PATH),),
        hashes=(dataset=stable_hash(rows), model=stable_hash(network)),
    )
    roundtrip = ske_roundtrip(
        network,
        encoder,
        cases;
        algebra=BOOLEAN,
        profile=(name=:fixed_linear, seed=SEED),
        provenance=provenance,
    )
    @assert roundtrip.verification.valid
    @assert all(
        eval_artifact(roundtrip.extracted, row)[1] == direct_outputs[i] for
        (i, row) in enumerate(rows)
    )
    _, original_trace = eval_artifact(roundtrip.extracted, rows[1])
    restored_trace = deserialize_trace(serialize_trace(original_trace))
    trace_replay = replay(restored_trace, rows[1])
    @assert trace_replay.valid
    unknown = (id=:unseen, hot=50, dry=50, cool=50, target=:review)
    honest_cases = vcat(cases, [ArtifactCase(unknown, nothing, missing, :global)])
    metrics = metric_bundle(roundtrip.extracted, honest_cases; scope=:all)
    @assert metrics.fidelity.applicable && metrics.fidelity.value == 0.8
    @assert metrics.coverage.applicable &&
            metrics.coverage.numerator == 4 &&
            metrics.coverage.denominator == 5
    @assert metrics.coverage.value == 0.8
    @assert !metrics.constraints.applicable && metrics.constraints.value === missing
    record = roundtrip.audit
    @assert length(record.trace) == 4
    @assert stable_hash(roundtrip.extracted) == record.artifact_id
    @assert all(
        length(hash) == 64 for hash in vcat(record.input_hashes, record.output_hashes)
    )
    println(io, "e. neural leaves/direct outputs: ", direct_outputs)
    println(
        io,
        "   exact extraction rules: ",
        length(Aletheia.AletheiaAudit.rules(roundtrip.extracted)),
    )
    println(
        io,
        "   round-trip verification: ",
        roundtrip.verification.valid,
        "; trace replay after serialization: ",
        trace_replay.valid,
    )
    println(io, "   metric bundle:")
    for name in (
        :fidelity, :coverage, :stability, :complexity, :constraints, :trace, :resource_cost
    )
        println(io, metric_line(name, getproperty(metrics, name)))
    end
    println(
        io,
        "   audit hashes: artifact length=$(length(record.artifact_id)), inputs=$(length(record.input_hashes)), outputs=$(length(record.output_hashes))",
    )
    println(
        io,
        "   direct-network/neural-leaf cross-check: true; semantic extension cross-check: true",
    )
    println(
        io,
        "   theory: exact extraction on declared finite cases keeps learned predicates and symbolic rules as separate paths [manhaeve2021; li2023; serafini2021; stan2026].",
    )

    return (
        rows=rows,
        plain_extensions=plain_extensions,
        crisp_labels=crisp_labels,
        graded=graded,
        probabilities=probability_rows,
        graph_values=concept_values,
        neural_outputs=direct_outputs,
        roundtrip=roundtrip,
        metrics=metrics,
        graph_trace=graph_trace,
        trace_replay=trace_replay,
        cross_checks=(
            plain=true,
            many_valued=true,
            circuits=all(circuit_checks),
            graph=true,
            neural=true,
        ),
    )
end

end # module AletheiaShowcase

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    AletheiaShowcase.run_showcase()
end
