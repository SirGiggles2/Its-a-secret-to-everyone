-- Dump plane A rows 6-14 (sword + logo area) on Genesis at f700.
-- Also dump sprite attribute table for waterfall sprites.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/sword_probe.txt"
local fh = io.open(OUT, "w")
while emu.framecount() < 700 do emu.frameadvance() end

fh:write("=== Plane A rows 6-14 (sword/logo) at f700 ===\n")
for row = 6, 14 do
  local addr = 0xC000 + row*64*2
  fh:write(string.format("row %2d [$%04X]: ", row, addr))
  for col = 0, 31 do
    local w = memory.read_u16_be(addr + col*2, "VRAM")
    fh:write(string.format("%04X ", w))
  end
  fh:write("\n")
end

fh:write("\n=== Sprite Attribute Table at $F000 (80 sprites, 8 bytes each in M5) ===\n")
fh:write("NB: MD sprite entry = 8 bytes: Y(2) size/link(2) attr(2) X(2)\n")
for i = 0, 31 do
  local base = 0xF000 + i*8
  local y  = memory.read_u16_be(base+0, "VRAM")
  local sz = memory.read_u16_be(base+2, "VRAM")
  local at = memory.read_u16_be(base+4, "VRAM")
  local x  = memory.read_u16_be(base+6, "VRAM")
  fh:write(string.format("spr %02d: Y=%04X SL=%04X AT=%04X X=%04X\n", i, y, sz, at, x))
end

fh:close()
client.exit()
