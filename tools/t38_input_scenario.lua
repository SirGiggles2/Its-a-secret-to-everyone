-- t38_input_scenario.lua
-- T38 enemy-AI parity (phase 1: spawn-position only).
--
-- From baseline in room $77, hold Left long enough to cross the west
-- transition into room $76 and settle. Room $76 has Octoroks — we want to
-- capture byte-parity of enemy object slots (id, x, y) at spawn time on
-- both NES and Genesis. Hitting with sword is deferred to phase 2.
--
-- Scenario frame budget (720 frames @ 60Hz = 12s):
--   T 000-059   baseline idle (no buttons)
--   T 060-239   hold Left  (180 frames — cross $77 -> $76 transition)
--   T 240-419   transition_settle (180 frames — let $76 finish loading)
--   T 420-719   observe_enemy (idle 300 frames — sample enemy slots)

local M = {}

M.SCENARIO_LENGTH = 720

M.PHASES = {
    { name = "baseline",           button = nil,    start_t = 0,   end_t = 60  },
    { name = "walk_left",          button = "Left", start_t = 60,  end_t = 240 },
    { name = "transition_settle",  button = nil,    start_t = 240, end_t = 420 },
    { name = "observe_enemy",      button = nil,    start_t = 420, end_t = 720 },
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
