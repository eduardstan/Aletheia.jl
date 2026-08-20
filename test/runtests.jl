using Test
using Aqua
using JET
using Aletheia

struct TestXor end
Aletheia.arity(::TestXor) = 2
Aletheia.precedence(::TestXor) = 15
Aletheia.associativity(::TestXor) = :left
Aletheia.notation(::TestXor) = "⊻"

@testset "syntax" begin
    diamond = Diamond(:G)
    box = Box(:G)
    sig = Signature((¬, ∧, ∨, →, diamond, box, TestXor()))
    pool = FormulaPool(sig)

    p = atom(pool, "p")
    q = atom(pool, "q")
    @test p isa Formula
    @test id(atom(pool, "p")) == id(p)
    @test atom(pool, "p") == p
    quoted = atom(pool, "a→b\"c")
    @test parse(pool, string(quoted)) == quoted

    modal = parse(pool, "⟨G⟩p → [G]q")
    @test string(modal) == "⟨G⟩p → [G]q"
    @test parse(pool, string(modal)) == modal
    @test string(parse(pool, "¬1→0"; atom_parser=x -> Base.parse(Float64, x))) == "¬1.0 → 0.0"
    @test string(parse(pool, "¬a → b ∧ c")) == "¬a → b ∧ c"

    left_nested = branch(pool, ∧, branch(pool, →, p, q), q)
    @test string(left_nested) == "(p → q) ∧ q"
    @test string(branch(pool, ¬, branch(pool, ∧, p, q))) == "¬(p ∧ q)"
    @test string(branch(pool, →, p, branch(pool, →, q, p))) == "p → q → p"
    @test string(branch(pool, →, branch(pool, →, p, q), p)) == "(p → q) → p"

    repeated = branch(pool, ∧, branch(pool, TestXor(), p, q), branch(pool, TestXor(), p, q))
    @test id(children(repeated)[1]) == id(children(repeated)[2])
    shallow = branch(pool, ∧, p, q)
    deep = branch(pool, ∧, shallow, q)
    @test typeof(shallow) == typeof(deep)
    @test fieldtype(typeof(shallow), 4) == NTuple{2,Int}
    @test nchildren(deep) == arity(deep) == 2
    @test children(deep)[1] == shallow
    @test nsubterms(repeated) == 4
    ids = subterms(repeated)
    @test ids == sort(ids)
    @test [node.id for node in dag(repeated)] == ids
    @test all(all(child < node.id for child in node.children) for node in dag(repeated))

    other_pool = FormulaPool(sig)
    @test atom(other_pool, "p") != p
    @test nsubterms(pool) == length(subterms(pool))
    @test arity(sig, TestXor()) == 2
end

@testset "Aletheia" begin
    Aqua.test_all(Aletheia)
    if pkgversion(JET) < v"0.11"
        JET.test_package(Aletheia; target_defined_modules=true)
    else
        JET.test_package(Aletheia; target_modules=(Aletheia,), analyze_from_definitions=true)
    end
end
