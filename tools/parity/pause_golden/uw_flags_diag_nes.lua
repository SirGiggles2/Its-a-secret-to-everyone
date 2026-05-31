-- uw_flags_diag_nes.lua — READ-ONLY NES ground truth. Warp to UW L1
-- (TargetMode mirror, proven in pause_capture_nes.lua), open the subscreen,
-- then dump System Bus $0000..$7FFF (RAM + $6xxx SRAM: LevelBlockAttrsA/B,
-- LevelInfo, world flags) so the dungeon-map inputs can be diffed vs Gen.
OUT_DIR = OUT_DIR or "C:/tmp/pause_golden"
local OUT = OUT_DIR
local function LOG(s)
    local fh = io.open(OUT .. "/diag_nes.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function SBr(a) memory.usememorydomain("System Bus"); return memory.read_u8(a & 0xFFFF) end
local function SBw(a,v) memory.usememorydomain("System Bus"); memory.write_u8(a & 0xFFFF, v & 0xFF) end
local function R(o) return memory.read_u8(o, "RAM") end

local UW_LEVEL = 1
-- Boot past title (Start), then warp.
for f=1,600 do
    if f>=30 and f%20==0 then joypad.set({Start=true}) else joypad.set({}) end
    emu.frameadvance()
    if SBr(0x0012) ~= 0 then break end
end
joypad.set({}); idle(30)
-- Warp (mirror SetTargetMode(2)).
SBw(0x0010, UW_LEVEL); SBw(0x005B, 0x02); SBw(0x0602, 0x02); SBw(0x0012, 0x10)
for _=1,240 do emu.frameadvance()
    if SBr(0x0012)==0x05 and SBr(0x0013)==0 and SBr(0x0010)==UW_LEVEL then break end
end
idle(60)
LOG(string.format("after warp gm=$%02X sub=$%02X level=$%02X room($EB)=$%02X",
    SBr(0x0012), SBr(0x0013), SBr(0x0010), SBr(0x00EB)))

-- Key dungeon-map inputs.
LOG(string.format("AttrsA[$73]($687E+73)=$%02X  AttrsB[$73]($68FE+73)=$%02X",
    SBr(0x687E+0x73), SBr(0x68FE+0x73)))
LOG(string.format("rotation $6BAB=$%02X  triforce $6BAE=$%02X  start $6BAD=$%02X",
    SBr(0x6BAB), SBr(0x6BAE), SBr(0x6BAD)))
local mask=""; for k=0,15 do mask=mask..string.format("%02X ",SBr(0x6BBD+k)) end
LOG("mask $6BBD..: "..mask)
local ptr = SBr(0x6BAF) | (SBr(0x6BB0)<<8)
LOG(string.format("WorldFlagsPtr $6BAF/B0 = $%04X", ptr))
local vis={}; for r=0,0x7F do if (SBr((ptr+r)&0xFFFF)&0x20)~=0 then vis[#vis+1]=string.format("$%02X(f=$%02X)",r,SBr((ptr+r)&0xFFFF)) end end
LOG("visited rooms via ptr: "..(#vis==0 and "NONE" or table.concat(vis," ")))
LOG(string.format("room $73 full flags via ptr = $%02X", SBr((ptr+0x73)&0xFFFF)))

-- Full $0000-$7FFF dump for offline analysis (RULE V3).
local f=io.open(OUT.."/nesram.bin","wb"); local t={}
for a=0,0x7FFF do t[#t+1]=string.char(SBr(a)); if #t==4096 then f:write(table.concat(t)); t={} end end
if #t>0 then f:write(table.concat(t)) end
f:close()
LOG("dumped $0000-$7FFF -> nesram.bin")
LOG("=== done ===")
client.exit()
