local Tuning = {}
Tuning.__index = Tuning

local function log2(x) return math.log(x) / math.log(2) end

-- ratios: array from .scl parser — index 1..N, where ratios[N] is the period (usually 2.0).
-- Unison (degree 0 = 1/1) is implicit and not included.
--
-- Pitch calculation uses a nearest-pitch search in cents space, so scales with any
-- number of degrees work correctly with 12-TET MIDI input.
function Tuning.new(ratios)
    local t = setmetatable({}, Tuning)
    t.period = ratios[#ratios]
    t.period_cents = 1200 * log2(t.period)

    -- Build sorted list of {cents, ratio} for all degrees within one period.
    -- Include unison (0 cents) and exclude the period endpoint itself
    -- (it equals unison of the next period).
    local degrees = {{cents = 0, ratio = 1.0}}
    for i = 1, #ratios - 1 do
        table.insert(degrees, {cents = 1200 * log2(ratios[i]), ratio = ratios[i]})
    end
    table.sort(degrees, function(a, b) return a.cents < b.cents end)
    t.degrees = degrees

    return t
end

-- Find the scale degree (within one period) nearest to within_cents.
local function nearest_degree(degrees, within_cents)
    local best = degrees[1]
    local best_dist = math.abs(degrees[1].cents - within_cents)
    for i = 2, #degrees do
        local dist = math.abs(degrees[i].cents - within_cents)
        if dist < best_dist then
            best_dist = dist
            best = degrees[i]
        end
    end
    return best
end

-- Map a MIDI note to its tuned frequency.
function Tuning:note_freq(midi_note, root_note, root_hz)
    local note_cents = (midi_note - root_note) * 100
    local oct = math.floor(note_cents / self.period_cents)
    local within_cents = note_cents - oct * self.period_cents
    local d = nearest_degree(self.degrees, within_cents)
    return root_hz * d.ratio * self.period ^ oct
end

-- Returns cents deviation of midi_note from its standard 12-TET pitch.
function Tuning:pitch_bend_cents(midi_note, root_note)
    local note_cents = (midi_note - root_note) * 100
    local oct = math.floor(note_cents / self.period_cents)
    local within_cents = note_cents - oct * self.period_cents
    local d = nearest_degree(self.degrees, within_cents)
    return (oct * self.period_cents + d.cents) - note_cents
end

-- Returns MIDI pitch bend value [0, 16383], center = 8192 (no bend).
function Tuning:pitch_bend_value(midi_note, root_note, pb_range_semitones)
    local cents = self:pitch_bend_cents(midi_note, root_note)
    local pb = 8192 + math.floor(cents / (pb_range_semitones * 100) * 8192 + 0.5)
    return math.max(0, math.min(16383, pb))
end

return Tuning
