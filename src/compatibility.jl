# Compatibility vocabulary for consumers migrating from SoleLogics.
#
# This module is deliberately nested: `using Aletheia.SoleLogics` imports the
# incumbent spellings without adding them to Aletheia's own namespace.
"""
    Aletheia.SoleLogics

Opt-in vocabulary adapters for consumers migrating from SoleLogics. The
module keeps incumbent names out of Aletheia's top-level namespace and raises
explicit errors for concepts with no faithful equivalent.
"""
module SoleLogics

import ..Aletheia

const children = Aletheia.children
const value = Aletheia.value
const arity = Aletheia.arity
const hasdual = Aletheia.hasdual
const dual = Aletheia.dual
const relation = Aletheia.relation

"""An error-producing marker for an old API with no faithful Aletheia value.

The symbol is a type parameter so every marker has a distinct dispatch type.
That matters for consumers which define one method per legacy relation name.
"""
struct _UnsupportedName{Name} end
Base.show(io::IO, ::_UnsupportedName{Name}) where Name =
    print(io, "unsupported SoleLogics.", Name)
(value::_UnsupportedName{Name})(args...) where Name =
    _unsupported(Name, "this legacy value is a deliberate compatibility gap")
_unsupported_name(name::Symbol) = _UnsupportedName{name}()

function _unsupported(name::Symbol, detail::AbstractString)
    throw(ArgumentError("SoleLogics.$name has no faithful Aletheia equivalent: $detail"))
end

# Aletheia's explicit pool is hidden behind this one migration-only default.
# New code should use FormulaPool/Signature directly instead.
const _DEFAULT_SIGNATURE = Aletheia.Signature((Aletheia.:¬, Aletheia.:∧, Aletheia.:∨, Aletheia.:→))
const _DEFAULT_POOL = Aletheia.FormulaPool(_DEFAULT_SIGNATURE)

"""The Aletheia formula interface used in place of SoleLogics.Formula."""
const Formula = Aletheia.Formula
const SyntaxStructure = Aletheia.Formula
const SyntaxTree = Aletheia.Formula
abstract type NamedConnective{Name} end
struct _CompatConnective{Name,C} <: NamedConnective{Name}
    native::C
end
const _NOT = _CompatConnective{:¬,Aletheia.Negation}(Aletheia.:¬)
const _AND = _CompatConnective{:∧,Aletheia.Conjunction}(Aletheia.:∧)
const _OR = _CompatConnective{:∨,Aletheia.Disjunction}(Aletheia.:∨)
const _IMP = _CompatConnective{:→,Aletheia.Implication}(Aletheia.:→)
const Operator = NamedConnective
const Connective = Operator
const AbstractRelation = Aletheia.RelationFamily
const BoxRelationalConnective = Aletheia.Box{<:Any}
const DiamondRelationalConnective = Aletheia.Diamond{<:Any}
const _LegacyConnective = Union{Aletheia.Negation,Aletheia.Conjunction,Aletheia.Disjunction,Aletheia.Implication}

# Truth values are intentionally separate from formulas. Keeping markers for
# old spellings makes a bad migration fail at the point of use, with a useful
# explanation, instead of turning a truth value into an atom.
abstract type Truth end
struct BooleanTruth <: Truth
    value::Bool
end
const TOP = BooleanTruth(true)
const BOT = BooleanTruth(false)
const ⊤ = TOP
const ⊥ = BOT
value(truth::BooleanTruth) = truth.value
istop(truth::BooleanTruth) = truth.value
isbot(truth::BooleanTruth) = !truth.value
istop(value) = false
isbot(value) = false
children(::Truth) = ()
arity(::Truth) = 0
truths(::Aletheia.Formula) = Truth[]
truths(::Truth) = _unsupported(:truths, "truth markers are semantic values, not formula truth collections")
collatetruth(args...) = _unsupported(:collatetruth,
    "Aletheia evaluates semantic values through TruthAlgebra and never treats them as formulas")


# Compatibility formulas wrap ordinary Aletheia DAG handles.  Keeping the
# wrapper type here (rather than extending Aletheia.Atom's constructor) makes
# the migration constructor local while allowing `Atom` in `isa` and dispatch.
struct Atom <: Aletheia.Formula
    native::Aletheia.Atom
    Atom(native::Aletheia.Atom, ::Val{:native}) = new(native)
end
struct _CompatBranch{C,N} <: Aletheia.Formula
    native::Aletheia.Branch{C,N}
