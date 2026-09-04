using Test

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
