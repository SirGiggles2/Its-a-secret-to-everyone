-- boot_sequence.lua — shared fresh-boot-to-gameplay macro recorded 2026-04-19.
-- Returns a state machine that drives the emulator from title through
-- file-select → register-name → save → overworld spawn at $77 → walk to
-- a target room (default $73).
--
-- Recorded input sequence (user playthrough):
--   frame 107-110:  Start (dismiss title attract)
--   frame 164-168:  Start (enter register name — Mode $0E)
--   frame 204-234:  A three times  (type a character)
--   frame 257-285:  C three times  (confirm char + cycle END)
--   frame 304-306:  Start (commit END, back to Mode 1 file select)
--   frame 349-352:  Start (start game)
--   frame 530+:     Left held (walk from $77 to target room)
--
-- Usage from another lua probe:
--   local boot = require "boot_sequence"
--   boot.drive(frame, target_room)   -- call each emu frame
--   -- returns "booting" | "walking" | "arrived"
--
-- Since BizHawk's lua 'require' path is hostile, inline this file
-- instead of requiring it. Pattern:
--   dofile("C:\\tmp\\boot_sequence.lua")   -- loads boot_sequence_drive()

local BUS = 0xFF0000

boot_sequence = {}

-- Absolute emu-frame schedule (button held from start_frame through
-- end_frame inclusive). Frames between entries are idle.
boot_sequence.schedule = {
    { sf=107, ef=110, btn="Start" },
    { sf=164, ef=168, btn="Start" },
    { sf=204, ef=208, btn="A"     },
    { sf=217, ef=221, btn="A"     },
    { sf=229, ef=234, btn="A"     },
    { sf=257, ef=260, btn="C"     },
    { sf=270, ef=273, btn="C"     },
    { sf=282, ef=285, btn="C"     },
    { sf=304, ef=306, btn="Start" },
    { sf=349, ef=352, btn="Start" },
}

-- Fallback margin in case a press misses: if by frame 400 we haven't
-- reached mode 5, nudge with extra Starts.
boot_sequence.gameplay_deadline = 500

-- Returns a button name (or nil) for this emu frame.
function boot_sequence.button_for_frame(frame)
    for _, s in ipairs(boot_sequence.schedule) do
        if frame >= s.sf and frame <= s.ef then return s.btn end
    end
    return nil
end

-- Build a joypad pad table for a button.
function boot_sequence.pad_for_button(btn)
    if not btn then return {} end
    return { [btn] = true, ["P1 " .. btn] = true }
end

-- Safe joypad.set wrapper.
function boot_sequence.safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then pcall(function() joypad.set(pad or {}) end) end
end

-- Drive one frame. Return status: "booting" | "walking" | "arrived".
function boot_sequence.drive(frame, target_room)
    target_room = target_room or 0x73
    local mode = memory.read_u8(BUS + 0x12, "M68K BUS")
    local lvl  = memory.read_u8(BUS + 0x10, "M68K BUS")
    local rid  = memory.read_u8(BUS + 0xEB, "M68K BUS")

    -- Arrival check.
    if mode == 0x05 and lvl == 0 and rid == target_room then
        boot_sequence.safe_set({})
        return "arrived"
    end

    -- Walking phase: mode 5 at OW but not at target.
    if mode == 0x05 and lvl == 0 then
        boot_sequence.safe_set({ Left = true, ["P1 Left"] = true })
        return "walking"
    end

    -- Boot phase: follow schedule; fallback to extra Start if late.
    local btn = boot_sequence.button_for_frame(frame)
    if btn then
        boot_sequence.safe_set(boot_sequence.pad_for_button(btn))
    elseif frame > boot_sequence.gameplay_deadline and (frame % 60) == 0 then
        boot_sequence.safe_set(boot_sequence.pad_for_button("Start"))
    else
        boot_sequence.safe_set({})
    end
    return "booting"
end
