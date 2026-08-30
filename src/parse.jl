import Base: parse

struct _Token
    kind::Symbol
    text::String
end

function _tokenize(source::AbstractString, signature::Signature)
    operators = sort!(collect(notation.(signature.connectives)), by=length, rev=true)
    tokens = _Token[]
    chars = String(source)
    i = firstindex(chars)
    last = lastindex(chars)
    while i <= last
        c = chars[i]
        if isspace(c)
            i = nextind(chars, i)
            continue
        elseif c == '"'
            i = nextind(chars, i)
            buffer = IOBuffer()
            closed = false
            while i <= last
                c = chars[i]
                if c == '"'
                    i = nextind(chars, i)
                    closed = true
                    break
                elseif c == '\\'
                    i = nextind(chars, i)
                    i <= last || throw(ArgumentError("unterminated quoted atom"))
                    escaped = chars[i]
                    escaped == '"' || escaped == '\\' || throw(ArgumentError("unsupported escape in quoted atom"))
                    print(buffer, escaped)
                else
                    print(buffer, c)
                end
                i = nextind(chars, i)
            end
            closed || throw(ArgumentError("unterminated quoted atom"))
            push!(tokens, _Token(:atom, String(take!(buffer))))
            continue
        elseif c == '('
            push!(tokens, _Token(:lparen, "(")); i = nextind(chars, i); continue
        elseif c == ')'
            push!(tokens, _Token(:rparen, ")")); i = nextind(chars, i); continue
        elseif c == ','
            push!(tokens, _Token(:comma, ",")); i = nextind(chars, i); continue
        end
        matched = nothing
        for op in operators
            startswith(SubString(chars, i, last), op) && (matched = op; break)
        end
        if matched !== nothing
            push!(tokens, _Token(:operator, matched))
            i = nextind(chars, i, length(matched))
            continue
        end
        start = i
        while i <= last
            c = chars[i]
            if isspace(c) || c in ('(', ')', ',') || any(op -> startswith(SubString(chars, i, last), op), operators)
                break
            end
            i = nextind(chars, i)
        end
        i == start && throw(ArgumentError("cannot tokenize input near $(repr(chars[i:end]))"))
        push!(tokens, _Token(:atom, String(chars[start:prevind(chars, i)])))
    end
    push!(tokens, _Token(:end, ""))
    tokens
end

mutable struct _Parser{F}
    tokens::Vector{_Token}
    position::Int
    pool::FormulaPool
    bynotation::Dict{String,Any}
    atom_parser::F
end

@inline _current(parser::_Parser) = parser.tokens[parser.position]
@inline function _advance!(parser::_Parser)
    token = _current(parser)
    parser.position += 1
    token
end

function _parse_prefix!(parser::_Parser)
    token = _advance!(parser)
    if token.kind == :atom
        return atom(parser.pool, parser.atom_parser(token.text))
    elseif token.kind == :lparen
        result = _parse_expression!(parser, 0)
        _current(parser).kind == :rparen || throw(ArgumentError("expected ')'"))
        _advance!(parser)
        return result
    elseif token.kind == :operator
        connective = parser.bynotation[token.text]
        n = arity(parser.pool.signature, connective)
        if n == 0
            if _current(parser).kind == :lparen
                _advance!(parser)
                _current(parser).kind == :rparen || throw(ArgumentError("expected ')' after nullary connective"))
                _advance!(parser)
            end
            return branch(parser.pool, connective)
        elseif n == 1
            # A parenthesized unary call is accepted as well as prefix notation.
            if _current(parser).kind == :lparen
                _advance!(parser)
                child = _parse_expression!(parser, 0)
                _current(parser).kind == :rparen || throw(ArgumentError("expected ')' after unary connective"))
                _advance!(parser)
            else
                child = _parse_expression!(parser, precedence(connective))
            end
            return branch(parser.pool, connective, child)
        else
            _current(parser).kind == :lparen ||
                throw(ArgumentError("connective $(repr(token.text)) with arity $n needs function notation"))
            _advance!(parser)
            parsed = Any[]
            if _current(parser).kind != :rparen
                while true
                    push!(parsed, _parse_expression!(parser, 0))
                    _current(parser).kind == :comma || break
                    _advance!(parser)
                end
            end
            _current(parser).kind == :rparen || throw(ArgumentError("expected ')' after connective arguments"))
            _advance!(parser)
            length(parsed) == n || throw(ArgumentError("connective $(repr(token.text)) expects $n arguments"))
            return branch(parser.pool, connective, Tuple(parsed))
        end
    end
    throw(ArgumentError("unexpected token $(repr(token.text))"))
end

function _parse_expression!(parser::_Parser, minimum_precedence::Int)
    left = _parse_prefix!(parser)
    while true
        token = _current(parser)
        token.kind == :operator || break
        connective = parser.bynotation[token.text]
        arity(parser.pool.signature, connective) == 2 || break
        p = precedence(connective)
        p < minimum_precedence && break
        _advance!(parser)
        next_minimum = associativity(connective) == :right ? p : p + 1
        right = _parse_expression!(parser, next_minimum)
        left = branch(parser.pool, connective, left, right)
    end
    left
end

"""
    parse(pool, source; atom_parser=identity)

Parse a formula over the pool's signature.  Atoms are parsed by
`atom_parser`, which receives their token text and defaults to returning a
`String`; this keeps parsing independent of any semantic or truth-value type.
The parser is precedence-aware and accepts both infix binary notation and
prefix/function notation for higher-arity connectives.
"""
function parse(pool::FormulaPool, source::AbstractString; atom_parser=identity)
    bynotation = Dict{String,Any}()
    for connective in pool.signature.connectives
        text = notation(connective)
        haskey(bynotation, text) && throw(ArgumentError("duplicate connective notation $(repr(text))"))
        bynotation[text] = connective
    end
    parser = _Parser(_tokenize(source, pool.signature), 1, pool, bynotation, atom_parser)
    result = _parse_expression!(parser, 0)
    _current(parser).kind == :end || throw(ArgumentError("unexpected token $(repr(_current(parser).text))"))
    result
end

"""Parse with the pool as the second argument; a convenience spelling for [`parse`](@ref)."""
parse(source::AbstractString, pool::FormulaPool; kwargs...) = parse(pool, source; kwargs...)

"""
    parse(Formula, source; atom_parser=identity)

Parse a formula over [`DEFAULT_SIGNATURE`](@ref) into [`DEFAULT_POOL`](@ref).
Equivalent to `parse(DEFAULT_POOL, source)`.

The type argument is not decoration.  `parse` here is `Base.parse`, so a
one-argument `parse(::AbstractString)` method would be type piracy: it would
change what `parse("...")` means for every package loaded alongside Aletheia.
Dispatching on `Formula` keeps the method Aletheia's own and follows Base's
own `parse(T, string)` convention.
"""
parse(::Type{<:Formula}, source::AbstractString; kwargs...) = parse(DEFAULT_POOL, source; kwargs...)
