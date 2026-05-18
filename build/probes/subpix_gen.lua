-- Genesis-only subpix trace
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
f:write("=== Genesis sub-pixel trace slot 1, 60 frames ===\n")
f:write("frame | X Y dir qspd posfrac gridoff\n")
for fr=0,59 do
  f:write(string.format("f%2d | X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X shTm$%02X wTSh$%02X mvTm$%02X stTm$%02X bnc$%02X hit$%02X\n",
    fr, R(0x8071), R(0x8085), R(0x8099), R(0x83BD), R(0x83A9), R(0x8395),
    R(0x8452), R(0x8413), R(0x8029), R(0x803E), R(0x8479), R(0x84F1)))
  emu.frameadvance()
end
f:close()
client.exit()
