-- t38_input_scenario.lua
-- T38 enemy-AI parity: extends T37 sword pickup, then walks Link EAST out
-- of room $77 into room $78 to observe enemy spawn + AI + damage response.
--
-- Rationale: T37 proves Link can acquire the sword; T38 proves enemies
-- spawn and behave identically NES vs Gen. Room $78 is the first
-- east-adjacent overworld screen. Unlike room $76 (left-adjacent, which
-- still has ROUTE_TRANSITION_SETTLE), the right transition has never been
-- exercised and should be independent of the left-transition regression.
--
-- Scenario frame budget (2400 frames @ 60Hz = 40s):
--   T 000-1400   identical to T37 (sword pickup + cave exit)
--   T 1400-1500  idle, let Mode5 re-settle in $77
--   T 1500-1620  hold Right, walk east across $77 (x=$40 -> ~x=$F0)
--   T 1620-1700  transition_settle ($77 -> $78)
--   T 1700-1820  idle in $78, sample enemy object slots
--   T 1820-1940  hold B (sword swing) to trigger enemy-damage logic
--   T 1940-2100  pickup_settle (kill reward / rupee collection)
--   T 2100-2400  final parity window

local M = {}

M.SCENARIO_LENGTH = 2400

M.PHASES = {
    { name = "baseline",       button = nil,     start_t = 0,    end_t = 60   },
    { name = "walk_left",      button = "Left",  start_t = 60,   end_t = 101  },
    { name = "align_y",        button = nil,     start_t = 101,  end_t = 165  },
    { name = "walk_up_cave",   button = "Up",    start_t = 165,  end_t = 285  },
    { name = "cave_settle",    button = nil,     start_t = 285,  end_t = 560  },
    { name = "align_x_sword",  button = "Right", start_t = 560,  end_t = 565  },
    { name = "walk_to_sword",  button = "Up",    start_t = 565,  end_t = 700  },
    { name = "pickup_settle",  button = nil,     start_t = 700,  end_t = 970  },
    { name = "walk_down",      button = "Down",  start_t = 970,  end_t = 1090 },
    { name = "post_exit",      button = nil,     start_t = 1090, end_t = 1400 },
    { name = "resettle_77",    button = nil,     start_t = 1400, end_t = 1500 },
    { name = "walk_east",      button = "Right", start_t = 1500, end_t = 1620 },
    { name = "transition_78",  button = nil,     start_t = 1620, end_t = 1700 },
    { name = "observe_enemy",  button = nil,     start_t = 1700, end_t = 1820 },
    { name = "sword_swing",    button = "B",     start_t = 1820, end_t = 1940 },
    { name = "kill_settle",    button = nil,     start_t = 1940, end_t = 2100 },
    { name = "final",          button = nil,     start_t = 2100, end_t = 2400 },
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