end
const _CompatFormula = Union{Atom,_CompatBranch}
const SyntaxLeaf = Atom
const AbstractAtom = Atom
_wrap(formula::Atom) = formula
_wrap(formula::_CompatBranch) = formula
_wrap(formula::Aletheia.Atom) = Atom(formula, Val(:native))
_wrap(formula::Aletheia.Branch) = _CompatBranch(formula)
function _unwrap(formula::Atom)
    formula.native
end
function _unwrap(formula::_CompatBranch)
    formula.native
end
_unwrap(formula::Aletheia.Formula) = formula

function Atom(value)
    value isa Aletheia.Formula && _unsupported(:Atom,
        "Aletheia atoms cannot contain formulas; use children/branch instead")
    value isa Truth && _unsupported(:Atom,
        "truth values are semantic values, not formulas in Aletheia")
    _wrap(Aletheia.atom(_DEFAULT_POOL, value))
end

# Sole treats connective values as constructors.  Keep Aletheia's values (and
# thus their type-level dispatch identity) while adding the opt-in call form.
function (connective::Aletheia.Negation)(formula::Aletheia.Formula)
    Branch(connective, formula)
end
function (connective::Union{Aletheia.Conjunction,Aletheia.Disjunction,
        Aletheia.Implication})(left::Aletheia.Formula, right::Aletheia.Formula)
    Branch(connective, left, right)
end

function _formula_pool_for(connective, formulas)
    fs = Tuple(formulas)
    existing = filter(x -> x isa Aletheia.Formula, fs)
    if !isempty(existing)
        candidate = Aletheia.pool(_unwrap(first(existing)))
        if all(Aletheia.pool(_unwrap(f)) === candidate for f in existing) &&
                Aletheia.hasconnective(Aletheia.signature(candidate), connective)
            return candidate
        end
        connectives = Aletheia.connectives(Aletheia.signature(candidate))
        return Aletheia.FormulaPool(Aletheia.Signature((connectives..., connective)))
    end
    Aletheia.FormulaPool(Aletheia.Signature((Aletheia.:¬, Aletheia.:∧, Aletheia.:∨, Aletheia.:→, connective)))
end

function _repool(formula, target)
    native = _unwrap(formula)
    native isa Aletheia.Atom && return _wrap(Aletheia.atom(target, Aletheia.value(native)))
    native isa Aletheia.Branch || _unsupported(:SyntaxBranch,
        "children must be Aletheia formulas (got $(typeof(formula)))")
    _wrap(Aletheia.branch(target, Aletheia.operator(native),
        Tuple(_unwrap(_repool(child, target)) for child in Aletheia.children(native))))
end

function Branch(connective::_LegacyConnective, children::Tuple)
    connective isa _UnsupportedName && _unsupported(:SyntaxBranch,
        "the requested connective is not implemented by Aletheia")
    pool = _formula_pool_for(connective, children)
    normalized = Tuple(_repool(child, pool) for child in children)
    _wrap(Aletheia.branch(pool, connective, Tuple(_unwrap.(normalized))))
end
Branch(connective::_LegacyConnective, children...) = Branch(connective, children)
Branch(connective::Aletheia.Diamond, children...) = begin
    pool = _formula_pool_for(connective, children)
    normalized = Tuple(_repool(child, pool) for child in children)
    _wrap(Aletheia.branch(pool, connective, Tuple(_unwrap.(normalized))))
end
Branch(connective::Aletheia.Box, children...) = begin
    pool = _formula_pool_for(connective, children)
    normalized = Tuple(_repool(child, pool) for child in children)
    _wrap(Aletheia.branch(pool, connective, Tuple(_unwrap.(normalized))))
end
const SyntaxBranch = Branch

# Old accessors and tree walks.
token(formula::Atom) = formula
function token(formula::_CompatBranch)
    native = Aletheia.operator(formula.native)
    native isa Aletheia.Negation && return _NOT
    native isa Aletheia.Conjunction && return _AND
    native isa Aletheia.Disjunction && return _OR
    native isa Aletheia.Implication && return _IMP
    native
