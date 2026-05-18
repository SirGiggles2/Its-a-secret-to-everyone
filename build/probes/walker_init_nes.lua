-- NES-only walker init diff.
local function R(o) return memory.read_u8(o, "RAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
for _=1,8 do tap("Down") end; tap("Start"); idle(60)
tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
tap("Start"); idle(120)
for _=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB) == 0x67 then break end end
joypad.set({},1)
for _=1,500 do if R(0x0350) ~= 0 then break end; emu.frameadvance() end

local f = io.open("C:/tmp/walker_init_nes.txt", "w")
f:write("=== NES slot 1 init capture ===\n")
for fr=0,15 do
  f:write(string.format("f%2d | LinkX$%02X LinkY$%02X LinkDir$%02X | ChaseX$%02X ChaseY$%02X | s1: type$%02X X$%02X Y$%02X dir$%02X inDir$%02X qspd$%02X mvTm$%02X meta$%02X | RNG: $%02X $%02X $%02X\n",
    fr,
    R(0x0070), R(0x0084), R(0x0098),
    R(0x0061), R(0x0062),
    R(0x0350),
    R(0x0071), R(0x0085), R(0x0099), R(0x03F9),
    R(0x03BD), R(0x0029), R(0x0406),
    R(0x0018), R(0x0019), R(0x001A)))
  emu.frameadvance()
end
f:close()
client.exit()
