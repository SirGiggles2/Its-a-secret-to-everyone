-- probe_nes_dungeon_enemies.lua — NES ground truth for dungeon enemy load.
-- Loads L1 + enters room $73 (same proven entry as the golden probe), then
-- dumps NES SRAM LevelBlockAttrsC/D + LevelInfo_FoeCounts + the spawned
-- ObjType[] so we can byte-diff vs the Gen blob (which had LBA_C[$73]=$00 →
-- template 0 → no enemies). RULE ZERO: NES live, not guessed. NesHawk.
LEVEL=1; QUEST=1; UW_ROOM=0x63
local function R(o)  return memory.read_u8(o,"RAM") end
local function W(o,v) memory.write_u8(o,v,"RAM") end
local function SB(o) return memory.read_u8(o,"System Bus") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local f=io.open("C:/tmp/nes_enemy_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
local GM=0x0012; local SUB=0x0013; local LVL=0x0010; local RM=0x00EB
local TGT=0x005B; local TILE=0x049E; local UG=0x0065

local function boot()
    for f=1,1800 do local gm=R(GM)
        if gm>=0x05 and gm<=0x07 then idle(20); return true end
        if (f%16)==0 then joypad.set({Start=true},1) else joypad.set({},1) end
        emu.frameadvance()
    end
    return false
end
local function load_level()
    W(0x062D,QUEST); W(LVL,LEVEL); idle(4)
    W(TILE,0x70); W(UG,0x70); W(TGT,0x02); W(GM,0x10)
    for _=1,240 do idle(1); local gm=R(GM); if gm>=0x05 and gm<=0x07 and R(LVL)==LEVEL then break end end
end
local function enter_room(room)
    memory.write_u8(0x6BAD, room, "System Bus"); W(RM,room); W(SUB,0); W(GM,0x04)
    for _=1,200 do idle(1); local gm=R(GM); if gm>=0x05 and gm<=0x07 and R(RM)==room then break end end
    idle(60)
end

LOG(string.format("=== NES dungeon enemy probe L%d room=$%02X ===", LEVEL, UW_ROOM))
LOG(string.format("boot start gm=$%02X", R(GM)))
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
LOG(string.format("booted gm=$%02X rm=$%02X", R(GM), R(RM)))
load_level()
enter_room(UW_ROOM)
LOG(string.format("gm=$%02X lvl=%d rm=$%02X", R(GM), R(LVL), R(RM)))
LOG(string.format("FoeCounts[0..3]=$%02X $%02X $%02X $%02X", SB(0x6BA2),SB(0x6BA3),SB(0x6BA4),SB(0x6BA5)))
LOG(string.format("LBA_C($73)=$%02X  LBA_D($73)=$%02X", SB(0x697E+0x73), SB(0x69FE+0x73)))
LOG(string.format("ROOM_OBJ_COUNT($034E)=$%02X  TEMPLATE_TYPE($035F)=$%02X", R(0x034E), R(0x035F)))
local objs={}; for s=1,11 do objs[#objs+1]=string.format("$%02X", R(0x0350+s)) end
LOG("ObjType[1..11]= "..table.concat(objs," "))
-- also dump LBA_C for the full L1 room set to see if it's region-wide zero
local cset={0x73,0x63,0x72,0x74,0x53,0x54,0x33,0x22,0x23,0x41,0x42,0x43,0x44,0x45,0x52,0x35,0x36}
local cs={}; for _,r in ipairs(cset) do cs[#cs+1]=string.format("%02X:%02X",r,SB(0x697E+r)) end
LOG("LBA_C[L1 rooms]= "..table.concat(cs," "))
LOG("done"); client.exit()
