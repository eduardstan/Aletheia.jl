using Test
const _ALETHEIA_CORE = getfield(Aletheia, :AletheiaCore)

mutable struct OwnershipWorld
    id::Int
end
mutable struct OwnershipPayload
    value::Int
end

"""Discover loaded Aletheia package modules and their complete public bindings."""
function _ownership_inventory()
    modules = Module[Aletheia]
    append!(
        modules,
        Module[
            m for
            m in values(Base.loaded_modules) if startswith(String(nameof(m)), "Aletheia")
        ],
    )
    modules = unique(modules)
    return Dict(
        pkg => begin
            exported = names(pkg; all=false, imported=false)
            constructors = Symbol[
                s for s in exported if isdefined(pkg, s) && getfield(pkg, s) isa DataType
            ]
            functions = Symbol[
                s for s in exported if isdefined(pkg, s) && getfield(pkg, s) isa Function
            ]
            (exported=exported, constructors=constructors, accessors=functions)
        end for pkg in modules
    )
end

@testset "one ownership mechanism covers every public package" begin
    inventory = _ownership_inventory()
    @test length(inventory) >= 8
    @test all(!isempty(entry.exported) for entry in values(inventory))
    @test any(!isempty(entry.constructors) for entry in values(inventory))
    @test any(!isempty(entry.accessors) for entry in values(inventory))
    core = only(pkg for pkg in keys(inventory) if nameof(pkg) === :AletheiaCore)

    # This is deliberately a dynamic inventory: adding an exported constructor
    # or accessor changes the set above without requiring a second hand-written
    # list. Every mutable fixture is checked through the one shared mechanism.
    for (pkg, entry) in inventory
        @test all(isdefined(pkg, name) for name in entry.exported)
        for name in (entry.constructors..., entry.accessors...)
            binding = getfield(pkg, name)
            @test getfield(core, :_boundary_copy)(binding) === binding
        end
    end
    original = Dict{Symbol,Any}(:nested => [Dict(:value => 1)])
    owned = getfield(core, :_boundary_copy)(original)
    owned[:nested][1][:value] = 2
    @test original[:nested][1][:value] == 1
    @test owned !== original
end

# Walk the values held by representative public semantic objects. This checks
# fields, rather than a hand-written accessor list: a newly added mutable field
# makes the corresponding constructed value fail immediately.
function _structurally_owned(value, seen=IdDict{Any,Bool}())
    value isa Function && return true
    value isa Union{Nothing,Missing,Number,Symbol,Char,AbstractString,Type} && return true
    value isa ReentrantLock && return true # synchronization state is intentionally mutable
    ismutabletype(typeof(value)) && return false
    value isa AbstractArray && return value isa getfield(_ALETHEIA_CORE, :FrozenArray) &&
           all(_structurally_owned(x, seen) for x in value)
    value isa AbstractDict && return value isa getfield(_ALETHEIA_CORE, :FrozenDict) &&
           all(_structurally_owned(x, seen) for pair in value for x in pair)
    value isa AbstractSet && return value isa getfield(_ALETHEIA_CORE, :FrozenSet) &&
           all(_structurally_owned(x, seen) for x in value)
    value isa Tuple && return all(_structurally_owned(x, seen) for x in value)
    T = typeof(value)
    haskey(seen, value) && return true
    seen[value] = true
    try
        all(_structurally_owned(getfield(value, field), seen) for field in 1:fieldcount(T))
    finally
        delete!(seen, value)
    end
end

@testset "public semantic values are structurally owned" begin
    frame = Aletheia.Frame([:w], Dict(:R => Dict(:w => [:w])); index=true)
    valuation = Aletheia.Valuation(Dict((:p, :w) => false))
    choice = Aletheia.ChoiceVariable(:c, ([1], :b), (0.5, 0.5))
    program = Aletheia.DSProgram(; choices=[choice])
    event = Aletheia.compile_event(program, [1])
    certificate = Aletheia.CircuitCertificate(Dict(), (), Dict(), true, true)
    circuit = Aletheia.CertifiedCircuit(Aletheia.BDDNode[], (1,), certificate)
    case = Aletheia.ArtifactCase(:input, Dict(:state => [1]), [false])
    store = Aletheia.DenseFeatureStore(reshape(Any[[1]], 1, 1, 1), [:w], [:f])
    for value in (valuation, choice, event.circuit, circuit, case, store)
        @test _structurally_owned(value)
    end
    heterogeneous = Dict{Any,Any}(:state => 1, 2 => "ready")
    heterogeneous_case = Aletheia.ArtifactCase(:input, heterogeneous, true)
    frozen_state = getfield(heterogeneous_case, :state)
    @test Dict(frozen_state) == heterogeneous
    @test keytype(frozen_state) === Any
    @test valtype(frozen_state) === Any
    # The cache is a deliberately mutable implementation detail of Frame.
    @test _structurally_owned(frame.worlds)
    mutable_probe = (payload=[1],)
    @test !_structurally_owned(mutable_probe.payload)

    @test_throws Aletheia.OwnershipError Aletheia.Frame(
        [OwnershipWorld(1)], Dict(); index=true
    )
    source = Dict((:p, :w) => false)
    model = Aletheia.Model(Aletheia.Frame([:w]), source)
    source[(:p, :w)] = true
    @test Aletheia.check(Aletheia.atom(:p), model, :w) === false

    payload = OwnershipPayload(1)
    @test_throws Aletheia.OwnershipError Aletheia.ArtifactCase(:input, payload, :output)
    @test_throws Aletheia.OwnershipError Aletheia.KGEntity(
        :entity; metadata=Dict(:payload => payload)
    )

    provenance = Aletheia.Provenance(; hashes=Dict(:x => [1]))
    trace = Aletheia.ExecutionTrace(
        (Aletheia.TraceStep(:test, nothing, nothing, :ok),), provenance, :ok,
        "", "", :global, nothing,
    )
    @test trace.provenance === provenance
    @test_throws CanonicalIndexError (
        getfield(getfield(trace, :provenance), :hashes)[:x][1] = 2
    )

    choices = [Aletheia.ChoiceVariable(:c, (:a, :b), (0.5, 0.5))]
    facts = Aletheia.ProbabilisticFact[]
    rules = Aletheia.GroundRule[]
    domain = [:a, :b]
    @test_throws MethodError Aletheia.DSProgram{
        typeof(choices), typeof(facts), typeof(rules), typeof(domain)
    }(choices, facts, rules, domain)

    owned_types = (
        typeof(frame), typeof(model), typeof(program), typeof(case), typeof(trace),
        typeof(Aletheia.KGEntity(:x)), typeof(Aletheia.KGRelation(:r)),
        typeof(Aletheia.KGEdge(Aletheia.KGEntity(:x), Aletheia.KGRelation(:r), Aletheia.KGEntity(:y))),
        typeof(Aletheia.KnowledgeGraph([Aletheia.KGEntity(:x)], Aletheia.KGRelation[], Aletheia.KGEdge[])),
    )
    @test all(isempty(methods(T)) for T in owned_types if !isempty(T.parameters))
end
