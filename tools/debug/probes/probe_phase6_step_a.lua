-- probe_hud.lua — Phase 6 Task 6.10.6 Step A focused probe.
-- Boots through title chord into RoomRom, captures baseline HUD,
-- pokes g_inventory cells via memory.write_u8, captures second
-- screenshot to prove live-read picks up the change.

local OUT_DIR = "C:\\tmp\\"
local SHOT_BASE  = OUT_DIR .. "phase6_step_a_baseline.png"
local SHOT_POKED = OUT_DIR .. "phase6_step_a_poked.png"
local LOG        = OUT_DIR .. "phase6_step_a_focused.log"

local f = io.open(LOG, "w")
local function logln(s) if f then f:write(s .. "\n") end print(s) end

local CHORD = {A=true, B=true, C=true}
local INV_BASE = 0x001A   -- g_inventory in 68K RAM domain (low 16 bits of $FF001A)

local function dump_inv(label)
    local bytes = ""
    for off = 0, 31 do
        bytes = bytes .. string.format("%02X ",
            memory.read_u8(INV_BASE + off, "68K RAM"))
    end
    logln(label .. " " .. bytes)
end

-- Frames 1..30 idle on title.
for i = 1, 30 do emu.frameadvance() end

-- Hold chord 90 frames to enter gameplay.
for i = 1, 90 do
    joypad.set(CHORD, 1)
    emu.frameadvance()
end
-- Release.
for i = 1, 60 do emu.frameadvance() end

-- A few Start taps in case fs_main is in the way.
joypad.set({Start=true}, 1); emu.frameadvance()
joypad.set({}, 1)
for i = 1, 30 do emu.frameadvance() end
joypad.set({Start=true}, 1); emu.frameadvance()
joypad.set({}, 1)
for i = 1, 90 do emu.frameadvance() end

logln("== Phase 6 Step A focused probe ==")
logln(string.format("frame=%d", emu.framecount()))

dump_inv("baseline:")
client.screenshot(SHOT_BASE)
logln("baseline_shot=" .. SHOT_BASE)

-- Poke inventory cells.
-- Layout (m68k default alignment, no -fpack-struct):
--   0..18 : 19 chars (items..clock)
--   19    : pad
--   20-21 : short rupees
--   22    : keys
--   23    : heart_values  (hi=max, lo=cur)
--   24    : heart_partial
-- Try poking 19,20,21 = pad,rupees_hi,rupees_lo=0,42 -> rupees=42 (0x002A)
-- And keys=3, heart_values = 0x54 (max=5, cur=4), heart_partial = 0x80
memory.write_u8(INV_BASE + 20, 0x00, "68K RAM")  -- rupees hi
memory.write_u8(INV_BASE + 21, 0x2A, "68K RAM")  -- rupees lo = 42
memory.write_u8(INV_BASE + 22, 0x03, "68K RAM")  -- keys = 3
memory.write_u8(INV_BASE + 23, 0x54, "68K RAM")  -- hv = max5/cur4
memory.write_u8(INV_BASE + 24, 0x80, "68K RAM")  -- hp = half
-- Also try a bombs poke at offset 1 (right after items at 0).
memory.write_u8(INV_BASE + 1, 0x08, "68K RAM")   -- bombs = 8

-- Let the per-tick refresh repaint with new state.
for i = 1, 6 do emu.frameadvance() end

dump_inv("poked   :")
client.screenshot(SHOT_POKED)
logln("poked_shot=" .. SHOT_POKED)

if f then f:close() end
client.exit()