end
token(formula::Aletheia.Atom) = formula
token(formula::Aletheia.Branch) = Aletheia.operator(formula)
Aletheia.arity(connective::_CompatConnective) = Aletheia.arity(connective.native)
Aletheia.notation(connective::_CompatConnective) = Aletheia.notation(connective.native)
token(value::Truth) = value
op(value) = token(value)
value(formula::Atom) = Aletheia.value(formula.native)
children(::Atom) = ()
children(formula::_CompatBranch) = Tuple(_wrap.(Aletheia.children(formula.native)))
nchildren(formula::Union{Atom,_CompatBranch}) = length(children(formula))
tree(formula::Aletheia.Formula) = formula
nchildren(formula::Aletheia.Formula) = Aletheia.nchildren(formula)

function _walk(formula::Aletheia.Formula, out::Vector)
    for child in children(formula)
        _walk(child, out)
    end
    push!(out, formula)
    out
end
function formulas(formula::Aletheia.Formula)
    _walk(formula, Aletheia.Formula[])
end
function subformulas(formula::Aletheia.Formula; sorted=true)
    result = formulas(formula)
    sorted ? sort!(result, by=height) : result
end
function atoms(formula::Aletheia.Formula)
    [node for node in formulas(formula) if node isa Atom || node isa Aletheia.Atom]
end
function leaves(formula::Aletheia.Formula)
    atoms(formula)
end
function connectives(formula::Aletheia.Formula)
    [token(node) for node in formulas(formula) if node isa _CompatBranch || node isa Aletheia.Branch]
end
operators(formula::Aletheia.Formula) = connectives(formula)
ntokens(formula::Aletheia.Formula) = length(formulas(formula))
natoms(formula::Aletheia.Formula) = length(atoms(formula))
nleaves(formula::Aletheia.Formula) = natoms(formula)
nconnectives(formula::Aletheia.Formula) = length(connectives(formula))
noperators(formula::Aletheia.Formula) = nconnectives(formula)
function height(formula::Aletheia.Formula)
    isempty(children(formula)) ? 0 : 1 + maximum(height, children(formula))
end

# Aletheia's normal forms are ordinary hash-consed formulas, not Sole's
# leftmost wrapper types. These helpers are useful for formulas after parsing.
function _flatten(formula::Aletheia.Formula, connective)
    if (formula isa _CompatBranch && token(formula).native isa connective) ||
            (formula isa Aletheia.Branch && Aletheia.operator(formula) isa connective)
        child = children(formula)
        return vcat(_flatten(child[1], connective), _flatten(child[2], connective))
    end
    [formula]
end
conjuncts(formula::Aletheia.Formula) = _flatten(formula, Aletheia.Conjunction)
disjuncts(formula::Aletheia.Formula) = _flatten(formula, Aletheia.Disjunction)
grandchildren(formula::Aletheia.Formula) = children(formula)
nconjuncts(formula::Aletheia.Formula) = length(conjuncts(formula))

# Poolless spellings remain available for old call sites; explicit pool forms
# are also accepted and preserve Aletheia's pool semantics.
atom(value) = Atom(value)
atom(pool::Aletheia.FormulaPool, value) = _wrap(Aletheia.atom(pool, value))
branch(pool::Aletheia.FormulaPool, connective, children...) =
    _wrap(Aletheia.branch(pool, connective, Tuple(_unwrap.(children))))
branch(connective::_LegacyConnective, children...) = Branch(connective, children...)

function syntaxstring(formula::Aletheia.Formula; kwargs...)
    allowed = (:threshold_digits, :function_notation, :remove_redundant_parentheses, :parenthesize_atoms)
    unknown = setdiff(collect(keys(kwargs)), collect(allowed))
    isempty(unknown) || _unsupported(:syntaxstring,
        "Aletheia's printer does not accept keyword(s) $(join(string.(unknown), ", ")).")
    Aletheia.syntaxstring(_unwrap(formula))
end
syntaxstring(connective::_CompatConnective; kwargs...) = Aletheia.notation(connective.native)
syntaxstring(connective::_LegacyConnective; kwargs...) = Aletheia.notation(connective)
syntaxstring(value; kwargs...) = string(value)

# Parser adapter. The callback returns an atom payload in Aletheia; callbacks
# written for SoleLogics may return the compatibility Atom constructor.
function _payload(atom_parser, text)
    parsed = atom_parser(text)
    parsed isa Truth && _unsupported(:parseformula,
        "truth values are not formula leaves in Aletheia")
    parsed isa Atom ? value(parsed) : parsed isa Aletheia.Atom ? Aletheia.value(parsed) : parsed
end
function _parse_pool(additional_operators)
    extras = additional_operators === nothing ? () : Tuple(additional_operators)
    all(c -> arity(c) isa Integer, extras)
    Aletheia.FormulaPool(Aletheia.Signature((Aletheia.:¬, Aletheia.:∧, Aletheia.:∨, Aletheia.:→, extras...)))
