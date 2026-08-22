# Differential coverage for the Stage 2b frame/world/relation vocabulary.
# The expected cases below are transcribed from the incumbent definitions in
# SoleLogics.jl/src/utils/modal-logic/modal-logic.jl (relations and natural
# accessibility), SoleLogics.jl/src/types/modal-logic.jl:429-490 (predicates),
# SoleLogics.jl/src/utils/modal-logic/modal-logic.jl:703-780 (collateworlds),
# SoleLogics.jl/src/utils/frames/frames.jl (center/empty relations), and SoleLogics.jl/src/types/frames/worlds.jl (world aliases).

struct VocabularyUnknownConnective end
Aletheia.arity(::VocabularyUnknownConnective) = 1

struct VocabularyBareFrame <: AbstractMultiModalFrame{Symbol} end

@testset "frame, world, and relation vocabulary" begin
    worlds_small = (:a, :b, :c)
    frame_small = Frame(worlds_small,
        Dict(:R => Dict(:a => (:b,), :b => (:c,), :c => ())))

    # Incumbent GlobalRel is universal and IdentityRel is equality.  The
    # AtWorldRelation implementation returns exactly its stored target.
    at_b = AtWorldRelation(:b)
    for source in worlds_small, target in worlds_small
        @test relation_holds(globalrel, source, target) == true
        @test relation_holds(identityrel, source, target) == isequal(source, target)
        @test relation_holds(at_b, source, target) == isequal(target, :b)
    end
    @test collect(accessible(frame_small, :a, globalrel)) == collect(worlds_small)
    @test collect(accessible(frame_small, :a, identityrel)) == [:a]
    @test collect(accessible(frame_small, :a, at_b)) == [:b]

    # SoleLogics.jl/src/types/modal-logic.jl:278-287 documents the iterator
    # boundary for global and modal access; no vector is materialised here.
    lazy = accessibles(frame_small, :a, globalrel)
    @test lazy isa Base.Generator
    @test !(lazy isa AbstractVector)
    @test collect(lazy) == collect(worlds_small)
    @test accessibles(frame_small, globalrel) === worlds(frame_small)

    # Converse properties from the incumbent relation traits.
    @test inverse(inverse(globalrel)) === globalrel
    @test inverse(inverse(identityrel)) === identityrel
    @test all(inverse(inverse(r)) === r for r in ALLEN_RELATIONS)
    @test_throws MethodError inverse(at_b) # no converse is intentionally declared
    @test isgrounding(globalrel)
    @test isgrounding(at_b)
    @test isgrounding(tocenterrel)
    @test !isgrounding(identityrel)

    # The abstract hierarchy is dispatchable, while the ordinary Aletheia
    # Frame remains the concrete multimodal implementation.
    @test Frame((:w,), Dict()) isa AbstractMultiModalFrame
    @test AbstractMultiModalFrame <: AbstractFrame
    @test AbstractUniModalFrame <: AbstractFrame
    @test Interval(1, 2) isa AbstractWorld
    @test AbstractWorlds{Interval} <: AbstractVector{Interval}
    @test AnyWorld() isa AnyWorld
    @test Diamond(globalrel) isa AbstractRelationalConnective

    # Incumbent dimensional defaults (SoleLogics.jl/src/utils/frames/full-
    # dimensional-frame/main.jl:141-153) are reproduced for Aletheia frames.
    interval = interval_frame(4)
    @test emptyworld(interval) == Interval(-1, 0)
    @test centralworld(interval) == Interval(2, 4)
    @test collect(accessibles(interval, centralworld(interval), tocenterrel)) == [centralworld(interval)]

    # Exhaustive Boolean world-set collation over a three-world frame.
    allsets = [Set(worlds_small[i] for i in eachindex(worlds_small) if mask & (1 << (i - 1)) != 0)
               for mask in 0:(2^length(worlds_small) - 1)]
    for left in allsets, right in allsets
        @test Set(collateworlds(frame_small, ∧, (left, right))) == intersect(left, right)
        @test Set(collateworlds(frame_small, ∨, (left, right))) == union(left, right)
        @test Set(collateworlds(frame_small, →, (left, right))) == setdiff(Set(worlds_small), left) ∪ right
        @test Set(collateworlds(frame_small, ¬, (left,))) == setdiff(Set(worlds_small), left)
        expected_diamond = Set(source for source in worlds_small if
            any(target -> target in left, accessible(frame_small, source, :R)))
        expected_box = Set(source for source in worlds_small if
            all(target -> target in left, accessible(frame_small, source, :R)))
        @test Set(collateworlds(frame_small, Diamond(:R), (left,))) == expected_diamond
        @test Set(collateworlds(frame_small, Box(:R), (left,))) == expected_box
        # A second relation checks that collation uses the connective's value,
        # not a hard-coded relation name.
        @test Set(collateworlds(frame_small, Diamond(globalrel), (left,))) ==
            (isempty(left) ? Set{Symbol}() : Set(worlds_small))
    end
    @test_throws ArgumentError collateworlds(frame_small, ¬, ())

    # Exhaustive predicate table for the incumbent's values.  See
    # SoleLogics.jl/src/types/modal-logic.jl:429-474 and :478-490.
    connective_cases = (
        (¬, false, true, false, false),
        (∧, false, false, false, false),
        (Diamond(:R), true, true, true, false),
        (Box(:R), true, true, false, true),
    )
    for (connective, modal, unary, diamond, box) in connective_cases
        @test ismodal(connective) == modal
        @test isunary(connective) == unary
        @test isdiamond(connective) == diamond
        @test isbox(connective) == box
    end
    @test !ismodal(:not_a_connective)
    @test !isdiamond(:not_a_connective)
    @test !isbox(:not_a_connective)
    @test ismodal(Diamond)
    @test ismodal(Box)
    @test isdiamond(Diamond)
    @test !isdiamond(Box)
    @test isbox(Box)
    @test !isbox(Diamond)

    # Grounding follows the incumbent's recursive formula criterion.
    pool = FormulaPool(Signature((¬, ∧, Diamond(globalrel), Diamond(:R))))
    atom_p = atom(pool, :p)
    @test !isgrounded(atom_p)
    @test isgrounded(branch(pool, Diamond(globalrel), atom_p))
    @test !isgrounded(branch(pool, Diamond(:R), atom_p))
    @test isgrounded(branch(pool, ∧, branch(pool, Diamond(globalrel), atom_p),
        branch(pool, Diamond(globalrel), atom_p)))
    @test !isgrounded(branch(pool, ∧, branch(pool, Diamond(globalrel), atom_p), atom_p))

    # Differential randomized check: collate the same formula bottom-up and
    # compare its world set with the shared evaluator's per-world `check`.
    rng = MersenneTwister(0xD2B)
    formula_pool = FormulaPool(Signature((¬, ∧, ∨, →,
        Diamond(IA_L), Box(IA_L), Diamond(globalrel), Box(globalrel))))
    p = atom(formula_pool, :p)
    ops = (¬, ∧, ∨, →, Diamond(IA_L), Box(IA_L), Diamond(globalrel), Box(globalrel))
    function random_formula(rng, depth)
        depth == 0 && return p
        op = rand(rng, ops)
        arity(op) == 1 ? branch(formula_pool, op, random_formula(rng, depth - 1)) :
            branch(formula_pool, op, random_formula(rng, depth - 1), random_formula(rng, depth - 1))
    end
    function collated(formula, atomset, fr)
        isatom(formula) && return atomset
        op = operator(formula)
        child_sets = Tuple(collated(child, atomset, fr) for child in children(formula))
        collateworlds(fr, op, child_sets)
    end
    for _ in 1:80
        atomset = Set(world for world in worlds(interval) if rand(rng, Bool))
        model = Model(interval, BOOLEAN, Valuation(Dict(:p => atomset)))
        formula = random_formula(rng, rand(rng, 0:4))
        expected = Set(world for world in worlds(interval) if check(formula, model, world))
        @test Set(collated(formula, atomset, interval)) == expected
    end

    # The nested opt-in module exports the same singleton/type vocabulary,
    # including the compatibility alias that was previously absent.
    @test Aletheia.SoleLogics.globalrel === globalrel
    @test Aletheia.SoleLogics.identityrel === identityrel
    @test Aletheia.SoleLogics.tocenterrel === tocenterrel
    @test Aletheia.SoleLogics.AbstractFrame === AbstractFrame
    @test Aletheia.SoleLogics.AbstractWorld === AbstractWorld
    @test Aletheia.SoleLogics.RCC8Relations === RCC8Relations

    # Exercise the complete incumbent value vocabulary, including display and
    # trait methods that consumers use for dispatch tables.
    io = IOBuffer()
    display_relations = (globalrel, identityrel, at_b, tocenterrel,
        ALLEN_RELATIONS..., IA_AorO, IA_DorBorE, IA_AiorOi, IA_DiorBiorEi, IA_I,
        POINT_RELATIONS..., RCC8_RELATIONS..., RCC5_RELATIONS..., POINT2D_RELATIONS...)
    for relation_value in display_relations
        show(io, relation_value)
        @test !isempty(Aletheia._relation_name(relation_value))
    end
    @test !isempty(String(take!(io)))
    @test arity(globalrel) == arity(identityrel) == arity(at_b) == arity(tocenterrel) == 2
    @test syntaxstring(globalrel) == "G"
    @test syntaxstring(identityrel) == "="
    @test syntaxstring(at_b) == "@(b)"
    @test syntaxstring(tocenterrel) == "◉"
    @test istransitive(CL_N)

    # Call both value and type predicate methods, plus the native atom/branch
    # structural predicates.
    @test isatom(atom_p) && !isatom(branch(pool, Diamond(globalrel), atom_p))
    @test !isbranch(atom_p) && isbranch(branch(pool, Diamond(globalrel), atom_p))
    @test ismodal(Diamond) && ismodal(Diamond(globalrel))
    @test ismodal(Box) && ismodal(Box(:R))
    @test !ismodal(¬) && !ismodal(:plain)
    @test isdiamond(Diamond) && isdiamond(Diamond(globalrel))
    @test !isdiamond(Box) && !isdiamond(Box(:R))
    @test isbox(Box) && isbox(Box(:R))
    @test !isbox(Diamond) && !isbox(Diamond(globalrel))
    # Avoid inference-only elimination of the tiny incumbent methods when
    # collecting source coverage.
    @test Base.invokelatest(relation_holds, GlobalRelation(), :a, :b)
    @test Base.invokelatest(arity, GlobalRelation()) == 2
    @test Base.invokelatest(arity, AtWorldRelation(:a)) == 2
    @test Base.invokelatest(arity, IdentityRelation()) == 2
    @test Base.invokelatest(arity, ToCenterRelation()) == 2
    @test !Base.invokelatest(isgrounding, :plain)
    @test Base.invokelatest(isgrounding, GlobalRelation())
    @test Base.invokelatest(isgrounding, AtWorldRelation(:a))
    @test Base.invokelatest(isgrounding, ToCenterRelation())
    @test Base.invokelatest(istransitive, CL_N)
    @test Base.invokelatest(nchildren, atom_p) == 0
    @test Base.invokelatest(isatom, atom_p)
    @test !Base.invokelatest(isatom, branch(pool, Diamond(globalrel), atom_p))
    @test !Base.invokelatest(isbranch, atom_p)
    @test Base.invokelatest(isbranch, branch(pool, Diamond(globalrel), atom_p))
    @test Base.invokelatest(ismodal, :plain) == false
    @test Base.invokelatest(ismodal, Diamond) && Base.invokelatest(ismodal, Box)
    @test Base.invokelatest(ismodal, Diamond(globalrel))
    @test Base.invokelatest(isbox, :plain) == false
    @test !Base.invokelatest(isbox, Diamond) && Base.invokelatest(isbox, Box)
    @test !Base.invokelatest(isbox, Diamond(globalrel)) && Base.invokelatest(isbox, Box(globalrel))
    @test Base.invokelatest(isdiamond, :plain) == false
    @test !Base.invokelatest(isdiamond, Box) && Base.invokelatest(isdiamond, Diamond)
    @test !Base.invokelatest(isdiamond, Box(globalrel)) && Base.invokelatest(isdiamond, Diamond(globalrel))
    @test Base.isequal(atom_p, branch(pool, Diamond(globalrel), atom_p)) == false
    @test (atom_p == branch(pool, Diamond(globalrel), atom_p)) == false

    # The world-set accessibility view is lazy and must survive re-iteration:
    # a shared `seen` set across passes silently drops already-yielded worlds.
    reachable = accessibles(frame_small, [:a, :b], :R)
    @test !(reachable isa AbstractVector)
    @test collect(reachable) == [:b, :c]
    @test !isempty(reachable)
    @test collect(reachable) == [:b, :c]

    # Natural relations keep the frame's world validation, and an explicitly
    # stored adjacency still wins over the natural reading.
    @test_throws KeyError accessible(frame_small, :not_a_world, identityrel)
    @test_throws KeyError accessible(frame_small, :not_a_world, globalrel)
    @test_throws KeyError accessible(frame_small, :not_a_world, at_b)
    @test_throws KeyError accessible(frame_small, :not_a_world, tocenterrel)
    stored_identity = Frame(worlds_small, Dict(identityrel => Dict(:a => (:b,), :b => (), :c => ())))
    @test collect(accessible(stored_identity, :a, identityrel)) == [:b]
    callable_relations = Frame(worlds_small, (world, relation) ->
        relation == identityrel ? (world == :a ? (:b,) : ()) : ())
    @test collect(accessible(callable_relations, :a, identityrel)) == [:b]
    @test collect(accessible(callable_relations, :a, globalrel)) == []

    # `check(formula, model, AnyWorld())` is satisfaction at some world; the
    # many-valued branch counts only the algebra's top as satisfied.
    any_pool = FormulaPool(Signature((¬, ∧)))
    any_p = atom(any_pool, "p")
    any_frame = Frame((:w1, :w2))
    @test check(any_p, Model(any_frame, BOOLEAN, Dict("p" => Set([:w2]))), AnyWorld())
    @test !check(any_p, Model(any_frame, BOOLEAN, Dict("p" => Set{Symbol}())), AnyWorld())
    @test check(branch(any_pool, ¬, any_p),
        Model(any_frame, BOOLEAN, Dict("p" => Set([:w2]))), AnyWorld())
    @test check(any_p, Model(any_frame, GodelAlgebra(),
        Dict("p" => Dict(:w1 => 1.0, :w2 => 0.5))), AnyWorld())
    @test !check(any_p, Model(any_frame, GodelAlgebra(),
        Dict("p" => Dict(:w1 => 0.9, :w2 => 0.5))), AnyWorld())
    @test_throws ArgumentError collateworlds(frame_small, VocabularyUnknownConnective(), (Set([:a]),))

    # Point and rectangle dimensional defaults share the ordinary Frame API.
    points = point_frame(3)
    grid = point_frame(2, 2)
    rectangles = rectangle_frame(2)
    @test centralworld(points) == 2
    @test emptyworld(points) == -1
    @test centralworld(grid) == Point(1, 1)
    @test emptyworld(grid) == Point(-1, -1)
    @test centralworld(rectangles) isa Rectangle
    @test emptyworld(rectangles) == Rectangle(Interval(-1, 0), Interval(-1, 0))

    # Non-dimensional worlds have no dimensional default, and a frame type that
    # does not implement the protocol is told to provide one.
    symbolic_frame = Frame(worlds_small)
    @test_throws MethodError emptyworld(symbolic_frame)
    @test_throws MethodError centralworld(symbolic_frame)
    @test_throws ErrorException emptyworld(VocabularyBareFrame())
    @test_throws ErrorException centralworld(VocabularyBareFrame())

    # Grounding relations reach the same worlds from every source.
    center = centralworld(interval)
    center_pool = FormulaPool(Signature((Diamond(tocenterrel), Box(tocenterrel), Diamond(globalrel))))
    center_p = atom(center_pool, "p")
    center_diamond = branch(center_pool, Diamond(tocenterrel), center_p)
    center_box = branch(center_pool, Box(tocenterrel), center_p)
    at_center = Model(interval, BOOLEAN, Dict("p" => Set([center])))
    nowhere = Model(interval, BOOLEAN, Dict("p" => Set{typeof(center)}()))
    @test all(extension(center_diamond, at_center))
    @test all(extension(center_box, at_center))
    @test !any(extension(center_diamond, nowhere))
    @test all(check(center_diamond, at_center, world) for world in worlds(interval))
    @test all(extension(branch(center_pool, Diamond(globalrel), center_p), at_center))
    @test !any(extension(branch(center_pool, Diamond(globalrel), center_p), nowhere))

    # A stored adjacency keeps precedence over the natural grounding reading.
    stored_global = Frame(worlds_small,
        Dict(globalrel => Dict(:a => (:b,), :b => (:c,), :c => ())))
    stored_pool = FormulaPool(Signature((Diamond(globalrel),)))
    stored_p = atom(stored_pool, "p")
    stored_model = Model(stored_global, BOOLEAN, Dict("p" => Set([:c])))
    @test extension(branch(stored_pool, Diamond(globalrel), stored_p), stored_model) ==
        BitVector([false, true, false])
end
