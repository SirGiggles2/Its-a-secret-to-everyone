-- Trace ObjPosFrac + ObjGridOffset + ObjX/Y for slot 1 over 30 frames
-- post-spawn. Will dump same probe shape for NES + Genesis ROM.
-- Auto-detects ROM by checking 68K RAM vs RAM domain.

local IS_GEN = false
for _, d in ipairs(memory.getmemorydomainlist()) do
  if d == "68K RAM" then IS_GEN = true; break end
end

local RAM_DOM = IS_GEN and "68K RAM" or "WRAM"
local function R(o) return memory.read_u8(o, RAM_DOM) end
local function W(o,v) memory.write_u8(o, v, RAM_DOM) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function tap(btn) joypad.set({[btn]=true},1); emu.frameadvance(); joypad.set({},1); emu.frameadvance() end

if IS_GEN then
  -- Genesis Debug.md boot path
  idle(60)
  for i=1,30 do joypad.set({A=true,B=true,C=true},1); emu.frameadvance() end
  W(0x73F8, 0x52); W(0x73F9, 0x50); W(0x73FA, 0x00)
  idle(60)
  for i=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x7205) == 0x67 then break end end
else
  -- NES Z1 boot
  idle(120); tap("Start"); idle(30); tap("Start"); idle(60)
  tap("Down"); tap("Down"); tap("Down"); tap("Start"); idle(60)
  for _=1,8 do tap("Down") end; tap("Start"); idle(60)
  tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); tap("Up"); idle(30)
  tap("Start"); idle(120)
  for _=1,400 do joypad.set({Up=true},1); emu.frameadvance(); if R(0x00EB) == 0x67 then break end end
end
joypad.set({},1)

-- Wait until slot 1 populated
local TYPE_OFF = IS_GEN and 0x8350 or 0x0350
for _=1,200 do if R(TYPE_OFF) ~= 0 then break end; emu.frameadvance() end

local out_path = IS_GEN and "C:/tmp/subpix_gen.txt" or "C:/tmp/subpix_nes.txt"
local f = io.open(out_path, "w")
f:write(string.format("=== %s sub-pixel trace slot 1, 60 frames ===\n", IS_GEN and "Genesis" or "NES"))
f:write("frame | X Y dir qspd posfrac gridoff\n")

local BASE = IS_GEN and 0x8000 or 0x0000
local SLOT = 1
local function S(off) return R(BASE + off + SLOT) end
local function G(off) return R(BASE + off) end  -- global

for fr=0,119 do
  f:write(string.format("f%3d | X$%02X Y$%02X d$%02X qspd$%02X frac$%02X grid$%02X mvTm$%02X stTm$%02X meta$%02X shTm$%02X wTSh$%02X bnc$%02X hit$%02X inDir$%02X\n",
    fr,
    S(0x70), S(0x84), S(0x98), S(0x3BC), S(0x3A8), S(0x394),
    S(0x28), S(0x3D), S(0x405), S(0x451), S(0x412), S(0x478), S(0x4F0),
    S(0x3F8)))
  emu.frameadvance()
end
f:close()
client.exit()
