-- Capture state at EXACT frame slot 1 inits. NES + Genesis both.
local IS_GEN = false
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "68K RAM" then IS_GEN = true; break end
end
local DOM = IS_GEN and "68K RAM" or "RAM"
local function R(o) return memory.read_u8(o, DOM) end
local function W(o,v) memory.write_u8(o, v, DOM) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

if IS_GEN then
  idle(60)
  for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
  W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
  idle(60)
  for i=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x7205) == 0x67 then break end end
else
  idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
  tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
  for _=1,8 do tap("Down") end; tap("Start"); idle(60)
  tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
  tap("Start"); idle(120)
  for _=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB) == 0x67 then break end end
end
joypad.set({},1)

local TYPE_BASE = IS_GEN and 0x8350 or 0x0350
local BASE = IS_GEN and 0x8000 or 0x0000

for _=1,200 do if R(TYPE_BASE) ~= 0 then break end; emu.frameadvance() end

local out_path = IS_GEN and "C:/tmp/walker_init_gen.txt" or "C:/tmp/walker_init_nes.txt"
local f = io.open(out_path, "w")
f:write(string.format("=== %s slot 1 init capture ===\n", IS_GEN and "Genesis" or "NES"))

for fr=0,15 do
  f:write(string.format("f%2d | LinkX$%02X LinkY$%02X LinkDir$%02X | ChaseX$%02X ChaseY$%02X | s1: type$%02X X$%02X Y$%02X dir$%02X inDir$%02X qspd$%02X mvTm$%02X meta$%02X | RNG: $%02X $%02X $%02X\n",
    fr,
    R(BASE + 0x70), R(BASE + 0x84), R(BASE + 0x98),
    R(BASE + 0x61), R(BASE + 0x62),
    R(TYPE_BASE),
    R(BASE + 0x70 + 1), R(BASE + 0x84 + 1), R(BASE + 0x98 + 1), R(BASE + 0x3F8 + 1),
    R(BASE + 0x3BC + 1), R(BASE + 0x28 + 1), R(BASE + 0x405 + 1),
    R(BASE + 0x18), R(BASE + 0x19), R(BASE + 0x1A)))
  emu.frameadvance()
end

f:close()
client.exit()
