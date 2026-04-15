-- t34_input_scenario.lua
-- Shared scripted D-pad input driver for T34 movement parity.
--
-- Both bizhawk_t34_movement_nes_capture.lua and bizhawk_t34_movement_gen_capture.lua
-- dofile this module so NES and Genesis see identical input frame-for-frame.
--
-- Contract:
--   T = 0 is the first frame AFTER the capture gate (Mode 5 / room $77 / Link stable 60f).
--   For each T in [0, SCENARIO_LENGTH), the capture probe calls
--   get_input_for_relative_frame(T) and passes the returned table to joypad.set(pad, 1).
--
-- Scenario (square walk + settle):
--   T 000-059  baseline idle  (no buttons)
--   T 060-119  hold Right     (60 frames, +X)
--   T 120-134  settle         (15 frames, no buttons)
--   T 135-194  hold Down      (60 frames, +Y)
--   T 195-209  settle         (15 frames)
--   T 210-269  hold Left      (60 frames, -X)
--   T 270-284  settle         (15 frames)
--   T 285-344  hold Up        (60 frames, -Y)
--   T 345-360  final idle     (16 frames)
-- Total 361 frames.
--
-- Round-trip property: equal hold times in opposing directions should leave
-- Link within a small neighbourhood of baseline (collision permitting).

local M = {}

M.SCENARIO_LENGTH = 361

-- Phase boundaries (inclusive start, exclusive end). Single source of truth.
M.PHASES = {
    { name = "baseline", button = nil,     start_t = 0,   end_t = 60  },
    { name = "right",    button = "Right", start_t = 60,  end_t = 120 },
    { name = "settle1",  button = nil,     start_t = 120, end_t = 135 },
    { name = "down",     button = "Down",  start_t = 135, end_t = 195 },
    { name = "settle2",  button = nil,     start_t = 195, end_t = 210 },
    { name = "left",     button = "Left",  start_t = 210, end_t = 270 },
    { name = "settle3",  button = nil,     start_t = 270, end_t = 285 },
    { name = "up",       button = "Up",    start_t = 285, end_t = 345 },
    { name = "final",    button = nil,     start_t = 345, end_t = 361 },
}

function M.phase_for_relative_frame(t)
    for i = 1, #M.PHASES do
        local p = M.PHASES[i]
        if t >= p.start_t and t < p.end_t then
            return p
        end
    end
    return nil
end

function M.get_input_for_relative_frame(t)
    local pad = {}
    local p = M.phase_for_relative_frame(t)
    if p and p.button then
        pad[p.button] = true
    end
    return pad
end

-- Return list of (name, start_t, end_t, button) tuples — used by the Python
-- comparator to group per-phase diagnostics. Emitted into the JSON capture
-- metadata so consumers don't need to reimplement the phase table.
function M.phase_summary()
    local out = {}
    for i = 1, #M.PHASES do
        local p = M.PHASES[i]
        out[#out + 1] = {
            name = p.name,
            button = p.button,
            start_t = p.start_t,
            end_t = p.end_t,
        }
    end
    return out
end

return M
