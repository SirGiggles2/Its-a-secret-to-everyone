-- tiles_67_column.lua — walk to $67 clamp, then dump $FF7400 cache.
-- $FF7400 starts the OW raw-tile cache (32x22 bytes = 704 B).
-- Layout in code: s_raw_tiles[tile_col][tile_row], but cache copy
-- has its own layout. Per ow_render: publish_cache copies to
-- $FF7400+. Check what's published.

local function R(o) return memory.read_u8(o, "68K RAM") end
local function R16BE(o) return R(o)*256 + R(o+1) end
local function S16BE(o)
  local v = R16BE(o); if v >= 0x8000 then v = v - 0x10000 end; return v
end
local function idle(n) for _=1,n do emu.frameadvance() end end

local OUT = "C:\\tmp\\tiles_67.txt"
local f = io.open(OUT, "w")

idle(60)
memory.write_u8(0x73F8, 0x52, "68K RAM")
memory.write_u8(0x73F9, 0x50, "68K RAM")
memory.write_u8(0x73FA, 0x01, "68K RAM")

for i=1,30 do joypad.set({A=true,B=true,C=true}, 1); emu.frameadvance() end
idle(30)

-- Walk north 400 frames to $67 + clamp
for i=1,400 do joypad.set({Up=true}, 1); emu.frameadvance() end
idle(20)

f:write(string.format("After up-walk: rm=$%02X X=$%04X Y=$%04X foot_tile=$%02X\n",
  R(0x7205), R16BE(0x7206), R16BE(0x7208), R(0x7215)))

-- Dump $FF7400 raw-tile cache (704 bytes). Check magic first.
f:write(string.format("\n$FF7400 magic: %02X %02X %02X %02X\n",
  R(0x7400), R(0x7401), R(0x7402), R(0x7403)))

-- Try alternative interpretation: 32 cols x 22 rows, row-major
-- Maybe stride 32 (cols) per row.
f:write("\n-- Try row-major 32 wide --\n")
for tr=0,21 do
  f:write(string.format("tr=%02d: ", tr))
  for tc=0,31 do
    f:write(string.format("%02X ", R(0x7400 + tr*32 + tc)))
  end
  f:write("\n")
end

-- Also dump col-major interpretation as sanity check
f:write("\n-- Try col-major 22 wide --\n")
for tc=0,31 do
  f:write(string.format("tc=%02d: ", tc))
  for tr=0,21 do
    f:write(string.format("%02X ", R(0x7400 + tc*22 + tr)))
  end
  f:write("\n")
end

client.screenshot("C:\\tmp\\tiles_67.png")
f:close()
gui.text(8, 8, "tile dump done")
idle(20)
client.exit()
