# Load boundaries are the midpoints between the recorded quiet and contaminated runs.
# The quiet run peaked at 4.81 (a seed sample) and rose -0.78; the contaminated
# run peaked at 9.54 (the ending 1-minute load) and rose 5.90. The gate uses
# those raw-load midpoints; the caller supplies the measured core count so the
# recorded diagnostics never assume a hardcoded core count.
const LOAD_GATE_QUIET_PEAK = 4.81
const LOAD_GATE_CONTAMINATED_PEAK = 9.54
const LOAD_GATE_QUIET_RISE = 2.98 - 3.76
const LOAD_GATE_CONTAMINATED_RISE = 9.54 - 3.64
# Decimal forms of the two midpoints above; using the decimal values keeps the
# inclusive boundary stable when Float64 values are compared.
const LOAD_GATE_PEAK_LIMIT_RAW = 7.175 # (4.81 + 9.54) / 2
const LOAD_GATE_RISE_LIMIT_RAW = 2.56 # (-0.78 + 5.90) / 2
"""Return the load-based publishability verdict for one benchmark run.

`start_load`, `end_load`, and `seed_loads` are the recorded 1-minute load
values. `cores` is supplied by the caller so this remains a pure function of
the recorded values and the machine's measured core count."""
function benchmark_load_verdict(start_load, end_load, seed_loads, cores::Integer)
    cores > 0 || throw(ArgumentError("core count must be positive"))
    start_load === missing && return (publishable=false, reason=:missing_start_load,
        peak_load=missing, rise=missing, peak_per_core=missing, rise_per_core=missing,
        peak_limit=missing, rise_limit=missing)
    end_load === missing && return (publishable=false, reason=:missing_end_load,
        peak_load=missing, rise=missing, peak_per_core=missing, rise_per_core=missing,
        peak_limit=missing, rise_limit=missing)
    isfinite(start_load) || return (publishable=false, reason=:invalid_start_load,
        peak_load=missing, rise=missing, peak_per_core=missing, rise_per_core=missing,
        peak_limit=missing, rise_limit=missing)
    isfinite(end_load) || return (publishable=false, reason=:invalid_end_load,
        peak_load=missing, rise=missing, peak_per_core=missing, rise_per_core=missing,
        peak_limit=missing, rise_limit=missing)

    samples = Float64[start_load, end_load]
    append!(samples, Float64[value for value in seed_loads
        if value !== missing && isfinite(value)])
    peak_load = maximum(samples)
    rise = end_load - start_load
    peak_per_core = peak_load / cores
    rise_per_core = rise / cores
    peak_limit_raw = LOAD_GATE_PEAK_LIMIT_RAW
    rise_limit_raw = LOAD_GATE_RISE_LIMIT_RAW
    peak_limit = peak_limit_raw / cores
    rise_limit = rise_limit_raw / cores
    # Compare raw loads so decimal midpoint boundaries remain inclusive despite
    # floating-point rounding; the equivalent per-core values are recorded.
    publishable = peak_load <= peak_limit_raw && rise <= rise_limit_raw
    reason = publishable ? :acceptable : peak_load > peak_limit_raw ? :peak_load : :load_rise
    (publishable=publishable, reason=reason, peak_load=peak_load, rise=rise,
        peak_per_core=peak_per_core, rise_per_core=rise_per_core,
        peak_limit=peak_limit, rise_limit=rise_limit)
end

function parse_load_average(uptime_text)
    match = Base.match(r"load average: ([0-9]+(?:\.[0-9]+)?)", uptime_text)
    match === nothing ? missing : parse(Float64, match.captures[1])
end
