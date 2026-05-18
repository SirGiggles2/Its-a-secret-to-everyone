-- Genesis full-state slot 1 trace, 120 frames.
local function R(o) return memory.read_u8(o, "68K RAM") end
local function W(o,v) memory.write_u8(o, v, "68K RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end

idle(60)
for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
idle(60)
for i=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x7205) == 0x67 then break end end
joypad.set({},1)
for _=1,200 do if R(0x8350) ~= 0 then break end; emu.frameadvance() end

local f = io.open("C:/tmp/subpix_gen.txt", "w")
f:write("=== Genesis full-state slot 1, 120 frames ===\n")
f:write("frame | X Y d qspd frac grid mvTm stTm meta shTm wTSh bnc hit inDir\n")
local SLOT = 1
for fr=0,119 do
  f:write(string.format("f%3d | X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X mvTm$%02X stTm$%02X meta$%02X shTm$%02X wTSh$%02X bnc$%02X hit$%02X inDir$%02X\n",
    fr,
    R(0x8070+SLOT), R(0x8084+SLOT), R(0x8098+SLOT),
    R(0x83BC+SLOT), R(0x83A8+SLOT), R(0x8394+SLOT),
    R(0x8028+SLOT), R(0x803D+SLOT), R(0x8405+SLOT),
    R(0x8451+SLOT), R(0x8412+SLOT), R(0x8478+SLOT), R(0x84F0+SLOT),
    R(0x83F8+SLOT)))
  emu.frameadvance()
end
f:close()
client.exit()
