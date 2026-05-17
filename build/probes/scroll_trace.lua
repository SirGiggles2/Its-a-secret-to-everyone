-- scroll_trace.lua — trace Link movement + room transitions in OW.
-- Arms the $FF7200 state mirror, drives D-pad in all 4 directions,
-- logs Link X/Y/room_id every 15 frames. Goal: prove whether OW
-- room scrolling fires when Link reaches an edge.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o)
  return memory.read_u8(o, "68K RAM") * 256 + memory.read_u8(o+1, "68K RAM")
end
local function S16BE(o)
  local v = R16BE(o)
  if v >= 0x8000 then v = v - 0x10000 end
  return v
end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\scroll_trace.txt"
local f = io.open(OUT, "w")

local function snap(tag)
  -- $FF7200 = 0x7200 in 68K RAM domain
  local frame = R16BE(0x7202)
  local scene = R(0x7204)
  local room  = R(0x7205)
  local lx    = S16BE(0x7206)
  local ly    = S16BE(0x7208)
  local face  = R(0x720A)
  local dir   = R(0x720B)
  local off   = R(0x720C); if off>=0x80 then off=off-0x100 end
  local door  = R(0x720D)
  local col   = R(0x7225)
  local row   = R(0x7226)
  f:write(string.format("%-14s fr=%04X sc=%d rm=$%02X X=$%04X Y=$%04X face=%d dir=%d off=%d col=%d row=%d\n",
    tag, frame, scene, room, lx & 0xFFFF, ly & 0xFFFF, face, dir, off, col, row))
end

-- Boot
idle(60)

-- Arm state mirror BEFORE chord so we see boot-into-game transition
memory.write_u8(0x73F8, 0x52, "68K RAM") -- 'R'
memory.write_u8(0x73F9, 0x50, "68K RAM") -- 'P'
memory.write_u8(0x73FA, 0x01, "68K RAM") -- HEAVY_MIRROR (extra fields)

-- A+B+C to enter
for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)

f:write("=== POST-ENTRY ===\n")
snap("entry")

-- Hold RIGHT 300f, sample every 15
f:write("\n=== HOLD RIGHT 300f ===\n")
for i=1,300 do
  joypad.set({Right=true}, 1)
  emu.frameadvance()
  if i % 15 == 0 then snap("R+"..i) end
end
idle(20)
snap("R+settled")

-- Hold DOWN 300f
f:write("\n=== HOLD DOWN 300f ===\n")
for i=1,300 do
  joypad.set({Down=true}, 1)
  emu.frameadvance()
  if i % 15 == 0 then snap("D+"..i) end
end
idle(20)
snap("D+settled")

-- Hold LEFT 300f
f:write("\n=== HOLD LEFT 300f ===\n")
for i=1,300 do
  joypad.set({Left=true}, 1)
  emu.frameadvance()
  if i % 15 == 0 then snap("L+"..i) end
end
idle(20)
snap("L+settled")

-- Hold UP 300f
f:write("\n=== HOLD UP 300f ===\n")
for i=1,300 do
  joypad.set({Up=true}, 1)
  emu.frameadvance()
  if i % 15 == 0 then snap("U+"..i) end
end
idle(20)
snap("U+settled")

client.screenshot("C:\\tmp\\scroll_trace.png")
f:write("\nDONE\n")
f:close()
gui.text(8, 8, "scroll trace done")
idle(20)
client.exit()
