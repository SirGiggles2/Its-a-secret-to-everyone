-- probe_gen_boss_live.lua — capture a Gen dungeon BOSS room with the boss
-- LIVE (Link NOT halted, boss object ticking). The golden/enemy probes halt
-- Link ($00AC=$40) for a static BG frame, which freezes the boss -> stale OAM.
-- This warps in, runs frames letting everything tick, then screenshots + dumps
-- the shadow OAM ($0200) boss-tile sprites + the live SAT boss sprites.
LEVEL=LEVEL or 1; QUEST=QUEST or 1; UW_ROOM=UW_ROOM or 0x36
local function r8(o) return memory.read_u8(o,"68K RAM") end
local function w8(o,v) memory.write_u8(o,v,"68K RAM") end
local function vr(o) return memory.read_u8(o,"VRAM") end
local function nes(a) return r8(0x8000+a) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local f=io.open("C:/tmp/gen_boss_live_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
local OFF_SCENE=0x0281; local OFF_IN_GAMEPLAY=0x0274; local SCENE_UW=1
local function boot()
    for f=1,1500 do
        if f>=30 and f<=600 and (f%30)==0 then joypad.set({["P1 A"]=true,["P1 B"]=true,["P1 C"]=true}) end
        emu.frameadvance(); if r8(OFF_IN_GAMEPLAY)==1 then idle(60); return true end
    end
    return false
end
local function warp(room)
    w8(0x73F8,0x52); w8(0x73F9,0x50); w8(0x73FB,0x01); w8(0x73FC,LEVEL)
    w8(0x73FD,QUEST); w8(0x73FE,room); w8(0x73FF,0x5A)
    for k=1,180 do emu.frameadvance(); if r8(OFF_SCENE)==SCENE_UW then return true end end
    return false
end
LOG(string.format("=== Gen LIVE boss probe L%d room=$%02X ===",LEVEL,UW_ROOM))
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
if not warp(UW_ROOM) then LOG("WARP FAIL scene="..r8(OFF_SCENE)); client.exit(); return end
idle(150)   -- let the boss spawn + tick + animate; DO NOT halt Link
-- shadow OAM ($0200) boss-tile ($C0-$D2) sprites
local sh={}
for i=0,63 do local t=nes(0x0200+i*4+1); local y=nes(0x0200+i*4) if t>=0xC0 and t<=0xD2 and y>0 and y<0xF0 then sh[#sh+1]=string.format("oam%d:y%02X t%02X x%02X",i,y,t,nes(0x0200+i*4+3)) end end
LOG("shadow-OAM boss tiles ($C0-$D2): "..(#sh>0 and table.concat(sh," ") or "NONE"))
-- live SAT ($F400) boss-bank tiles (677..695)
local sat=0xF400; local sb={}; local allslots={}
for i=0,63 do local o=sat+i*8; local at=(vr(o+4)<<8)|vr(o+5); local tile=at&0x7FF
  local y=((vr(o)<<8)|vr(o+1)); local x=((vr(o+6)<<8)|vr(o+7)); local link=vr(o+3)&0x7F
  if tile>=677 and tile<=695 then sb[#sb+1]=string.format("spr%d:t%d(NES$%02X)pal%d",i,tile,0xC0+tile-677,(at>>13)&3) end
  if not (y==0 and x==0 and tile==0) then allslots[#allslots+1]=string.format("s%d[y%d x%d t%d lk%d]",i,y-128,x-128,tile,link) end
end
LOG("live SAT boss-bank sprites: "..(#sb>0 and table.concat(sb," ") or "NONE"))
LOG("FULL SAT non-empty ("..#allslots.."): "..table.concat(allslots," "))
do  -- CRAM PAL2 (slots 32..35) = where the boss (sub-pal 3) routes; should be green.
    local function cw(slot) return (memory.read_u8(slot*2,"CRAM")<<8)|memory.read_u8(slot*2+1,"CRAM") end
    LOG(string.format("CRAM PAL2[0..3] = %04X %04X %04X %04X", cw(32),cw(33),cw(34),cw(35)))
end
client.screenshot("C:\\tmp\\cave_golden\\gen_bosslive_L"..LEVEL.."_R"..string.format("%02X",UW_ROOM)..".png")
LOG("done"); client.exit()
