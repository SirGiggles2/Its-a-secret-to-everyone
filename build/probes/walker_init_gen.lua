-- Genesis-only walker init diff.
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

local f = io.open("C:/tmp/walker_init_gen.txt", "w")
f:write("=== Genesis slot 1 init capture ===\n")
for fr=0,15 do
  f:write(string.format("f%2d | LinkX$%02X LinkY$%02X LinkDir$%02X | ChaseX$%02X ChaseY$%02X | s1: type$%02X X$%02X Y$%02X dir$%02X inDir$%02X qspd$%02X mvTm$%02X meta$%02X | RNG: $%02X $%02X $%02X\n",
    fr,
    R(0x8070), R(0x8084), R(0x8098),
    R(0x8061), R(0x8062),
    R(0x8350),
    R(0x8071), R(0x8085), R(0x8099), R(0x83F9),
    R(0x83BD), R(0x8029), R(0x8406),
    R(0x8018), R(0x8019), R(0x801A)))
  emu.frameadvance()
end
f:close()
client.exit()
