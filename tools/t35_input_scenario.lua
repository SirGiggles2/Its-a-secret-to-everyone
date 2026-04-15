-- t35_input_scenario.lua
-- Shared scripted input driver for T35 screen-scroll parity.
--
-- Both bizhawk_t35_scroll_nes_capture.lua and bizhawk_t35_scroll_gen_capture.lua
-- dofile this module so NES and Genesis see identical input frame-for-frame.
--
-- Contract:
--   T = 0 is the first frame AFTER the capture gate (Mode 5 / room $77 / Link
--   stable 60f) — same gate shape as the T34 scenario.
--   For each T in [0, SCENARIO_LENGTH), the capture probe calls
--   get_input_for_relative_frame(T) and passes the returned table to joypad.set.
--
-- Scenario (idle → walk left across room + scroll transition → settle):
--   T 000-059  baseline idle           (60 frames)
--   T 060-299  hold Left               (240 frames, walk west, trigger scroll)
--   T 300-479  idle during scroll      (180 frames, let Mode-7 submodes settle)
--   T 480-539  final idle in room $76  (60 frames, post-settle parity)
-- Total 540 frames.
--
-- The 240-frame Left hold is a first-pass estimate: Link walks at ~3/4 px per
-- frame, room-$77 starting X is ~$78, left wall is ~$08, so ~$70 px of travel
-- plus scroll-threshold slack. Tune via NES capture if Link stalls against
-- scenery before reaching the transition edge.

local M = {}

M.SCENARIO_LENGTH = 540

-- Phase boundaries (inclusive start, exclusive end). Single source of truth.
M.PHASES = {
    { name = "baseline",     button = nil,    start_t = 0,   end_t = 60  },
    { name = "walk_left",    button = "Left", start_t = 60,  end_t = 300 },
    { name = "scroll_wait",  button = nil,    start_t = 300, end_t = 480 },
    { name = "final_idle",   button = nil,    start_t = 480, end_t = 540 },
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
