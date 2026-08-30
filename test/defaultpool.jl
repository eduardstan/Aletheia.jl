@testset "default pool" begin
    p = atom("p")
    q = atom("q")

    @test pool(p) === Aletheia.DEFAULT_POOL
    @test signature(Aletheia.DEFAULT_POOL) === Aletheia.DEFAULT_SIGNATURE
    @test connectives(Aletheia.DEFAULT_SIGNATURE) == (¬, ∧, ⊗, ∨, →)

    # The pool-free spelling is the explicit spelling with one argument dropped.
    @test atom("p") == atom(Aletheia.DEFAULT_POOL, "p")
    @test branch(∧, p, q) == branch(Aletheia.DEFAULT_POOL, ∧, p, q)
    @test parse(Formula, "p ∧ q → r") == parse(Aletheia.DEFAULT_POOL, "p ∧ q → r")

    # Connective values are callable on pooled formulas, and the result is a
    # native pooled formula in the operands' own pool.
    @test p ∧ q isa Branch
    @test p ∧ q == branch(∧, p, q)
    @test syntaxstring(¬(p ∧ q) → p) == "¬(p ∧ q) → p"
    @test syntaxstring(p ⊗ q) == "p ⊗ q"
    @test syntaxstring(p ∨ q) == "p ∨ q"

    explicit = FormulaPool(Signature((¬, ∧, Diamond(:G), Box(:G))))
    a = atom(explicit, "p")
    b = atom(explicit, "q")
    @test pool(a ∧ b) === explicit
    @test a ∧ b == branch(explicit, ∧, a, b)
    @test syntaxstring(Diamond(:G)(a)) == "⟨G⟩p"
    @test syntaxstring(Box(:G)(a)) == "[G]p"
    @test pool(Diamond(:G)(a)) === explicit

    # Signatures cannot silently collide: the default path has exactly one
    # signature, and both bad cases are errors rather than wrong answers.
    @test_throws ArgumentError a ∧ q
    @test_throws ArgumentError branch(∧, a, q)
    @test_throws ArgumentError branch(Diamond(:G), p)
    # Outside the default signature, `⟨G⟩` is not a connective at all: the
    # parser reads the text as one atom rather than silently forming a modality.
    @test isatom(parse(Formula, "⟨G⟩p"))
    @test !isequal(p, a)
    @test p != a

    # Type stability: the const pool is concretely typed, so the implicit path
    # infers exactly as the explicit one does.
    @test isconcretetype(typeof(Aletheia.DEFAULT_POOL))
    @test (@inferred atom("p")) == p
    @test (@inferred atom(Aletheia.DEFAULT_POOL, "p")) == p
    @test (@inferred branch(∧, p, q)) == p ∧ q
    @test (@inferred branch(Aletheia.DEFAULT_POOL, ∧, p, q)) == p ∧ q
    @test (@inferred p ∧ q) == branch(∧, p, q)

    # Thread safety: interning is lock-guarded, so concurrent construction
    # through the default pool canonicalizes rather than duplicating or
    # corrupting the pool.  This is meaningful only with more than one thread;
    # it must still pass, and stay silent, on a single-threaded run.
    names = ["t$(i)" for i in 1:200]
    before = nsubterms(Aletheia.DEFAULT_POOL)
    results = Vector{Vector{Int}}(undef, 8)
    Threads.@sync for worker in 1:8
        Threads.@spawn begin
            ids = Int[]
            for name in names
                x = atom(name)
                push!(ids, id(x), id(¬x), id(x ∧ x))
            end
            results[worker] = ids
        end
    end
    @test all(r -> r == results[1], results)
    @test nsubterms(Aletheia.DEFAULT_POOL) == before + 3 * length(names)
    @test length(unique(results[1])) == 3 * length(names)
end
