-- nes_state_audit.lua — sweep audit of NES_RAM cells.
-- Boot, ARM stress harness, idle, then dump raw state for ALL key
-- NES Z1 cells. Cross-check vs perma-zero patterns to find more
-- never-written/never-incremented bugs.
-- Output: C:\tmp\nes_audit\

local OUTDIR = "C:\\tmp\\nes_audit\\"
os.execute("mkdir " .. OUTDIR .. " 2>NUL")

local function press(buttons, frames)
    for i = 1, frames do joypad.set(buttons, 1); emu.frameadvance() end
end
local function idle(frames)
    for i = 1, frames do emu.frameadvance() end
end
local function nesram(off) return memory.read_u8(0x8000 + off, "68K RAM") end

-- Sample state at multiple timepoints to find advancing vs stuck cells.
local function snapshot()
    local s = {}
    for off = 0x0010, 0x00FF do s[off] = nesram(off) end
    for off = 0x0340, 0x04FF do s[off] = nesram(off) end
    for off = 0x0500, 0x05FF do s[off] = nesram(off) end
    for off = 0x0600, 0x07FF do s[off] = nesram(off) end
    return s
end

idle(60)
memory.write_u8(0x73FC, 0x45, "68K RAM")
memory.write_u8(0x73FD, 0x50, "68K RAM")
idle(60)
press({A=true, B=true, C=true}, 30)
idle(180)

local s_before = snapshot()
press({Down=true}, 30)
press({Right=true}, 30)
-- Plan v5a T1.4: capture mid-press snapshot so $FB ButtonsDown is
-- non-zero (held bits live only while joypad is held; edge bits in $FA
-- live for exactly one frame each press transition). Hold the chord
-- briefly and snapshot before idling clears the press.
joypad.set({A=true, Down=true}, 1); emu.frameadvance()
joypad.set({A=true, Down=true}, 1); emu.frameadvance()
local s_pressed = snapshot()
idle(180)
local s_after = snapshot()

local f = io.open(OUTDIR .. "audit.log", "w")
f:write("nes_state_audit — 2026-05-15\n")
f:write("===========================\n\n")
f:write("Cells that DID NOT change between snapshot1 (after settle) and\n")
f:write("snapshot2 (after walk + idle). Cells stuck across 240 frames =\n")
f:write("never written by gameplay tick. Suspicious if NES Z1 references\n")
f:write("them as per-frame mutable.\n\n")

local stuck = {}
local advancing = {}
for off, v in pairs(s_before) do
    if s_after[off] ~= v then
        advancing[#advancing + 1] = {off=off, before=v, after=s_after[off]}
    end
end
table.sort(advancing, function(x, y) return x.off < y.off end)

f:write(string.format("%d cells changed (out of %d sampled)\n\n",
    #advancing, 0x100 + 0x1C0 + 0x100 + 0x200))

f:write("--- ADVANCING cells (changed between snapshots) ---\n")
for _, e in ipairs(advancing) do
    f:write(string.format("  $%04X  $%02X -> $%02X\n", e.off, e.before, e.after))
end

f:write("\n--- KEY NES Z1 CELLS that should advance (probe samples) ---\n")
local key_cells = {
    {0x0010, "CurLevel"},
    {0x0011, "IsUpdatingMode"},
    {0x0012, "GameMode"},
    {0x0013, "GameSubmode"},
    {0x0014, "TileBufSelector"},
    {0x0015, "FrameCounter"},
    {0x0016, "CurSaveSlot"},
    {0x0018, "Random[0]"},
    {0x0019, "Random[1]"},
    {0x001A, "Random[2]"},
    {0x0026, "StunCycle"},
    {0x0027, "DoorTimer"},
    {0x0028, "ObjTimer[0]"},
    {0x0029, "ObjTimer[1]"},
    {0x002A, "ObjTimer[2]"},
    {0x003C, "FluteTimer"},
    {0x003D, "ObjStunTimer[0]"},
    {0x004A, "ChaseLongTimer"},
    {0x0070, "Link X (ObjX[0])"},
    {0x0084, "Link Y (ObjY[0])"},
    {0x0098, "Link face (ObjDir[0])"},        -- Plan v5a T1.3 (corrected addr)
    {0x00A5, "Link weapon-slot 13 dir"},      -- Plan v5 sword sync ($98+13)
    {0x00B9, "Link weapon-slot 13 state"},    -- Plan v5 sword sync ($AC+13)
    {0x0657, "ITEM_SWORD_LEVEL"},             -- Plan v5 (seeded =1)
    {0x00AC, "Link State (ObjState[0])"},
    {0x00BC, "Link Hearts? (ObjHP)"},
    {0x00EB, "RoomId"},
    {0x00F8, "ButtonsPressed (edge)"},        -- Plan v5a T1.1 (was $FA, corrected)
    {0x00FA, "ButtonsDown (held)"},           -- Plan v5a T1.1 (was $FB, corrected)
    {0x0341, "RollingSpriteIndex"},
    {0x052A, "WorldKillCycle"},
    {0x0660, "InvClock"},
    {0x066F, "HeartValues (hi=max,lo=cur)"},  -- Plan v5a T1.2
    {0x0670, "HeartPartial"},                  -- Plan v5a T1.2
    {0x07FE, "(probe sentinel)"},
    {0x07F0, "TitlePhase"},
}
for _, kc in ipairs(key_cells) do
    local before = s_before[kc[1]] or 0
    local pressed = s_pressed[kc[1]] or 0
    local after = s_after[kc[1]] or 0
    local changed = ((before ~= after) or (before ~= pressed)) and "ADVANCING" or "STUCK"
    f:write(string.format("  $%04X %-26s  pre=%02X  hold=%02X  post=%02X  %s\n",
        kc[1], kc[2], before, pressed, after, changed))
end

client.screenshot(OUTDIR .. "after.png")
f:close()
gui.text(8, 8, "nes audit done")
client.exit()
