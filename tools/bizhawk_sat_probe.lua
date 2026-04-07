-- Sprite Attribute Table is at $F800 (Reg 5=$7C)
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/sat_probe.txt"
local fh = io.open(OUT, "w")
while emu.framecount() < 700 do emu.frameadvance() end

fh:write("=== Sprite Attribute Table at $F800, f700 ===\n")
for i = 0, 79 do
  local base = 0xF800 + i*8
  local y  = memory.read_u16_be(base+0, "VRAM")
  local sz = memory.read_u16_be(base+2, "VRAM")
  local at = memory.read_u16_be(base+4, "VRAM")
  local x  = memory.read_u16_be(base+6, "VRAM")
  if y ~= 0 or at ~= 0 or x ~= 0 then
    fh:write(string.format("spr %02d: Y=%04X SL=%04X AT=%04X X=%04X\n", i, y, sz, at, x))
  end
end
fh:close()
client.exit()
