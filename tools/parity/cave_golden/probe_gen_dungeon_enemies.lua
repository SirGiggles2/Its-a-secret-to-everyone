-- probe_gen_dungeon_enemies.lua — diagnose why Gen dungeon rooms spawn no
-- enemies. Warp to (LEVEL, UW_ROOM) via the probe-warp ctrl, settle, then dump
-- the enemy room-load state (RULE ZERO — read live, don't guess):
--   LevelInfo_FoeCounts $6BA2..$6BA5  (DUNGEON_LEVEL_FOE_COUNTS)
--   DUNGEON_LBA_C/D(room) $697E+r / $69FE+r  (template_id + foe_idx source)
--   DUNGEON_ROOM_OBJ_COUNT $034E, TEMPLATE_TYPE $035F
--   ObjType[1..11] $0350+slot, ENEMY_ALIVE $0350.. (type!=0 => loaded)
-- All NES-mirror cells: Gen reads $FF8000+addr (68K RAM offset $8000+addr).
LEVEL   = LEVEL   or 1
QUEST   = QUEST   or 1
UW_ROOM = UW_ROOM or 0x73

local function r8(o)   return memory.read_u8(o, "68K RAM") end
local function w8(o,v) memory.write_u8(o, v, "68K RAM") end
local function nes(a)  return r8(0x8000 + a) end        -- NES-mirror read
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local f=io.open("C:/tmp/dun_enemy_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
local OFF_SCENE=0x0281; local OFF_IN_GAMEPLAY=0x0274; local SCENE_UW=1

local function boot()
    for f=1,1500 do
        if f>=30 and f<=600 and (f%30)==0 then joypad.set({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}) end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY)==1 then idle(60); return true end
    end
    return false
end

local function warp(room)
    w8(0x73F8,0x52); w8(0x73F9,0x50); w8(0x73FB,0x01); w8(0x73FC,LEVEL)
    w8(0x73FD,QUEST); w8(0x73FE,room); w8(0x73FF,0x5A)
    for k=1,180 do emu.frameadvance(); if r8(OFF_SCENE)==SCENE_UW then idle(90); return true end end
    return false
end

LOG(string.format("=== Gen dungeon enemy probe L%dQ%d room=$%02X ===", LEVEL, QUEST, UW_ROOM))
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
if not warp(UW_ROOM) then LOG("WARP FAIL scene="..r8(OFF_SCENE)); client.exit(); return end

LOG(string.format("gm=$%02X lvl=%d rmEB=$%02X scene=%d", nes(0x0012), nes(0x0010), nes(0x00EB), r8(OFF_SCENE)))
LOG(string.format("FoeCounts[0..3]=$%02X $%02X $%02X $%02X",
    nes(0x6BA2), nes(0x6BA3), nes(0x6BA4), nes(0x6BA5)))
LOG(string.format("LBA_C($%02X)=$%02X  LBA_D($%02X)=$%02X",
    UW_ROOM, nes(0x697E+UW_ROOM), UW_ROOM, nes(0x69FE+UW_ROOM)))
LOG(string.format("ROOM_OBJ_COUNT($034E)=$%02X  TEMPLATE_TYPE($035F)=$%02X",
    nes(0x034E), nes(0x035F)))
local objs = {}
for s=1,11 do objs[#objs+1]=string.format("$%02X", nes(0x0350+s)) end
LOG("ObjType[1..11]= " .. table.concat(objs, " "))
client.screenshot("C:\\tmp\\cave_golden\\gen_enemy_L"..LEVEL.."_R"..string.format("%02X",UW_ROOM)..".png")
LOG("done")
client.exit()
