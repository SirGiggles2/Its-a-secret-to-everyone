-- probe_combat_stress.lua — arm stress harness so 11 enemies spawn
-- in slot 1..11; A-mash 200 frames; track HP per slot per frame; report
-- first HP-drop event.
--
-- If ANY slot HP drops -> GREEN combat end-to-end works.
-- If sword state==2 fires (verified by prior probe) but NO HP drops ->
-- real collision-engine bug.
--
-- Output: C:\tmp\probe_combat_stress.txt + screenshot.

local BASE = 0x8000
local function R(off)   return memory.read_u8(BASE + off, "68K RAM") end
local function W(off,v) memory.write_u8(BASE + off, v, "68K RAM") end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local OUT = "C:\\tmp\\probe_combat_stress.txt"
local f = io.open(OUT, "w")
f:write("probe_combat_stress\n===================\n\n")

-- Phase A: boot.
idle(40)

-- Phase B: arm enemy stress harness (both legacy + canonical sentinels).
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x02)  -- 'RP' + ENEMY_STRESS
W(0x73FC, 0x45); W(0x73FD, 0x50)                    -- 'EP' legacy

-- Phase C: debug-enter chord A+B+C.
press({A=true, B=true, C=true}, 30)
idle(30)

-- Capture initial state.
local hp_initial = {}
local type_initial = {}
local alive_initial = {}
for slot=1,11 do
    hp_initial[slot] = R(0x0485 + slot)
    type_initial[slot] = R(0x034F + slot)
    alive_initial[slot] = R(0x0492 + slot)
end

f:write("== post-debug-enter (T+0) ==\n")
f:write(string.format("  Link=($%02X,$%02X) RoomId=$%02X GameMode=$%02X\n",
    R(0x0070), R(0x0084), R(0x00EB), R(0x0012)))
local alive_at_start = 0
for slot=1,11 do
    if alive_initial[slot] ~= 0 then
        alive_at_start = alive_at_start + 1
        f:write(string.format("  slot%02d: type=$%02X hp=$%02X xy=($%02X,$%02X) alive=$%02X\n",
            slot, type_initial[slot], hp_initial[slot],
            R(0x0070 + slot), R(0x0084 + slot), alive_initial[slot]))
    end
end
f:write(string.format("  alive_at_start=%d\n\n", alive_at_start))

-- Phase D: A-mash 200 frames, track per-frame HP changes + sword state.
f:write("== combat phase: 200 frames A-mash + HP delta detection ==\n")
local first_hp_drop_slot = -1
local first_hp_drop_frame = -1
local first_hp_drop_from = 0
local first_hp_drop_to = 0
local total_hp_drops = 0
local sword_state_max = 0
local sword_state_at_drop = -1
local hp_prev = {}
for slot=1,11 do hp_prev[slot] = hp_initial[slot] end

for i=1,200 do
    if (i % 2) == 1 then joypad.set({A=true}, 1) else joypad.set({}, 1) end
    emu.frameadvance()
    local sst = R(0x00B9)  -- sword OBJ_STATE slot 13
    if sst > sword_state_max then sword_state_max = sst end
    for slot=1,11 do
        local hp = R(0x0485 + slot)
        if hp < hp_prev[slot] then
            total_hp_drops = total_hp_drops + 1
            if first_hp_drop_slot < 0 then
                first_hp_drop_slot = slot
                first_hp_drop_frame = i
                first_hp_drop_from = hp_prev[slot]
                first_hp_drop_to = hp
                sword_state_at_drop = sst
            end
        end
        hp_prev[slot] = hp
    end
end

local alive_at_end = 0
for slot=1,11 do if R(0x0492 + slot) ~= 0 then alive_at_end = alive_at_end + 1 end end

f:write(string.format("  sword_state_max during phase: $%02X\n", sword_state_max))
f:write(string.format("  total HP-drop events: %d\n", total_hp_drops))
f:write(string.format("  first HP drop: slot=%d frame=%d hp=$%02X->$%02X sword_state_at_drop=$%02X\n",
    first_hp_drop_slot, first_hp_drop_frame, first_hp_drop_from, first_hp_drop_to, sword_state_at_drop))
f:write(string.format("  alive_at_end: %d (was %d)\n", alive_at_end, alive_at_start))

f:write("\n== VERDICT ==\n")
if total_hp_drops > 0 then
    f:write("GREEN: sword damage end-to-end - HP drops landed.\n")
elseif sword_state_max == 2 then
    f:write("RED: sword state==2 fires (sync OK) but NO HP drops.\n")
    f:write("Real collision-engine gap. Investigate:\n")
    f:write("  - link_collision_check_monster_collisions actually runs per slot?\n")
    f:write("  - collision_check_monster_sword_collision(slot, 13u) reads $00B9?\n")
    f:write("  - sword X/Y at $7D/$91 vs enemy X/Y at $70+slot / $84+slot — reach?\n")
else
    f:write(string.format("YELLOW: sword state never reached 2 (max=$%02X). swing path broken.\n", sword_state_max))
end

client.screenshot("C:\\tmp\\probe_combat_stress.png")
f:close()
client.exit()
