using Test
using Random
using Aqua
using JET
using Aletheia

@testset "compatibility remains opt-in" begin
    @test !hasmethod(Aletheia.Atom, Tuple{Any})
    @test !applicable(Aletheia.Atom, :p)
    @test !hasmethod(Aletheia.Branch, Tuple{Any,Tuple})
    @test !applicable(Aletheia.Branch, Aletheia.:∧, ())
end

struct TestXor end
Aletheia.arity(::TestXor) = 2
Aletheia.precedence(::TestXor) = 15
Aletheia.associativity(::TestXor) = :left
Aletheia.notation(::TestXor) = "⊻"

struct TestNullary end
Aletheia.arity(::TestNullary) = 0
Aletheia.notation(::TestNullary) = "z"

struct TestTernary end
Aletheia.arity(::TestTernary) = 3
Aletheia.precedence(::TestTernary) = 40
Aletheia.notation(::TestTernary) = "T"

struct TestWhitespaceNotation end
Aletheia.arity(::TestWhitespaceNotation) = 1
Aletheia.notation(::TestWhitespaceNotation) = "bad op"

struct TestEmptyNotation end
Aletheia.arity(::TestEmptyNotation) = 1
Aletheia.notation(::TestEmptyNotation) = ""

struct TestDelimiterNotation end
Aletheia.arity(::TestDelimiterNotation) = 1
Aletheia.notation(::TestDelimiterNotation) = "("

struct TestUnspecified end

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

