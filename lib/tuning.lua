local Tuning = {}
Tuning.__index = Tuning

local function log2(x) return math.log(x) / math.log(2) end

-- ratios: array from .scl parser — index 1..N, where ratios[N] is the period (usually 2.0).
-- Unison (degree 0) is implicit and not stored.
function Tuning.new(ratios)
    local t = setmetatable({}, Tuning)
    t.ratios = ratios
    t.n = #ratios
    t.period = ratios[#ratios]
    return t
end

function Tuning:degree_ratio(degree)
    local oct = math.floor(degree / self.n)
    local within = degree % self.n
    local ratio = within == 0 and 1.0 or self.ratios[within]
    return ratio * self.period ^ oct
end

function Tuning:note_freq(midi_note, root_note, root_hz)
    return root_hz * self:degree_ratio(midi_note - root_note)
end

-- Returns cents deviation of midi_note from standard 12-TET pitch.
function Tuning:pitch_bend_cents(midi_note, root_note)
    local degree = midi_note - root_note
    local tuned_ratio = self:degree_ratio(degree)
    local std_ratio = 2 ^ (degree / 12)
    return 1200 * log2(tuned_ratio / std_ratio)
end

-- Returns MIDI pitch bend value [0, 16383], center = 8192 (no bend).
function Tuning:pitch_bend_value(midi_note, root_note, pb_range_semitones)
    local cents = self:pitch_bend_cents(midi_note, root_note)
    local pb = 8192 + math.floor(cents / (pb_range_semitones * 100) * 8192 + 0.5)
    return math.max(0, math.min(16383, pb))
end

return Tuning
