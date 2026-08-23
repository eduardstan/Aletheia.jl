# Shared conventions for the rich `MIME"text/plain"` displays.
#
# Every rich display has the same shape: a bold header naming the type, a dim
# parenthetical summary giving its size, then indented sections whose labels
# are dim and whose content is plain.  Colour is emitted only when the IO
# context reports it, so redirected output and doctests stay plain text.
# Collections are truncated with an explicit elided count unless the context
# sets `:limit => false`.

const _DISPLAY_HEAD = :cyan
const _DISPLAY_DIM = :light_black
const _DISPLAY_TOP = :green
const _DISPLAY_BOT = :red

"""Number of items a rich display shows before eliding the rest."""
const DISPLAY_ITEMS = 10

_display_color(io::IO) = get(io, :color, false) === true

"""Print `text` in `color`, or plain when the IO context has no colour."""
function _styled(io::IO, text, color; bold::Bool=false)
    if color === :normal || !_display_color(io)
        print(io, text)
    else
        printstyled(io, text; color=color, bold=bold)
    end
end

"""Print a rich-display header: a bold type name and a dim parenthetical summary."""
function _display_header(io::IO, name::AbstractString, summary::AbstractString="")
    _styled(io, name, _DISPLAY_HEAD; bold=true)
    if !isempty(summary)
        print(io, " ")
        _styled(io, "($summary)", _DISPLAY_DIM)
    end
end

"""Start a new indented section line with a dim `label` followed by `separator`."""
function _display_label(io::IO, indent::Int, label::AbstractString, separator::AbstractString=": ")
    print(io, "\n", " "^indent)
    _styled(io, label, _DISPLAY_DIM)
    print(io, separator)
end

"""Return `limit`, or `typemax(Int)` when the IO context disables truncation."""
_display_limit(io::IO, limit::Int=DISPLAY_ITEMS) =
    get(io, :limit, true) === true ? limit : typemax(Int)

"""Return the leading `limit` items and the number omitted, honouring `:limit`."""
function _display_bounded(io::IO, items, limit::Int=DISPLAY_ITEMS)
    bound = _display_limit(io, limit)
    n = length(items)
    n > bound ? (items[1:bound], n - bound) : (items, 0)
end

"""Join `items` with `", "`, eliding everything past `limit` with a count."""
function _join_bounded(items, limit::Int)
    n = length(items)
    n <= limit && return join(items, ", ")
    string(join(items[1:limit], ", "), ", … (", n - limit, " elided)")
end

"""Print a dim inline `, … (n elided)` suffix when `n` items were omitted."""
function _display_elision(io::IO, n::Int)
    n == 0 || _styled(io, ", … ($n elided)", _DISPLAY_DIM)
    nothing
end

"""Print a dim `… (n elided)` line at `indent` when `n` items were omitted."""
function _display_elision_line(io::IO, indent::Int, n::Int)
    n == 0 && return nothing
    print(io, "\n", " "^indent)
    _styled(io, "… ($n elided)", _DISPLAY_DIM)
    nothing
end

"""Render a truth value for display; the fallback is its plain string form."""
_display_truth(::Any, value) = string(value)
