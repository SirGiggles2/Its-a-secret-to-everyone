-- t37_input_scenario.lua
-- T37 sword-pickup parity: enter the cave (same as T36), then walk UP
-- into the sword at the center of the cave. The merchant offers the
-- sword when Link crosses y=$80 approx (NES position where the sword
-- pickup zone begins).
--
-- Key state bytes:
--   $0012 GameMode  ($05 overworld, $10 stair, $0B cave)
--   $00EB RoomId    ($77 opening room)
--   $0200 objstate  ($40 = dialog/merchant active, $00 = free movement)
--   $0657+[slot]    inventory array; $0657+0 = SWORD level (0=none, 1=wood, etc)
--
-- Coordinates from NES observation (t36_cave_nes_capture trace):
--   Link spawns inside cave at (x=$70, y=$D5) at t=300 (mode $0B).
--   Sword merchant near (x=$78, y=$80). Link walks up at ~1.25 px/frame.
--   D5 - 80 = 85 (133 px). 133/1.25 = ~107 frames to reach sword.
--
-- Scenario (1200 frames @ 60Hz = 20s):
--   T 000-059    baseline idle                 (60f)
--   T 060-100    hold Left   walk west to x=$40       (41f)
--   T 101-164    idle align-y                          (64f)
--   T 165-284    hold Up     walk north to stair      (120f)
--   T 285-360    cave-settle (enter + text)            (76f)
--   T 361-490    hold Up     walk into sword tile    (130f)
--   T 491-700    sword-pickup settle                  (210f)
--   T 701-820    hold Down   walk back to exit stair (120f)
--   T 821-1000   post-exit idle                       (180f)
--   T 1001-1199  final parity window                  (199f)

local M = {}

M.SCENARIO_LENGTH = 1200

M.PHASES = {
    { name = "baseline",     button = nil,    start_t = 0,    end_t = 60   },
    { name = "walk_left",    button = "Left", start_t = 60,   end_t = 101  },
    { name = "align_y",      button = nil,    start_t = 101,  end_t = 165  },
    { name = "walk_up_cave", button = "Up",   start_t = 165,  end_t = 285  },
    { name = "cave_settle",  button = nil,    start_t = 285,  end_t = 361  },
    { name = "walk_to_sword",button = "Up",   start_t = 361,  end_t = 491  },
    { name = "pickup_settle",button = nil,    start_t = 491,  end_t = 701  },
    { name = "walk_down",    button = "Down", start_t = 701,  end_t = 821  },
    { name = "post_exit",    button = nil,    start_t = 821,  end_t = 1001 },
    { name = "final",        button = nil,    start_t = 1001, end_t = 1200 },
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
