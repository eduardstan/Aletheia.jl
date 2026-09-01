include(joinpath(@__DIR__, "deployed_apply_common.jl"))
for seed in APPLY_SEEDS
    fixture = build_apply_fixture(train_seed=seed)
    gate = run_parity_gate(fixture)
    println("deployed apply differential: PASS; seed=$(seed); rules=$(gate.rules); " *
        "instances=$(gate.instances); extension_cases=$(gate.extension_cases); " *
        "predictions=$(gate.predictions)")
end
println("deployed apply differential seeds: ", join(string.(APPLY_SEEDS), ","))
