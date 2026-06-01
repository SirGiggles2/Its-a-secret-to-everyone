-- quest_test.lua — find which QuestNumbers ($62D) value loads the NES 2nd
-- quest. Boot, then for q in {0,1,2}: poke quest cells, warp L1, read the
-- installed LevelBlockAttrsA[$73]. Q1 = $A2; a different value = Q2 loaded.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
local function SBr(a) memory.usememorydomain("System Bus"); return memory.read_u8(a&0xFFFF) end
local function SBw(a,v) memory.usememorydomain("System Bus"); memory.write_u8(a&0xFFFF,v&0xFF) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s) local fh=io.open(OUT_DIR.."/quest_test.txt","a"); if fh then fh:write(s.."\n"); fh:close() end; print(s) end
-- boot past title
for f=1,600 do if f>=30 and f%20==0 then joypad.set({Start=true}) else joypad.set({}) end; emu.frameadvance(); if SBr(0x0012)~=0 then break end end
joypad.set({}); idle(20)
local function warp(L) SBw(0x0010,L); SBw(0x005B,0x02); SBw(0x0602,0x02); SBw(0x0012,0x10)
    for _=1,300 do emu.frameadvance(); if SBr(0x0012)==0x05 and SBr(0x0010)==L then break end end; idle(30) end
for _,q in ipairs({0,1,2}) do
    -- set quest in all candidate cells before the level load
    SBw(0x062D,q); SBw(0x062E,q); SBw(0x062F,q)            -- QuestNumbers[0..2]
    SBw(0x651B,q); SBw(0x651C,q); SBw(0x651D,q)            -- SaveFileAQuestNumber
    warp(1)
    LOG(string.format("quest=%d -> CurLevel=%d AttrsA[$73]=$%02X AttrsB[$73]=$%02X QN$62D=$%02X",
        q, SBr(0x0010), SBr(0x687E+0x73), SBr(0x68FE+0x73), SBr(0x062D)))
end
client.exit()