end
function parseformula(expr::AbstractString; atom_parser=identity,
        additional_operators=nothing, function_notation=false, kwargs...)
    ignored = (:additional_whitespaces, :opening_parenthesis, :closing_parenthesis, :arg_delim,
        :threshold_digits, :remove_redundant_parentheses, :parenthesize_atoms)
    unknown = setdiff(collect(keys(kwargs)), collect(ignored))
    isempty(unknown) || _unsupported(:parseformula,
        "Aletheia's parser does not accept keyword(s) $(join(string.(unknown), ", "))")
    pool = additional_operators === nothing ? _DEFAULT_POOL : _parse_pool(additional_operators)
    _wrap(Aletheia.parse(pool, expr; atom_parser=text -> _payload(atom_parser, text)))
end
parseformula(::Type{<:Aletheia.Formula}, expr::AbstractString; kwargs...) = parseformula(expr; kwargs...)
parseformula(expr::AbstractString, additional_operators; kwargs...) =
    parseformula(expr; additional_operators=additional_operators, kwargs...)
parseformula(::Type{<:Aletheia.Formula}, expr::AbstractString, additional_operators; kwargs...) =
    parseformula(expr; additional_operators=additional_operators, kwargs...)

# Core evaluation/model names retain their Aletheia meaning. In particular,
# check now consumes a Model rather than Sole's InterpretationSet.  Formula
# wrappers are unwrapped at this boundary.
check(formula::Aletheia.Formula, args...; kwargs...) =
    Aletheia.check(_unwrap(formula), args...; kwargs...)
interpret(formula::Aletheia.Formula, args...; kwargs...) =
    Aletheia.interpret(_unwrap(formula), args...; kwargs...)
frame = Aletheia.frame
algebra = Aletheia.algebra
domain = Aletheia.domain
top = Aletheia.top
bot = Aletheia.bot
worlds = Aletheia.worlds
worldtype(f) = eltype(Aletheia.worlds(Aletheia.frame(f)))
accessible = Aletheia.accessible
allworlds(f) = collect(Aletheia.worlds(f))
accessibles(f, world, relation) = collect(Aletheia.accessible(f, world, relation))

# Legacy formula containers are deliberately not aliases: Aletheia's ordinary
# Formula is a pool-local DAG, and cannot honestly promise grandchildren or
# leftmost linear-form invariants.
abstract type LeftmostLinearForm end
const LeftmostConjunctiveForm = LeftmostLinearForm
const LeftmostDisjunctiveForm = LeftmostLinearForm
const DNF = LeftmostLinearForm
const CNF = LeftmostLinearForm
struct Literal
    function Literal(args...)
        _legacy_container(:Literal, args...)
    end
end
const AbstractInterpretationSet = _unsupported_name(:AbstractInterpretationSet)
function _legacy_container(name, args...)
    _unsupported(name, "Aletheia has ordinary Formula DAGs, not Sole leftmost/interpretation-set containers")
end
LeftmostLinearForm(args...) = _legacy_container(:LeftmostLinearForm, args...)
function ispos(args...)
    _unsupported(:ispos, "Aletheia has no Literal wrapper; use an explicit negation branch")
end

# Modal and dimensional spellings with a direct data-level equivalent.
const Interval = Aletheia.Interval
const Interval2D = Aletheia.Interval2D
const Point = Aletheia.Point
const Point1D = Aletheia.Point
const Point2D = Aletheia.Point
const FullDimensionalFrame = Aletheia.FullDimensionalFrame
diamond(relation_value) = Aletheia.Diamond(relation_value)
box(relation_value) = Aletheia.Box(relation_value)
const IA_A = Aletheia.IA_A
const IA_L = Aletheia.IA_L
const IA_B = Aletheia.IA_B
const IA_E = Aletheia.IA_E
const IA_D = Aletheia.IA_D
const IA_O = Aletheia.IA_O
const IA_Ai = Aletheia.IA_Ai
const IA_Li = Aletheia.IA_Li
const IA_Bi = Aletheia.IA_Bi
const IA_Ei = Aletheia.IA_Ei
const IA_Di = Aletheia.IA_Di
const IA_Oi = Aletheia.IA_Oi
const TruthDict = Aletheia.Valuation
KripkeStructure(frame_value, valuation_value) = Aletheia.Model(frame_value, Aletheia.BOOLEAN, valuation_value)

