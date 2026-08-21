# Deterministic differential correctness suite.  It is deliberately housed in
# benchmark/ rather than test/ so Aletheia does not depend on SoleLogics.
import Pkg
sole_path = get(ENV, "SOLELOGICS_PATH", "../SoleLogics.jl")
isdir(sole_path) || error("SoleLogics checkout not found at $sole_path; set SOLELOGICS_PATH")
Pkg.develop(Pkg.PackageSpec(path=sole_path))
Pkg.instantiate()
include(joinpath(@__DIR__, "common.jl"))
using Test

println("differential seed: ", SEED)
rng = MersenneTwister(SEED)

function syntax_random_recipe(rng, depth, nextatom=Ref(0))
    if depth == 0 || rand(rng) < 0.22
        nextatom[] += 1
        return atomrecipe("p$(1 + mod(nextatom[], 7))")
    end
    op = rand(rng, (:not, :and, :or, :implies))
    op === :not ? recipe(op, syntax_random_recipe(rng, depth - 1, nextatom)) :
        recipe(op, syntax_random_recipe(rng, depth - 1, nextatom), syntax_random_recipe(rng, depth - 1, nextatom))
end

function parse_both(text)
    (Aletheia.parse(pool_a(), text), SoleLogics.parseformula(SoleLogics.SyntaxTree, text))
end

# These are the only deliberate representation differences: Aletheia's
# equality is pool-local integer identity, while SoleLogics compares tree
# structure.  The harness compares canonical structure below, never raw values.
const DOCUMENTED_EXCEPTIONS = Dict(
    :formula_equality_scope => "Aletheia equality requires the same FormulaPool; SoleLogics equality is structural across independently allocated trees. The differential test therefore compares canonical structure and same-pool/same-tree decisions.",
    :subformula_identity => "Aletheia subterms are unique pool ids (a DAG set); SoleLogics subformulas returns tree occurrences. The differential test compares Set(canonical representations), which is the comparable subformula set.",
    :printer_associativity => "SoleLogics syntaxstring intentionally omits parentheses around associative commutative chains. Its reparsed tree may therefore be regrouped even though the printed text is stable; round-trip checks compare each package's canonical printed text, while direct parsed structures are compared before printing.",
)

const FORMULA_COUNT = 64
@testset "Aletheia/SoleLogics differential (seed=$SEED)" begin
    @test !isempty(DOCUMENTED_EXCEPTIONS)
    for i in 1:FORMULA_COUNT
        r = syntax_random_recipe(rng, rand(rng, 1:5))
        a = build_a(r, pool_a())
        s = build_s(r)
        text = Aletheia.syntaxstring(a)
        ap, sp = parse_both(text)

        # Both parsers must build the same structure from the same text.
        @test canonical(ap) == canonical(sp)
        atext = Aletheia.syntaxstring(ap)
        stext = SoleLogics.syntaxstring(sp)
        @test Aletheia.syntaxstring(Aletheia.parse(pool_a(), atext)) == atext
        @test SoleLogics.syntaxstring(SoleLogics.parseformula(SoleLogics.SyntaxTree, stext)) == stext
        # Aletheia's explicit parentheses are accepted by the incumbent too.
        @test canonical(SoleLogics.parseformula(SoleLogics.SyntaxTree, atext)) == canonical(ap)

        # Structural equality decisions: equal and deliberately altered forms.
        equal_pool = pool_a()
        aequal = build_a(r, equal_pool)
        aequal_again = build_a(r, equal_pool)
        @test (isequal(aequal, aequal_again)) == (canonical(aequal) == canonical(aequal_again))
        s_equal = build_s(r)
        @test (isequal(s, s_equal)) == (canonical(s) == canonical(s_equal))
        altered = atomrecipe("not-in-formula-$i")
        altered_a = build_a(altered, pool_a())
        altered_s = build_s(altered)
        @test (isequal(a, altered_a)) == (canonical(a) == canonical(altered_a))
        @test (isequal(s, altered_s)) == (canonical(s) == canonical(altered_s))

        # Comparable subformula sets (not occurrence lists; see exception).
        function aset_of(x)
            out = Set{Any}()
            function visit(y)
                push!(out, canonical(y))
                foreach(visit, Aletheia.children(y))
            end
            visit(x)
            out
        end
        aset = aset_of(a)
        sset = Set(canonical(x) for x in SoleLogics.subformulas(s))
        @test aset == sset
    end
end
println("differential: PASS ($FORMULA_COUNT formulas; seed $SEED)")


@testset "semantic evaluation (seed=$SEED)" begin
    modal_rng = MersenneTwister(SEED + 1)
    for trial in 1:64
        n = rand(modal_rng, 2:8)
        depth = rand(modal_rng, 1:5)
        edges = edge_data(n, rand(modal_rng), SEED + trial)
        sets = Dict("p$(i)" => Set(w for w in 1:n if rand(modal_rng, Bool)) for i in 1:6)
        am = a_boolean_model(n, edges; sets=sets)
        sm = s_boolean_model(n, edges; sets=sets)
        recipe = random_recipe(modal_rng, depth; modal=true)
        pool = modal_pool_a(); af = build_a(recipe, pool)
        sf = build_s(recipe)
        @test all(Aletheia.check(af, am, w) ==
            SoleLogics.check(sf, sm, SoleLogics.World(w); perform_normalization=false)
            for w in 1:n)
        @test collect(Aletheia.extension(af, am)) ==
            BitVector([SoleLogics.check(sf, sm, SoleLogics.World(w); perform_normalization=false) for w in 1:n])
    end
end
println("semantic differential: PASS (64 seeded random modal models)")
