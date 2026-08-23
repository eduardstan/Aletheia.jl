@testset "finite FLew algebras" begin
    # These are the source-order tables from SoleLogics.  Equality here is
    # deliberately element-for-element: the general constructor is the
    # executable specification, not a second set of hand-written implications.
    named = (
        (G3, [1 1 1; 1 2 3; 1 3 3], [1 2 3; 2 2 2; 3 2 3], [1 2 3; 2 2 2; 3 2 3]),
        (G4, [1 1 1 1; 1 2 3 4; 1 3 3 4; 1 4 4 4], [1 2 3 4; 2 2 2 2; 3 2 3 3; 4 2 3 4], [1 2 3 4; 2 2 2 2; 3 2 3 3; 4 2 3 4]),
        (G5, [1 1 1 1 1; 1 2 3 4 5; 1 3 3 4 5; 1 4 4 4 5; 1 5 5 5 5], [1 2 3 4 5; 2 2 2 2 2; 3 2 3 3 3; 4 2 3 4 4; 5 2 3 4 5], [1 2 3 4 5; 2 2 2 2 2; 3 2 3 3 3; 4 2 3 4 4; 5 2 3 4 5]),
        (G6, [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 5 6; 1 5 5 5 5 6; 1 6 6 6 6 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6]),
        (Ł3, [1 1 1; 1 2 3; 1 3 3], [1 2 3; 2 2 2; 3 2 3], [1 2 3; 2 2 2; 3 2 2]),
        (Ł4, [1 1 1 1; 1 2 3 4; 1 3 3 4; 1 4 4 4], [1 2 3 4; 2 2 2 2; 3 2 3 3; 4 2 3 4], [1 2 3 4; 2 2 2 2; 3 2 2 2; 4 2 2 3]),
        (H4, [1 1 1 1; 1 2 3 4; 1 3 3 1; 1 4 1 4], [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4], [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4]),
        (H6, [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 6 5 6; 1 4 6 4 1 6; 1 5 5 1 5 1; 1 6 6 6 1 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 2 4; 5 2 3 2 5 3; 6 2 3 4 3 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 2 4; 5 2 3 2 5 3; 6 2 3 4 3 6]),
        (H6_1, [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 5 5 6; 1 4 5 4 5 6; 1 5 5 5 5 6; 1 6 6 6 6 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 2 3 3; 4 2 2 4 4 4; 5 2 3 4 5 5; 6 2 3 4 5 6]),
        (H6_2, [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 6 6; 1 5 5 6 5 6; 1 6 6 6 6 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 3 4; 5 2 3 3 5 5; 6 2 3 4 5 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 3 4; 5 2 3 3 5 5; 6 2 3 4 5 6]),
        (H6_3, [1 1 1 1 1 1; 1 2 3 4 5 6; 1 3 3 4 5 6; 1 4 4 4 5 6; 1 5 5 5 5 1; 1 6 6 6 1 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 4; 6 2 3 4 4 6], [1 2 3 4 5 6; 2 2 2 2 2 2; 3 2 3 3 3 3; 4 2 3 4 4 4; 5 2 3 4 5 4; 6 2 3 4 4 6]),
        (H9, [1 1 1 1 1 1 1 1 1; 1 2 3 4 5 6 7 8 9; 1 3 3 6 5 6 9 8 9; 1 4 6 4 8 6 7 8 9; 1 5 5 8 5 8 1 8 1; 1 6 6 6 8 6 9 8 9; 1 7 9 7 1 9 7 1 9; 1 8 8 8 8 8 1 8 1; 1 9 9 9 1 9 9 1 9], [1 2 3 4 5 6 7 8 9; 2 2 2 2 2 2 2 2 2; 3 2 3 2 3 3 2 3 3; 4 2 2 4 2 4 4 4 4; 5 2 3 2 5 3 2 5 3; 6 2 3 4 3 6 4 6 6; 7 2 2 4 2 4 7 4 7; 8 2 3 4 5 6 4 8 6; 9 2 3 4 3 6 7 6 9], [1 2 3 4 5 6 7 8 9; 2 2 2 2 2 2 2 2 2; 3 2 3 2 3 3 2 3 3; 4 2 2 4 2 4 4 4 4; 5 2 3 2 5 3 2 5 3; 6 2 3 4 3 6 4 6 6; 7 2 2 4 2 4 7 4 7; 8 2 3 4 5 6 4 8 6; 9 2 3 4 3 6 7 6 9]),
    )
    for (a, expected_join, expected_lattice_meet, expected_monoid) in named
        @test a isa FiniteFLewAlgebra
        @test a.join == UInt8.(expected_join)
        @test a.meet == UInt8.(expected_lattice_meet)
        @test a.monoid == UInt8.(expected_monoid)
        @test truth_type(a) === UInt8 && carrier(a) === UInt8
        @test top(a) == UInt8(1) && bottom(a) == UInt8(2)
        @test domain(a) == Tuple(UInt8.(1:size(a.join, 1)))
        @test levels(a) == domain(a) && !isfinitechain(a)
        @test length(a) == size(a.join, 1)
        for x in domain(a), y in domain(a), z in domain(a)
            @test implication(a, x, y) == residuum(a, x, y)
            @test (precedeq(a, product(a, x, y), z) == precedeq(a, x, implication(a, y, z)))
        end
    end
    @test L3 === Ł3 && L4 === Ł4
    @test BooleanFLewAlgebra isa FiniteFLewAlgebra

    # Differential tests for the Float64 chain fast paths and the general
    # integer-table construction.
    indexof(level, n) = level == 0.0 ? UInt8(2) : level == 1.0 ? UInt8(1) : UInt8(round(Int, level * (n - 1)) + 2)
    for n in 2:12
        for (specialized, kind) in ((GodelAlgebra(n), :godel), (LukasiewiczAlgebra(n), :lukasiewicz))
            general = Aletheia._chain_flew(n, kind)
            vals = collect(levels(specialized))
            for x in vals, y in vals
                ix, iy = indexof(x, n), indexof(y, n)
                @test meet(general, ix, iy) == indexof(meet(specialized, x, y), n)
                @test join(general, ix, iy) == indexof(join(specialized, x, y), n)
                @test implication(general, ix, iy) == indexof(implication(specialized, x, y), n)
                @test negation(general, ix) == indexof(negation(specialized, x), n)
            end
        end
    end

    # H4 witnesses that maximal/minimal members are genuinely set-valued.
    @test lattice_meet(H4, 3, 4) == UInt8(2)
    @test join(H4, 3, 4) == UInt8(1)
    @test maximalmembers(H4, UInt8[3, 4]) == UInt8[3, 4]
    @test minimalmembers(H4, (UInt8(3), UInt8(4))) == UInt8[3, 4]
    @test precedeq(H4, 2, 3) && succeedeq(H4, 3, 2)
    @test precedes(H4, 2, 3) && succeedes(H4, 3, 2)
    @test maximalmembers(H4, UInt8(2)) == UInt8[]
    @test minimalmembers(H4, UInt8(1)) == UInt8[]
    @test_throws ArgumentError maximalmembers(H4, [2, 9])
    @test Aletheia._finite_subset(H4, 2) == UInt8[2]
    flat = FiniteFLewAlgebra([1, 1, 1, 2], [1, 2, 2, 2], [1, 2, 2, 2], 2, 1)
    @test flat isa FiniteFLewAlgebra{2} && flat.join == UInt8[1 1; 1 2]
    @test_throws ArgumentError FiniteFLewAlgebra([1, 2, 3], [1, 2, 3], [1, 2, 3], 2, 1)
    @test_throws ArgumentError FiniteFLewAlgebra{2}(:bad, [1 2; 2 2], [1 2; 2 2], 2, 1)
    @test_throws ArgumentError FiniteFLewAlgebra{2}([1 1; 1 2], :bad, [1 2; 2 2], 2, 1)
    @test sprint(show, H4) == "FiniteFLewAlgebra{4}(bottom=⊥, top=⊤)"

    # Propositional and modal evaluation uses the same UInt8 vector path.
    sig = Signature((¬, ∧, ∨, →, Diamond(:R), Box(:R)))
    pool = FormulaPool(sig)
    p, q = atom(pool, "p"), atom(pool, "q")
    frame = Frame((:a, :b), Dict(:R => Dict(:a => [:b], :b => [:b])); index=true)
    model = Model(frame, H4, Dict("p" => Dict(:a => UInt8(3), :b => UInt8(4)),
        "q" => Dict(:a => UInt8(4), :b => UInt8(3))))
    conjunction = branch(pool, ∧, p, q)
    diamond = branch(pool, Diamond(:R), p)
    box = branch(pool, Box(:R), p)
    @test check(conjunction, model, :a) === UInt8(2)
    @test extension(conjunction, model) isa Vector{UInt8}
    @test extension(conjunction, model) == UInt8[2, 2]
    @test check(diamond, model, :a) === UInt8(4)
    @test check(box, model, :a) === UInt8(4)
    @test extension(diamond, model) == UInt8[4, 4]
    @test extension(box, model) == UInt8[4, 4]
    @test check(branch(pool, ¬, p), model, :a) === negation(H4, UInt8(3))

    # Every validation stage rejects bad data before an invalid object exists.
    valid_join = [1 1 1; 1 2 3; 1 3 3]
    valid_meet = [1 2 3; 2 2 2; 3 2 3]
    valid_monoid = valid_meet
    expect_bad(j, m, o, needle) = begin
        error = try
            FiniteFLewAlgebra(j, m, o, 2, 1)
            nothing
        catch caught
            caught
        end
        @test error isa ArgumentError
        @test occursin(needle, sprint(showerror, error))
    end
    expect_bad([1 2 1; 1 2 3; 1 3 3], valid_meet, valid_monoid, "commutativity")
    expect_bad(valid_join, [1 1 3; 2 2 2; 3 2 3], valid_monoid, "commutativity")
    expect_bad([1 1 1 1; 1 2 3 4; 1 3 3 1; 1 4 1 4],
        [1 2 3 4; 2 2 2 2; 3 2 3 1; 4 2 1 4],
        [1 2 3 4; 2 2 2 2; 3 2 3 1; 4 2 1 4], "absorption")
    expect_bad([1 1 1; 1 2 1; 1 1 3], valid_meet, valid_monoid, "absorption")
    expect_bad(valid_join, valid_meet, [1 2 3; 1 2 3; 3 3 3], "commutativity")
    expect_bad(valid_join, valid_meet, [1 1 1; 1 2 2; 1 2 2], "neutral")
    expect_bad(valid_join, valid_meet, [1 2 3; 2 1 1; 3 1 1], "associativity")
    expect_bad(valid_join, valid_meet, [1 2 3; 2 1 3; 3 3 3], "monotonicity")
    expect_bad(valid_join, [1 2; 2 2], [1 2; 2 2], "table") # inconsistent dimensions
    @test_throws ArgumentError FiniteFLewAlgebra([1 0; 1 2], [1 2; 2 2], [1 2; 2 2], 2, 1)
    drastic = [1 2 3 4; 2 2 2 2; 3 2 2 2; 4 2 2 2]
    expect_bad([1 1 1 1; 1 2 3 4; 1 3 3 1; 1 4 1 4],
        [1 2 3 4; 2 2 2 2; 3 2 3 2; 4 2 2 4], drastic, "residuum")
end
