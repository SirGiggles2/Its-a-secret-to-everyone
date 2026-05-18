-- NES Z1 full-state slot 1 trace, 120 frames at room $67.
local function R(o) return memory.read_u8(o, "WRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

-- Boot: tap Start until in gameplay (GameMode @ $0012 = 5).
idle(120)
for _=1,300 do
  tap("Start")
  if memory.read_u8(0x0012, "WRAM") == 0x05 then break end
end
idle(60)
-- Walk Up to room $67
for _=1,600 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB) == 0x67 then break end end
joypad.set({},1)
-- Wait for slot 1 populate
for _=1,500 do if R(0x0350) ~= 0 then break end; emu.frameadvance() end

local f = io.open("C:/tmp/subpix_nes.txt", "w")
f:write("=== NES full-state slot 1, 120 frames ===\n")
f:write("frame | X Y d qspd frac grid mvTm stTm meta shTm wTSh bnc hit inDir\n")
local SLOT = 1
for fr=0,119 do
  f:write(string.format("f%3d | X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X mvTm$%02X stTm$%02X meta$%02X shTm$%02X wTSh$%02X bnc$%02X hit$%02X inDir$%02X\n",
    fr,
    R(0x0070+SLOT), R(0x0084+SLOT), R(0x0098+SLOT),
    R(0x03BC+SLOT), R(0x03A8+SLOT), R(0x0394+SLOT),
    R(0x0028+SLOT), R(0x003D+SLOT), R(0x0405+SLOT),
    R(0x0451+SLOT), R(0x0412+SLOT), R(0x0478+SLOT), R(0x04F0+SLOT),
    R(0x03F8+SLOT)))
  emu.frameadvance()
end
f:close()
client.exit()
