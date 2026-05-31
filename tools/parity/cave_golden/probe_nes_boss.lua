-- probe_nes_boss.lua — NES ground truth for a dungeon BOSS sprite.
-- Enters L1 room $36 (Aquamentus) via the proven mode-$10 entry, then RUNS
-- frames (does NOT halt Link / the boss) so the boss object ticks + draws to
-- shadow OAM. Captures OAM($0200) + CHR(VRAM) + PALRAM + ppuctrl + screenshot.
-- The golden probe halts Link for a static BG frame -> garbage OAM; the boss
-- needs to be live to render, so this one lets it run. NesHawk.
LEVEL = LEVEL or 1
UW_ROOM = UW_ROOM or 0x36
local OUT = string.format("C:\\tmp\\nes_boss_L%d_R%02X", LEVEL, UW_ROOM)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')
local function R(o)  return memory.read_u8(o,"RAM") end
local function W(o,v) memory.write_u8(o,v,"RAM") end
local function OAM(o) return memory.read_u8(o,"OAM") end
local function PAL(o) return memory.read_u8(o,"PALRAM") end
local function CHR(o) return memory.read_u8(o,"VRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local f=io.open("C:/tmp/nes_boss_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
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
local function load_level(lvl)
    W(0x062D,1); W(LVL,lvl); idle(4)
    W(TILE,0x70); W(UG,0x70); W(TGT,0x02); W(GM,0x10)
    for _=1,300 do idle(1); local gm=R(GM); if gm>=0x05 and gm<=0x07 and R(LVL)==lvl then break end end
end
local function enter_room(room)
    memory.write_u8(0x6BAD, room, "System Bus"); W(RM,room); W(SUB,0); W(GM,0x04)
    for _=1,200 do idle(1); local gm=R(GM); if gm>=0x05 and gm<=0x07 and R(RM)==room then break end end
end
local function capture(fp)
    local f=io.open(string.format("%s\\f%03d.bin",OUT,fp),"wb")
    f:write("NCGD"); f:write(string.char(fp&0xFF)); f:write(string.char(UW_ROOM&0xFF))
    f:write(string.char(R(GM))); f:write(string.char(R(LVL)))
    for i=0,255 do f:write(string.char(OAM(i))) end
    for i=0,31 do f:write(string.char(PAL(i))) end
    for i=0,8191 do f:write(string.char(CHR(i))) end
    f:write(string.char(R(0x00FF)))
    f:close()
end

LOG(string.format("=== NES boss probe L%d room=$%02X ===", LEVEL, UW_ROOM))
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
load_level(LEVEL)
enter_room(UW_ROOM)
-- DO NOT halt — let the boss tick + animate. Run, sampling OAM occupancy.
LOG(string.format("entered gm=$%02X rm=$%02X objtype1=$%02X", R(GM), R(RM), R(0x0350+1)))
local prev=0
for _,fp in ipairs({0,30,60,90,120}) do idle(fp-prev); prev=fp; capture(fp) end
-- log boss OAM tiles present (sprite tiles in shadow OAM)
local tiles={}
for i=0,63 do local y=OAM(i*4); if y<0xF0 and y>0 then tiles[OAM(i*4+1)]=true end end
local tl={}; for t,_ in pairs(tiles) do tl[#tl+1]=string.format("$%02X",t) end
table.sort(tl)
LOG("on-screen OAM tiles: "..table.concat(tl," "))
client.screenshot(OUT.."\\shot.png")
LOG("done"); client.exit()
