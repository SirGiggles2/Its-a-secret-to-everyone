-- t37_input_scenario.lua
-- T37 sword-pickup parity: enter the cave, let the merchant dialog run,
-- ALIGN X WITH THE SWORD (critical!), then walk UP into the Y range that
-- fires pickup.
--
-- Pickup mechanic (reference/aldonunez/Z_01.asm:718-729):
--   For each cave ware slot X in 2..0:
--     if Link.ObjX == CaveWareXs[X]    (EXACT X match — no tolerance)
--        and abs(Link.ObjY - $98) < 6  (Y range [$92, $9D])
--     then trigger @PickedUp
--
-- Original scenario failed because it only held Up inside the cave. Link
-- spawns at x=$70 and the sword is at x=$78. Holding Up advances Y but
-- never aligns X, so CMP CaveWareXs,X fires BNE and the check loop skips
-- to @NextWare forever. Fix: interleave Right to align X before the
-- sword-approach Up phase.
--
-- Key state bytes:
--   $0012 GameMode  ($05 overworld, $10 stair, $0B cave)
--   $00EB RoomId    ($77 opening room)
--   $00AC ObjState[0] ($40 = halted by dialog, $00 = free movement)
--   $0657+[slot]    inventory array; $0657+0 = SWORD level
--
-- Observed timing (from an unreversed NES capture — see trace inspection):
--   t=349   mode $10 -> $0B (cave interior active)
--   t=350   Link at (x=$70, y=$D5), objstate=$40 (merchant dialog)
--   t=550   objstate -> $00 (dialog ended, Link can move)
--   sword at (x=$78, y=$80); walk speed ~1.25 px/f
--
-- Motion budget to reach pickup from cave spawn (x=$70, y=$D5):
--   ΔX  = $78 - $70 = 8 px → ≥7 frames Right at 1.25 px/f
--   ΔY  = $D5 - $98 = 61 px (need to land in [$92, $9D], target $98)
--       → ~49 frames Up. Allow generous slop for terrain collision bumps.
--
-- Scenario (1400 frames @ 60Hz = 23s):
--   T 000-059    baseline idle                           (60f)
--   T 060-100    hold Left  walk west to x=$40           (41f)
--   T 101-164    idle align-y                            (64f)
--   T 165-284    hold Up    walk north to stair          (120f)
--   T 285-560    cave-settle + merchant textbox          (276f)
--   T 560-585    hold Right align X with sword ($70→$78) ( 25f)
--   T 585-700    hold Up    walk UP into pickup Y range  (115f)
--   T 700-970    pickup-settle (sword-reveal + fanfare)  (270f)
--   T 970-1090   hold Down  walk back to exit stair      (120f)
--   T 1090-1250  post-exit idle (stair ascent + settle)  (160f)
--   T 1250-1399  final parity window                     (150f)

local M = {}

M.SCENARIO_LENGTH = 1400

M.PHASES = {
    { name = "baseline",      button = nil,     start_t = 0,    end_t = 60   },
    { name = "walk_left",     button = "Left",  start_t = 60,   end_t = 101  },
    { name = "align_y",       button = nil,     start_t = 101,  end_t = 165  },
    { name = "walk_up_cave",  button = "Up",    start_t = 165,  end_t = 285  },
    { name = "cave_settle",   button = nil,     start_t = 285,  end_t = 560  },
    { name = "align_x_sword", button = "Right", start_t = 560,  end_t = 585  },
    { name = "walk_to_sword", button = "Up",    start_t = 585,  end_t = 700  },
    { name = "pickup_settle", button = nil,     start_t = 700,  end_t = 970  },
    { name = "walk_down",     button = "Down",  start_t = 970,  end_t = 1090 },
    { name = "post_exit",     button = nil,     start_t = 1090, end_t = 1250 },
    { name = "final",         button = nil,     start_t = 1250, end_t = 1400 },
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
