-- t36_input_scenario.lua
-- Shared scripted input driver for T36 cave-enter parity.
--
-- Builds on T35 scenario: starts from the baseline gate (Mode 5, room $77,
-- Link stable 60f), walks left into room $76, then navigates to the cave
-- stair in room $76, descends into the cave interior, stays briefly, and
-- walks back out.
--
-- Cave stair in room $76 (Level 0 overworld Q1) is at screen coords
-- (Link_x ~ $70, Link_y ~ $8D). After the T35 scroll settles, Link is at
-- ($B2, $8D), same row as the stair. Plan:
--   T 000-059   baseline idle          (60f)        gate verification
--   T 060-299   hold Left              (240f)       walk across + scroll
--   T 300-479   idle during scroll     (180f)       mode-7 submodes settle
--   T 480-539   final idle room $76    (60f)        post-scroll verify
--   T 540-659   hold Left              (120f)       walk west to stair x~$70
--   T 660-719   idle                   (60f)        align / pause
--   T 720-839   hold Down              (120f)       descend stair → cave
--   T 840-1079  idle in cave           (240f)       cave-mode settle + parity
--   T 1080-1199 hold Up                (120f)       exit cave via stair
--   T 1200-1319 idle back in room $76  (120f)       post-exit parity
-- Total 1320 frames (~22s @ 60Hz).
--
-- Stair coord tuning: run NES capture first; if Link walks past the stair
-- or stops short, adjust the T=540-659 walk_west phase length. Cave mode
-- id on NES = $06 (dungeon/cave) per Zelda convention; confirm from the
-- capture trace.

local M = {}

M.SCENARIO_LENGTH = 1320

M.PHASES = {
    { name = "baseline",        button = nil,    start_t = 0,    end_t = 60   },
    { name = "walk_left_a",     button = "Left", start_t = 60,   end_t = 300  },
    { name = "scroll_wait",     button = nil,    start_t = 300,  end_t = 480  },
    { name = "settle_76",       button = nil,    start_t = 480,  end_t = 540  },
    { name = "walk_left_b",     button = "Left", start_t = 540,  end_t = 660  },
    { name = "align_stair",     button = nil,    start_t = 660,  end_t = 720  },
    { name = "descend",         button = "Down", start_t = 720,  end_t = 840  },
    { name = "cave_settle",     button = nil,    start_t = 840,  end_t = 1080 },
    { name = "exit_stair",      button = "Up",   start_t = 1080, end_t = 1200 },
    { name = "post_exit",       button = nil,    start_t = 1200, end_t = 1320 },
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