# Names used by Sole's modal and collection helpers.
const IARelations = (IA_A, IA_L, IA_B, IA_E, IA_D, IA_O, IA_Ai, IA_Li, IA_Bi, IA_Ei, IA_Di, IA_Oi)
const RCC5Relations = _unsupported_name(:RCC5Relations)
function alphabet(args...)
    _unsupported(:alphabet, "Aletheia has no model-wide alphabet object; collect Atom payloads from a Formula")
end
function feature(args...)
    _unsupported(:feature, "feature metadata belongs to SoleData conditions, not Aletheia syntax")
end
function condition(args...)
    _unsupported(:condition, "condition metadata belongs to SoleData conditions, not Aletheia syntax")
end
function threshold(args...)
    _unsupported(:threshold, "threshold metadata belongs to SoleData conditions, not Aletheia syntax")
end
function normalize(args...)
    _unsupported(:normalize, "Aletheia's normal-form conversion is explicit: use cnf or dnf")
end
function sample(args...)
    _unsupported(:sample, "random SoleLogics generation is not part of Aletheia's compatibility surface")
end
function worldtype(::Aletheia.Frame)
    _unsupported(:worldtype, "Aletheia frames are heterogeneous tuples; use eltype(worlds(frame)) explicitly")
end
name(connective) = Symbol(Aletheia.notation(connective))

# Compass relations remain explicit gaps: Aletheia does not yet implement
# the Compass family.  The other names below are incumbent aliases, not gaps;
# preserve their definitions rather than guessing from their spelling.
for name in (:CL_N, :CL_S, :CL_E, :CL_W)
    @eval const $(name) = _unsupported_name($(QuoteNode(name)))
end
const HS_A = Aletheia.IA_A
const HS_L = Aletheia.IA_L
const HS_B = Aletheia.IA_B
const HS_E = Aletheia.IA_E
const HS_D = Aletheia.IA_D
const HS_O = Aletheia.IA_O
const HS_Ai = Aletheia.IA_Ai
const HS_Li = Aletheia.IA_Li
const HS_Bi = Aletheia.IA_Bi
const HS_Ei = Aletheia.IA_Ei
const HS_Di = Aletheia.IA_Di
const HS_Oi = Aletheia.IA_Oi
const LRCC8_Rec_DC = Aletheia.Topo_DC
const LRCC8_Rec_EC = Aletheia.Topo_EC
const LRCC8_Rec_PO = Aletheia.Topo_PO
const LRCC8_Rec_TPP = Aletheia.Topo_TPP
const LRCC8_Rec_TPPi = Aletheia.Topo_TPPi
const LRCC8_Rec_NTPP = Aletheia.Topo_NTPP
const LRCC8_Rec_NTPPi = Aletheia.Topo_NTPPi
const LTLFP_F = Aletheia.GREATER
const LTLFP_P = Aletheia.LESSER

# A small, explicit nested replacement for SoleLogics.ManyValuedLogics.
module ManyValuedLogics
import ...Aletheia
struct _UnsupportedMV{Name} end
Base.show(io::IO, ::_UnsupportedMV{Name}) where Name =
    print(io, "unsupported SoleLogics.ManyValuedLogics.", Name)
(value::_UnsupportedMV{Name})(args...) where Name =
    _unsupported(Name, "this many-valued legacy value is a deliberate compatibility gap")
_unsupported_mv(name::Symbol) = _UnsupportedMV{name}()
export FiniteTruth, ContinuousTruth, FiniteFLewAlgebra, getdomain
export GodelAlgebra, LukasiewiczAlgebra, BooleanAlgebra
export booleanalgebra, precedeq, succeedeq, maximalmembers, minimalmembers
export α, β
for name in (:FiniteTruth, :ContinuousTruth, :FiniteFLewAlgebra)
    @eval abstract type $(name) end
    @eval (::Type{$(name)})(args...) = _unsupported($(QuoteNode(name)), "Aletheia does not provide Sole's finite tableau type")
end
const GodelAlgebra = Aletheia.GodelAlgebra
const LukasiewiczAlgebra = Aletheia.LukasiewiczAlgebra
const BooleanAlgebra = Aletheia.BooleanAlgebra
getdomain(algebra::Aletheia.TruthAlgebra) = Aletheia.domain(algebra)
getdomain(args...) = _unsupported(:getdomain, "the supplied value is not an Aletheia TruthAlgebra")
function _unsupported(name::Symbol, detail::AbstractString)
    throw(ArgumentError("SoleLogics.ManyValuedLogics.$name has no faithful Aletheia equivalent: $detail"))
