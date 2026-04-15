-- t36_input_scenario.lua
-- T36 cave-enter parity: enter the cave at (x=$40, y=$4D) in room $77
-- (north-west stair of the starting overworld room). Coordinates + mode
-- chain confirmed by tools/bizhawk_t36_state_log.lua user playthrough:
--
--   f01530 gameplay Mode5 room $77 Link=($78,$8D)
--   f01548 Left hold: Link walks west ($78 -> $42, ~40 frames)
--   f01589 Up hold: Link walks north ($8D -> $4D, ~50 frames)
--   f01639 mode $05 -> $10 (cave-stair descent triggers at Link=$40,$4D)
--   f01704 mode $10 -> $0B (scroll into cave interior)
--   f01990 inside cave, Link at ($70,$D7), Down starts
--   f01995 mode $0B -> $0A (exit stair triggers)
--   f02029 mode $04 (fade/init)
--   f02092 back to Mode5 room $77 Link=($40,$4D) (outside stair)
--
-- Scenario (840 frames @ 60Hz = 14s):
--   T 000-059   baseline idle          (60f)
--   T 060-179   hold Left              (120f) walk west to x=$40
--   T 180-239   idle                   (60f)  align y
--   T 240-359   hold Up                (120f) walk north to stair + trigger
--   T 360-599   idle inside cave       (240f) cave-interior parity window
--   T 600-719   hold Down              (120f) exit stair (auto via Down)
--   T 720-839   post_exit idle in $77  (120f) final parity

local M = {}

M.SCENARIO_LENGTH = 840

-- Tuned 2026-04-15 after first NES pass: 120f Left overshot west edge
-- into room $76 scroll at t=150. Link walks ~1.25 px/frame; reducing
-- Left to 45 frames targets x=$40 (stair col) without triggering scroll.
M.PHASES = {
    { name = "baseline",    button = nil,    start_t = 0,   end_t = 60  },
    { name = "walk_left",   button = "Left", start_t = 60,  end_t = 101 },
    { name = "align_y",     button = nil,    start_t = 101, end_t = 165 },
    { name = "walk_up",     button = "Up",   start_t = 165, end_t = 285 },
    { name = "cave_settle", button = nil,    start_t = 285, end_t = 645 },
    { name = "walk_down",   button = "Down", start_t = 645, end_t = 765 },
    { name = "post_exit",   button = nil,    start_t = 765, end_t = 840 },
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
            name = p.name, button = p.button,
            start_t = p.start_t, end_t = p.end_t,
        }
    end
    return out
end

return M
