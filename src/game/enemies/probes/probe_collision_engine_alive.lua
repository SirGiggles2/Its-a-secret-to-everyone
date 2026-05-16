-- probe_collision_engine_alive.lua — verify the collision engine
-- actually ticks per-slot per-frame when enemies exist, regardless
-- of whether sword reaches.
--
-- Read $FF7FCC ENEMY_LOOP_COLLISION_VIZ_BASE:
--   [0..1] = 'CV' magic
--   [2..5] = g_check_monster_collisions_calls (be u32)
--   [6..9] = g_check_link_collision_calls    (be u32)
--
-- Counter growth > 0 across the 200-frame trace proves c_walker_move
-- downstream c_check_monster_collisions invocation actually fires
-- per-slot per-tick. If counter == 0 throughout, the engine is dead
-- (real bug). If counter > 0 but no HP drops -> Link approach issue.

local function r8(off)  return memory.read_u8(off, "68K RAM") end
local function w8(off,v) memory.write_u8(off, v, "68K RAM") end
local function r32be(off) return (r8(off)*0x1000000) + (r8(off+1)*0x10000) + (r8(off+2)*0x100) + r8(off+3) end
local function idle(n)  for _=1,n do emu.frameadvance() end end
local function press(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end
local function hold(b,n) for _=1,n do joypad.set(b,1); emu.frameadvance() end end

local CV = 0x7FCC
local DV = 0x7FD8

local OUT = "C:\\tmp\\probe_collision_engine_alive.txt"
local f = io.open(OUT, "w")
f:write("probe_collision_engine_alive (v2 with probe armed)\n============================\n\n")

-- Boot + ARM probe so publish_collision_viz runs each tick.
idle(40)
-- Canonical: $73F8='R','P', flag +2 = 0x02 ENEMY_STRESS.
w8(0x73F8, 0x52); w8(0x73F9, 0x50); w8(0x73FA, 0x02)
-- Legacy: $73FC='E','P'.
w8(0x73FC, 0x45); w8(0x73FD, 0x50)
press({A=true,B=true,C=true},30); idle(30)

local function pos_tag(tag)
    f:write(string.format("  %-30s Link=($%02X,$%02X) RoomId=$%02X face=$%02X GameMode=$%02X\n",
        tag, r8(0x8070), r8(0x8084), r8(0x80EB), r8(0x808C), r8(0x8012)))
end
pos_tag("@T+0 pos")

local function dump_cv(tag)
    local m0 = r8(CV); local m1 = r8(CV+1)
    local mc = r32be(CV+2); local lc = r32be(CV+6)
    f:write(string.format("  %-30s magic=%02X%02X mc_calls=%d lc_calls=%d\n",
        tag, m0, m1, mc, lc))
    return mc, lc
end

local function dump_dv(tag)
    local m0 = r8(DV); local m1 = r8(DV+1)
    f:write(string.format("  %-30s DM magic=%02X%02X slot1_hp_seed=$%02X slot1_hp_live=$%02X "
                       .."hit_react=$%02X shove_dir=$%02X shove_timer=$%02X meta=$%02X "
                       .."type=$%02X death=$%02X kill=$%02X obj13_state=$%02X harm=$%02X room_kill=$%02X\n",
        tag, m0, m1, r8(DV+2), r8(DV+3), r8(DV+4), r8(DV+5), r8(DV+6), r8(DV+7),
        r8(DV+8), r8(DV+9), r8(DV+10), r8(DV+11), r8(DV+12), r8(DV+13)))
end

f:write("== T+0 post-debug-enter ($77 cave entrance) ==\n")
dump_cv("@T+0   cv")
dump_dv("@T+0   dv")
local alive_t0 = 0
for slot=1,11 do if r8(0x8492+slot)~=0 then alive_t0=alive_t0+1 end end
f:write(string.format("  enemies_alive=%d\n\n", alive_t0))

f:write("== walk LEFT 120 + idle 60 ($76 entry) ==\n")
hold({Left=true}, 120); idle(60)
pos_tag("@scrolled pos")
dump_cv("@scrolled cv")
dump_dv("@scrolled dv")
local alive_scrolled = 0
for slot=1,11 do if r8(0x8492+slot)~=0 then alive_scrolled=alive_scrolled+1 end end
f:write(string.format("  enemies_alive=%d (was %d at T+0)\n\n", alive_scrolled, alive_t0))

f:write("== passive 120 frames (enemies wander toward Link) ==\n")
local mc_before, lc_before = dump_cv("@passive-start cv")
idle(120)
local mc_after, lc_after = dump_cv("@passive-end   cv")
dump_dv("@passive-end   dv")
f:write(string.format("  delta over 120 idle frames: mc=+%d lc=+%d\n\n",
    mc_after - mc_before, lc_after - lc_before))

f:write("== A-mash 200 frames in place ==\n")
local mc_amash_start = mc_after
for i=1,200 do
    if (i%2)==1 then joypad.set({A=true},1) else joypad.set({},1) end
    emu.frameadvance()
end
local mc_amash_end, lc_amash_end = dump_cv("@amash-end cv")
dump_dv("@amash-end dv")
f:write(string.format("  delta over 200 amash frames: mc=+%d lc=+%d\n\n",
    mc_amash_end - mc_amash_start, lc_amash_end - lc_after))

-- HP scan all slots after amash
f:write("  enemy HP after amash:\n")
local alive_end = 0
for slot=1,11 do
    if r8(0x8492+slot)~=0 then
        alive_end = alive_end + 1
        f:write(string.format("    slot%02d: type=$%02X hp=$%02X xy=($%02X,$%02X)\n",
            slot, r8(0x8000+0x034F+slot), r8(0x8000+0x0485+slot),
            r8(0x8000+0x0070+slot), r8(0x8000+0x0084+slot)))
    end
end
f:write(string.format("  alive_end=%d (was %d after scroll)\n", alive_end, alive_scrolled))

f:write("\n== VERDICT ==\n")
local mc_total_delta = mc_amash_end - mc_after
if mc_total_delta > 0 and mc_amash_end > 0 then
    f:write(string.format("GREEN: collision engine alive, mc counter +%d in 200 frames.\n", mc_total_delta))
    if alive_end < alive_scrolled then
        f:write("       kills landed too.\n")
    else
        f:write("       no HP drops = Link approach failure (sword reach < enemy distance).\n")
    end
else
    f:write(string.format("RED: collision engine NOT firing (mc delta=%d, mc_total=%d).\n",
        mc_total_delta, mc_amash_end))
    f:write("Investigate c_walker_move -> c_check_monster_collisions wrapper chain.\n")
end

client.screenshot("C:\\tmp\\probe_collision_engine_alive.png")
f:close()
client.exit()
