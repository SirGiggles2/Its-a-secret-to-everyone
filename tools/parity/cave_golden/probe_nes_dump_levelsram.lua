-- probe_nes_dump_levelsram.lua — dump LIVE NES SRAM LevelBlock+LevelInfo.
-- The reference dat/LevelBlock*.dat + dat/LevelInfo*.dat do NOT match what
-- NES actually loads into SRAM (NES applies load transforms — palette buf
-- expand, LevelBlockAttrs post-process). The Gen rooms_dungeons blob was
-- built 1:1 from those dats, so dungeon enemy templates (LBA C/D) + FoeCounts
-- are wrong. Dump the REAL loaded tables ($687E..$6C7D = LevelBlockAttrs A-F
-- 768B + LevelInfo 256B = 1024B) per level so the blob can be regenerated to
-- byte-match NES (Phase-A "regenerate from NES probe" precedent). RULE ZERO.
-- One launch loads each Q1 level via the proven mode-$10 stairs entry + dumps.
QUEST = QUEST or 1
local OUT = "C:\\tmp\\nes_levelsram"
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')
local function R(o)  return memory.read_u8(o,"RAM") end
local function W(o,v) memory.write_u8(o,v,"RAM") end
local function SB(o) return memory.read_u8(o,"System Bus") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local f=io.open("C:/tmp/nes_sram_dbg.txt","a"); if f then f:write(s.."\n"); f:close() end; print(s) end
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
    W(0x062D,QUEST); W(LVL,lvl); idle(4)
    W(TILE,0x70); W(UG,0x70); W(TGT,0x02); W(GM,0x10)
    for _=1,300 do idle(1); local gm=R(GM); if gm>=0x05 and gm<=0x07 and R(LVL)==lvl then break end end
    idle(30)
end
local function dump_level(lvl)
    -- $687E..$6C7D inclusive = 1024 bytes (LevelBlock 768 + LevelInfo 256).
    local path=string.format("%s\\nes_sram_L%dQ%d.bin", OUT, lvl, QUEST)
    local f=io.open(path,"wb")
    for a=0x687E,0x6C7D do f:write(string.char(SB(a))) end
    f:close()
    LOG(string.format("L%dQ%d dumped rm=$%02X startroom=$%02X foe0=$%02X lbaC73=$%02X",
        lvl, QUEST, R(RM), SB(0x6BAD), SB(0x6BA2), SB(0x697E+0x73)))
end

LOG(string.format("=== NES SRAM level dump Q%d ===", QUEST))
if not boot() then LOG("BOOT FAIL"); client.exit(); return end
for lvl=1,9 do load_level(lvl); dump_level(lvl) end
LOG("done"); client.exit()