@testset "syntax edge cases and API" begin
    invoke_trait(f, x) = Base.invokelatest(f, x)
    invoke_trait3(f, x, y) = Base.invokelatest(f, x, y)
    @test invoke_trait(hasdual, TestUnspecified()) == false
    @test invoke_trait(precedence, TestUnspecified()) == 0
    @test invoke_trait(associativity, TestUnspecified()) == :none
    @test invoke_trait(commutative, TestUnspecified()) == false
    @test invoke_trait(modality, TestUnspecified()) == false
    @test invoke_trait(iscommutative, TestUnspecified()) == false
    @test invoke_trait(ismodality, TestUnspecified()) == false
    @test_throws MethodError arity(TestUnspecified())
    @test_throws ArgumentError dual(TestUnspecified())
    @test precedence(TestUnspecified()) == 0
    @test associativity(TestUnspecified()) == :none
    @test !commutative(TestUnspecified())
    @test !modality(TestUnspecified())
    @test !hasdual(TestUnspecified())
    @test !iscommutative(TestUnspecified())
    @test !ismodality(TestUnspecified())
    @test notation(TestUnspecified()) isa String

    @test Signature([¬, ∧]).arities == (1, 2)
    @test Signature([¬, ∧], [1, 2]).arities == (1, 2)
    @test_throws ArgumentError Signature(())
    @test_throws ArgumentError Signature((¬, ∧), (1,))
    @test_throws ArgumentError Signature((¬,), (2,))
    @test_throws ArgumentError Signature((∧, Conjunction()))
    @test_throws ArgumentError Signature((TestWhitespaceNotation(),))
    @test_throws ArgumentError Signature((TestEmptyNotation(),))
    @test_throws ArgumentError Signature((TestDelimiterNotation(),))

    nullary = TestNullary()
    ternary = TestTernary()
    sig = Signature((¬, ∧, nullary, ternary))
    pool = FormulaPool(sig)
    p = atom(pool, "p")
    q = atom(pool, "q")
    r = atom(pool, "r")
    z = branch(pool, nullary)
    @test branch(pool, nullary, ()) == z
    @test string(z) == "z"
    @test parse(pool, "z()") == z
    @test parse("z()", pool) == z
    @test parse(pool, "(p)") == p
    @test parse(pool, "¬(p)") == branch(pool, ¬, p)
    t = parse(pool, "T(p,q,r)")
    @test t == branch(pool, ternary, p, q, r)
    @test string(t) == "T(p, q, r)"
    @test nchildren(p) == 0
    @test nchildren(t) == arity(t) == 3
    @test children(p) == ()
    @test children(t) == (p, q, r)
    @test signature(pool) == sig
    @test signature(p) == sig
    @test signature(t) == sig
    @test connectives(sig) == sig.connectives
    @test hasconnective(sig, ternary)
    @test !hasconnective(sig, TestXor())
    @test_throws ArgumentError arity(sig, TestXor())

    @test Aletheia._formula(pool, id(p)) == p
    @test Aletheia._formula(pool, id(t)) == t
    @test_throws BoundsError Aletheia._formula(pool, 0)
    @test dag(pool) isa Vector{DAGNode}
    @test dag(pool, id(t)).id == id(t)
    @test_throws BoundsError dag(pool, 0)
    @test subterms(p) == [id(p)]
    @test dag(p)[1].kind == :atom
    @test nsubterms(p) == 1
    @test nsubterms(pool) == length(subterms(pool))

    other = FormulaPool(sig)
    otherp = atom(other, "p")
    @test Aletheia.pool(p) === pool
    @test id(p) == id(otherp)
    @test !isequal(p, otherp)
    @test !(p == otherp)
    @test !isequal(p, t)
    @test !isequal(t, p)
    @test !(p == t)
    @test !(t == p)
    @test hash(p) isa UInt
    @test hash(t) isa UInt
    @test operator(t) === ternary
    @test head(t) === ternary
    @test value(p) == "p"
    @test isatom(p) && !isatom(t)
    @test !isbranch(p) && isbranch(t)
    @test invoke_trait(Aletheia.pool, t) === pool
    @test invoke_trait(nchildren, p) == 0
    @test invoke_trait(arity, p) == 0
    @test invoke_trait(isatom, p) && !invoke_trait(isatom, t)
    @test !invoke_trait(isbranch, p) && invoke_trait(isbranch, t)
    @test Base.invokelatest(Atom, pool, "new") == atom(pool, "new")
    @test Base.invokelatest(Branch, pool, ∧, (p, q)) == branch(pool, ∧, p, q)
    @test Base.invokelatest(Branch, pool, ∧, p, q) == branch(pool, ∧, p, q)
    @test invoke_trait3(isequal, t, t)
    @test !invoke_trait3(isequal, p, t) && !invoke_trait3(isequal, t, p)
    @test !Base.invokelatest((==), p, t) && !Base.invokelatest((==), t, p)

    @test arity(¬) == 1
    @test arity(∧) == 2
    @test arity(∨) == 2
    @test arity(→) == 2
    @test arity(Diamond(:G)) == 1
    @test arity(Box(:G)) == 1
    @test precedence(¬) > precedence(∧) > precedence(∨) > precedence(→)
    @test associativity(∧) == :left && associativity(→) == :right
    @test commutative(∧) && commutative(∨)
    @test modality(Diamond(:G)) && modality(Box(:G))
    @test ismodality(Diamond(:G))
    @test relation(Diamond(:G)) == :G && relation(Box(:G)) == :G
    @test dual(¬) === ¬
    @test dual(∧) === (∨) && dual(∨) === (∧)
    @test dual(Diamond(:G)) == Box(:G)
    @test dual(Box(:G)) == Diamond(:G)
    @test hasdual(Diamond(:G))
    for c in (¬, ∧, ∨, →, Diamond(:G), Box(:G))
        @test invoke_trait(arity, c) == arity(c)
        @test invoke_trait(precedence, c) == precedence(c)
        @test invoke_trait(associativity, c) == associativity(c)
    end
    for c in (∧, ∨)
        @test invoke_trait(commutative, c)
    end
    for c in (Diamond(:G), Box(:G))
        @test invoke_trait(modality, c)
        @test invoke_trait(hasdual, c)
    end
    @test invoke_trait(hasdual, ¬)
    @test sprint(show, p) == "p"
    @test sprint(show, t) == "T(p, q, r)"
    @test sprint(show, ∧) == "∧"
    @test sprint(show, ∨) == "∨"
    @test sprint(show, →) == "→"
    @test sprint(show, ¬) == "¬"
    @test sprint(show, Diamond(:G)) == "⟨G⟩"
    @test sprint(show, Box(:G)) == "[G]"

    @test_throws ArgumentError parse(pool, "")
    @test_throws ArgumentError parse(pool, "(")
    @test_throws ArgumentError parse(pool, "T p")
    @test_throws ArgumentError parse(pool, "T(p,q)")
    @test_throws ArgumentError parse(pool, "T(p,q,r,s)")
    @test_throws ArgumentError parse(pool, "T(p,q,r")
    @test_throws ArgumentError parse(pool, "¬(p")
    @test_throws ArgumentError parse(pool, "¬(p,q)")
    @test_throws ArgumentError parse(pool, "z(p)")
end

include("semantics.jl")
include("evaluation.jl")
include("algebras.jl")
include("relations.jl")
include("theory.jl")
include("compatibility.jl")
include("ilp.jl")
include("examples.jl")
@testset "Aletheia" begin
    Aqua.test_all(Aletheia)
    if pkgversion(JET) < v"0.11"
        JET.test_package(Aletheia; target_defined_modules=true)
    else
        JET.test_package(Aletheia; target_modules=(Aletheia,), analyze_from_definitions=true)
    end
end
