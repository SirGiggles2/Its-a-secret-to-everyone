-- uw_capture_all_levels.lua — READ-ONLY (except TargetMode warp). Warp NES
-- to each UW level L1..L9 (Q1) and dump per-level LevelInfo (rotation, mask,
-- triforce, start) + the loaded LevelBlockAttrsA/B door block. Produces the
-- self-contained pause-local dungeon-map dataset (independent of the in-flight
-- data/rooms/dungeons.c regen). System Bus domain (NesHawk).
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
QN = QN or 0                  -- QuestNumbers value: 0 = 1st quest, 1 = 2nd
local QSUF = (QN == 0) and "" or ("_q" .. (QN + 1))   -- "" for Q1, "_q2" for Q2
local OUT = OUT_DIR
local function LOG(s)
    local fh = io.open(OUT .. "/levels" .. QSUF .. ".txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function SBr(a) memory.usememorydomain("System Bus"); return memory.read_u8(a & 0xFFFF) end
local function SBw(a,v) memory.usememorydomain("System Bus"); memory.write_u8(a & 0xFFFF, v & 0xFF) end

-- Boot past title.
for f=1,600 do
    if f>=30 and f%20==0 then joypad.set({Start=true}) else joypad.set({}) end
    emu.frameadvance()
    if SBr(0x0012) ~= 0 then break end
end
joypad.set({}); idle(20)

local function warp(L)
    -- Force quest before the level load (QuestNumbers + SaveFileAQuestNumber).
    SBw(0x062D,QN); SBw(0x062E,QN); SBw(0x062F,QN)
    SBw(0x651B,QN); SBw(0x651C,QN); SBw(0x651D,QN)
    SBw(0x0010, L); SBw(0x005B, 0x02); SBw(0x0602, 0x02); SBw(0x0012, 0x10)
    for _=1,300 do emu.frameadvance()
        if SBr(0x0012)==0x05 and SBr(0x0013)==0 and SBr(0x0010)==L then break end
    end
    idle(40)
end

local function dump_block(tag)  -- AttrsA $687E(128) + AttrsB $68FE(128)
    local f=io.open(OUT.."/door_"..tag..".bin","wb"); local t={}
    for a=0x687E,0x687E+0xFF do t[#t+1]=string.char(SBr(a)) end
    f:write(table.concat(t)); f:close()
    LOG(string.format("door_%s.bin: AttrsA[$73]=$%02X AttrsB[$73]=$%02X",
        tag, SBr(0x687E+0x73), SBr(0x68FE+0x73)))
end

LOG("=== per-level LevelInfo (Q1) ===")
local got_uw1q1, got_uw2q1 = false, false
for L=1,9 do
    warp(L)
    local mask=""; for k=0,15 do mask=mask..string.format("%02X ",SBr(0x6BBD+k)) end
    LOG(string.format("L%d: gm=$%02X room=$%02X rot$6BAB=$%02X sbxoff$6BAC=$%02X tri$6BAE=$%02X start$6BAD=$%02X mask=%s",
        L, SBr(0x0012), SBr(0x00EB), SBr(0x6BAB), SBr(0x6BAC), SBr(0x6BAE), SBr(0x6BAD), mask))
    if L<=6 and not got_uw1q1 then dump_block("uw1q"..(QN+1)); got_uw1q1=true end
    if L>=7 and not got_uw2q1 then dump_block("uw2q"..(QN+1)); got_uw2q1=true end
end
LOG("=== done ===")
client.exit()
