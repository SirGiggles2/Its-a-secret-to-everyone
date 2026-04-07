-- Dump Gen CRAM (64 bytes = 4 palettes × 16 colors) at frame 2200 during items showcase.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/cram_items.txt"

local frame = 0
while frame < 2200 do emu.frameadvance() frame = frame + 1 end

local f = io.open(OUT, "w")
f:write(string.format("# CRAM dump at frame %d\n", frame))
for pal=0,3 do
  f:write(string.format("PAL%d: ", pal))
  for col=0,15 do
    local w = memory.read_u16_be(pal*32 + col*2, "CRAM")
    f:write(string.format("%04X ", w))
  end
  f:write("\n")
end
-- Also dump a few OAM entries to see sprite palette bits used by items
f:write("\n# Sprite Attribute Table (VRAM $F800, first 16 sprites):\n")
for i=0,15 do
  local base = 0xF800 + i*8
  local w0 = memory.read_u16_be(base, "VRAM")
  local w1 = memory.read_u16_be(base+2, "VRAM")
  local w2 = memory.read_u16_be(base+4, "VRAM")
  local w3 = memory.read_u16_be(base+6, "VRAM")
  f:write(string.format("SPR%02d: Y=%04X size/link=%04X tile=%04X X=%04X  pal=%d\n",
    i, w0, w1, w2, w3, math.floor(w2/8192) % 4))
end
f:close()
client.screenshot("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/cram_items.png")
client.exit()
