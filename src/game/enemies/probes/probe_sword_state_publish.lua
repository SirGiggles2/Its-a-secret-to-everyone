-- probe_sword_state_publish.lua — verify nes_ram_sync_sword writes
-- NES weapon slot 13 ($00B9 = OBJ_STATE_BASE $00AC + slot 13) to state $02.
-- v2: prior version sampled $00BC (slot 16, wrong); corrected to $00B9.
--
-- If state==2 EVER fires → sync is correct, combat just needs Link-adjacent.
-- If state==2 NEVER fires → real bug in roomrom_combat_get_swing_state
--   or nes_ram_sync_sword call ordering.
--
-- Output: C:\tmp\probe_sword_state_publish.txt + screenshot.

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT = "C:\\tmp\\probe_sword_state_publish.txt"
local f = io.open(OUT, "w")
f:write("probe_sword_state_publish\n=========================\n\n")

-- Boot + debug enter (chord A+B+C).
idle(40)
press({A=true, B=true, C=true}, 30)
idle(60)

f:write(string.format("post-enter frame=%d GameMode=$%02X Link=($%02X,$%02X) RoomId=$%02X face=$%02X\n\n",
    emu.framecount(), R(0x0012), R(0x0070), R(0x0084), R(0x00EB), R(0x008C)))

-- Sample $00BC (NES weapon slot 13 OBJ_STATE) every frame for 120 frames
-- while mashing A.  Histogram + first-state-2 frame.
local hist = {}
for s=0,15 do hist[s] = 0 end
local first_state2 = -1
local sword_x_at_state2 = -1
local sword_y_at_state2 = -1
local sword_dir_at_state2 = -1

f:write("== A-mash 120 frames ==\n")
for i=1,120 do
    if (i % 2) == 1 then joypad.set({A=true}, 1) else joypad.set({}, 1) end
    emu.frameadvance()
    local s = R(0x00B9)
    if s < 16 then hist[s] = hist[s] + 1 end
    if s == 2 and first_state2 < 0 then
        first_state2 = i
        sword_x_at_state2 = R(0x007D)
        sword_y_at_state2 = R(0x0091)
        sword_dir_at_state2 = R(0x00A5)
    end
    -- Log first 20 frames as raw trace.
    if i <= 20 then
        f:write(string.format("  f+%02d: B9=$%02X (sword_state) 7D=$%02X (sword_x) 91=$%02X (sword_y) A5=$%02X (sword_dir)\n",
            i, s, R(0x007D), R(0x0091), R(0x00A5)))
    end
end

f:write("\n== Histogram of $00B9 (sword OBJ_STATE slot 13) over 120 frames ==\n")
for s=0,15 do
    if hist[s] > 0 then f:write(string.format("  state $%02X : %d frames\n", s, hist[s])) end
end

f:write(string.format("\nfirst frame with state==2: %d\n", first_state2))
if first_state2 > 0 then
    f:write(string.format("  sword pose at state-2: dir=$%02X xy=($%02X,$%02X)\n",
        sword_dir_at_state2, sword_x_at_state2, sword_y_at_state2))
    f:write(string.format("  Link at that moment: xy=($%02X,$%02X) face=$%02X\n",
        R(0x0070), R(0x0084), R(0x008C)))
end

f:write("\n== VERDICT ==\n")
if hist[2] > 0 then
    f:write(string.format("GREEN: sword state==2 fired on %d frames - sync IS working.\n", hist[2]))
    f:write("Combat probe RED = Link approach navigation failure, not sync bug.\n")
else
    f:write("RED: sword state==2 NEVER fired during 120 frames of A-mash.\n")
    f:write("Bug in roomrom_combat_get_swing_state OR nes_ram_sync_sword call ordering.\n")
end

client.screenshot("C:\\tmp\\probe_sword_state_publish.png")
f:close()
client.exit()
