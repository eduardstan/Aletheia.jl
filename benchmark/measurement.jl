"""A single benchmark case outcome.

A missing time is never a measurement: `status` records whether the child timed
out or failed, so those outcomes cannot be mistaken for an empty result.
"""
struct Measurement
    time::Union{Missing,Float64}
    allocs::Union{Missing,Int}
    memory::Union{Missing,Int}
    note::String
    load::Union{Missing,Float64}
    status::Symbol
end

function _measurement_status(time, note)
    time !== missing && return :measured
    startswith(lowercase(String(note)), "timeout") && return :timeout
    :failed
end
Measurement(time, allocs, memory) = Measurement(time, allocs, memory, "", missing,
    _measurement_status(time, ""))
Measurement(time, allocs, memory, note::AbstractString) = Measurement(time, allocs, memory,
    String(note), missing, _measurement_status(time, note))
Measurement(time, allocs, memory, note::AbstractString, load) = Measurement(time, allocs, memory,
    String(note), load, _measurement_status(time, note))
Measurement(time, allocs, memory, note::AbstractString, load, status::Symbol) =
    Measurement(time, allocs, memory, String(note), load, status)

is_measured(m::Measurement) = m.status === :measured && m.time !== missing
is_timeout_exitcode(exitcode) = exitcode in (124, 137, 143)

function benchmark_measurement_verdict(measurements)
    publishable = all(is_measured, measurements)
    return (
        publishable=publishable,
        reason=publishable ? :none : :failed_or_incomplete_measurement,
    )
end

function outcome_summary(measurements)
    total = length(measurements)
    failed = count(m -> m.status === :failed, measurements)
    timed_out = count(m -> m.status === :timeout, measurements)
    measured = count(is_measured, measurements)
    if failed > 0
        failure = findfirst(m -> m.status === :failed, measurements)
        note = measurements[failure].note
        suffix = measured > 0 || timed_out > 0 ? "; $(measured) measured, $(timed_out) timed out" : ""
        return "failed ($(failed)/$(total) seeds): $(note)$(suffix)"
    elseif timed_out > 0
        suffix = measured > 0 ? "; $(measured) measured" : ""
        return "timed out ($(timed_out)/$(total) seeds)$(suffix)"
    end
    nothing
end

function combine_measurements(first_measurement, second_measurement)
    is_measured(first_measurement) && is_measured(second_measurement) &&
        return Measurement(first_measurement.time + second_measurement.time, missing, missing,
            "", missing, :measured)
    if first_measurement.status === :failed
        return Measurement(missing, missing, missing, first_measurement.note, missing, :failed)
    elseif second_measurement.status === :failed
        return Measurement(missing, missing, missing, second_measurement.note, missing, :failed)
    end
    note = isempty(first_measurement.note) ? second_measurement.note : first_measurement.note
    Measurement(missing, missing, missing, note, missing, :timeout)
end
