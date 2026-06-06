local Tuning = {}
Tuning.__index = Tuning

local function log2(x) return math.log(x) / math.log(2) end

-- ratios: array from .scl parser — index 1..N, where ratios[N] is the period (usually 2.0).
-- Unison (degree 0 = 1/1) is implicit and not included.
--
-- Linear key mapping: MIDI key (root + n) plays scale degree n.
-- After N keys the period repeats (e.g. a 5-note scale octavates every 5 keys).
-- Works correctly for negative degrees (keys below root).
function Tuning.new(ratios)
    local t = setmetatable({}, Tuning)
    t.ratios = ratios
    t.n = #ratios        -- scale degrees per period (includes period itself)
    t.period = ratios[#ratios]
    return t
end

-- Frequency ratio for scale degree n relative to root (can be negative or > n).
function Tuning:degree_ratio(degree)
    local oct = math.floor(degree / self.n)
    local within = degree % self.n
    local ratio = within == 0 and 1.0 or self.ratios[within]
    return ratio * self.period ^ oct
end

-- Tuned frequency for a MIDI note.
function Tuning:note_freq(midi_note, root_note, root_hz)
    return root_hz * self:degree_ratio(midi_note - root_note)
end

-- Cents deviation of midi_note from its 12-TET pitch, given linear key mapping.
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

-- Coarse + fine tuning: returns (coarse_note, pb_value).
-- coarse_note is the nearest 12-TET MIDI note to the target pitch.
-- pb_value is the residual fine-tuning bend (always <= ±50 cents,
-- so PB range 1-2 semitones is always sufficient for any scale).
-- ref_note: MIDI note used as coarse pitch anchor. Defaults to root_note (adjusting
-- mode: coarse lookup tracks the 12-TET pitch of root_note).
function Tuning:coarse_and_bend(midi_note, root_note, pb_range_semitones, ref_note)
    ref_note = ref_note or root_note
    local degree = midi_note - root_note
    local target_cents = 1200 * log2(self:degree_ratio(degree))
    local nearest_semitone = math.floor(target_cents / 100 + 0.5)
    local fine_cents = target_cents - nearest_semitone * 100
    local coarse_note = math.max(0, math.min(127, ref_note + nearest_semitone))
    local pb = 8192 + math.floor(fine_cents / (pb_range_semitones * 100) * 8192 + 0.5)
    return coarse_note, math.max(0, math.min(16383, pb))
end

return Tuning
