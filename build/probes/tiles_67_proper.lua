-- tiles_67_proper.lua — dump cache properly: offset 4 + col*22 + row.
-- Show 32 cols x 22 rows in tabular format.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\tiles_67p.txt"
local f = io.open(OUT, "w")

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)

-- Walk to $67
for i=1,400 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(20)

f:write(string.format("room=$%02X (expected $67)\n", R(0x7205)))
f:write(string.format("Link X=$%04X Y=$%04X foot_tile=$%02X\n",
  R16BE(0x7206), R16BE(0x7208), R(0x7215)))

-- Proper col-major cache: byte at offset 4 + col*22 + row = tile[col][row]
f:write("\n-- s_raw_tiles[col][row] grid (cols 0..31, rows 0..21) --\n")
f:write("       ")
for c=0,31 do f:write(string.format("%2d ", c)) end
f:write("\n")
for r=0,21 do
  f:write(string.format("r=%2d:  ", r))
  for c=0,31 do
    local b = R(0x7400 + 4 + c*22 + r)
    f:write(string.format("%02X ", b))
  end
  f:write("\n")
end

-- Mark walkable per my new nes_ow_walkable_tile list
local function is_walk(t)
  if (t >= 0x03 and t <= 0x04) then return true end
  if (t >= 0x24 and t <= 0x27) then return true end
  if (t >= 0x54 and t <= 0x5F) then return true end
  if (t >= 0x6F and t <= 0x71) then return true end
  if (t >= 0x74 and t <= 0x77) then return true end
  if (t >= 0x84 and t <= 0x87) then return true end
  if t == 0x8D or t == 0x91 or t == 0x9C then return true end
  if t == 0xAC or t == 0xAD then return true end
  if t == 0xCC then return true end
  if t == 0xD2 or t == 0xD5 or t == 0xDF then return true end
  if t == 0xF3 then return true end
  return false
end

f:write("\n-- WALKABLE map (W=walk, .=block) --\n")
f:write("       ")
for c=0,31 do f:write(string.format("%2d ", c)) end
f:write("\n")
for r=0,21 do
  f:write(string.format("r=%2d:  ", r))
  for c=0,31 do
    local b = R(0x7400 + 4 + c*22 + r)
    f:write(is_walk(b) and " W " or " . ")
  end
  f:write("\n")
end

client.screenshot("C:\\tmp\\tiles_67p.png")
f:close()
gui.text(8, 8, "tile p done")
idle(20)
client.exit()