end
booleanalgebra(args...) = _unsupported(:booleanalgebra,
    "Aletheia uses BooleanAlgebra() as an explicit TruthAlgebra")
precedeq(args...) = _unsupported(:precedeq,
    "Aletheia's finite chains expose ordered levels rather than Sole order relations")
succeedeq(args...) = _unsupported(:succeedeq,
    "Aletheia's chain algebra does not implement Sole's successor protocol")
maximalmembers(args...) = _unsupported(:maximalmembers, "many-valued tableau order helpers are not in Aletheia")
minimalmembers(args...) = _unsupported(:minimalmembers, "many-valued tableau order helpers are not in Aletheia")
const α = _unsupported_mv(:α)
const β = _unsupported_mv(:β)
for name in (:G3, :G4, :G5, :G6, :H4, :H6, :H6_1, :H6_2, :H6_3, :H9, :Ł3, :Ł4)
    @eval const $(name) = _unsupported_mv($(QuoteNode(name)))
end
end
export Formula, SyntaxStructure, SyntaxTree, SyntaxLeaf, SyntaxBranch, Branch
export Atom, AbstractAtom, AbstractRelation, Operator, Connective, NamedConnective
export BoxRelationalConnective, DiamondRelationalConnective
export Interval, Interval2D, Point, Point1D, Point2D, FullDimensionalFrame, diamond, box
export IA_A, IA_L, IA_B, IA_E, IA_D, IA_O, IA_Ai, IA_Li, IA_Bi, IA_Ei, IA_Di, IA_Oi
export token, op, tree, children, value, nchildren, arity, syntaxstring, hasdual, dual, relation
export formulas, subformulas, atoms, leaves, connectives, operators, ntokens, natoms, nleaves
export nconnectives, noperators, height, conjuncts, disjuncts, grandchildren, nconjuncts
export parseformula, check, interpret, frame, algebra, domain, top, bot, worlds, allworlds
export accessible, accessibles, worldtype
export Truth, BooleanTruth, TOP, BOT, ⊤, ⊥, istop, isbot, truths, collatetruth
export dnf, cnf, normalize, LeftmostLinearForm, LeftmostConjunctiveForm
export LeftmostDisjunctiveForm, DNF, CNF, Literal, AbstractInterpretationSet, ispos
export IARelations, RCC5Relations, alphabet, feature, condition, threshold, name, sample
export TruthDict, KripkeStructure
export ManyValuedLogics
for name in (:CL_N, :CL_S, :CL_E, :CL_W,
    :LRCC8_Rec_DC, :LRCC8_Rec_EC, :LRCC8_Rec_PO, :LRCC8_Rec_TPP,
    :LRCC8_Rec_TPPi, :LRCC8_Rec_NTPP, :LRCC8_Rec_NTPPi,
    :HS_A, :HS_L, :HS_B, :HS_E, :HS_D, :HS_O,
    :HS_Ai, :HS_Li, :HS_Bi, :HS_Ei, :HS_Di, :HS_Oi,
    :LTLFP_F, :LTLFP_P)
    @eval export $(name)
end

dnf(formula::Aletheia.Formula) = _wrap(Aletheia.dnf(_unwrap(formula)))
cnf(formula::Aletheia.Formula) = _wrap(Aletheia.cnf(_unwrap(formula)))

# Aletheia names useful to a consumer that is being migrated incrementally.
const FormulaPool = Aletheia.FormulaPool
const Signature = Aletheia.Signature
const parse = Aletheia.parse
const Model = Aletheia.Model
const Valuation = Aletheia.Valuation
const TruthAlgebra = Aletheia.TruthAlgebra
const BooleanAlgebra = Aletheia.BooleanAlgebra
const GodelAlgebra = Aletheia.GodelAlgebra
const LukasiewiczAlgebra = Aletheia.LukasiewiczAlgebra
export FormulaPool, Signature, atom, branch, parse, Model, Valuation, TruthAlgebra
export BooleanAlgebra, GodelAlgebra, LukasiewiczAlgebra
export ¬, ∧, ∨, →
const ¬ = Aletheia.:¬
const ∧ = Aletheia.:∧
const ∨ = Aletheia.:∨
const → = Aletheia.:→

end
