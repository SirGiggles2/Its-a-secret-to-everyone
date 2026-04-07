-- Dump Gen VRAM bytes for NES sprite tile $A0 expanded 4x.
-- Gen tile index = NES_tile + bias, where bias = {0, 0x200, 0x300, 0x400}.
-- So NES $A0 -> Gen $A0, $2A0, $3A0, $4A0.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/tile_4a0_probe.txt"
local fh = io.open(OUT, "w")
while emu.framecount() < 700 do emu.frameadvance() end

local function dump_tile(label, tile)
  local base = tile * 32
  fh:write(string.format("%s tile $%03X @ VRAM $%04X:\n", label, tile, base))
  for r = 0, 7 do
    fh:write("  ")
    for c = 0, 3 do
      fh:write(string.format("%02X ", memory.read_u8(base + r*4 + c, "VRAM")))
    end
    fh:write("\n")
  end
end

fh:write("=== NES sprite tile $A0 expanded 4x ===\n")
dump_tile("copy0", 0x0A0)
dump_tile("copy1", 0x2A0)
dump_tile("copy2", 0x3A0)
dump_tile("copy3", 0x4A0)

fh:write("\n=== Tiles around $4A0 (sub-pal 3, nearby NES indices) ===\n")
for t = 0x49E, 0x4A6 do dump_tile("nb", t) end

fh:write("\n=== NES OAM sprites 22-27 read via saved ROM? skip. Dump SAT entries for sword-middle ===\n")
for i = 20, 35 do
  local base = 0xF800 + i*8
  local y  = memory.read_u16_be(base+0, "VRAM")
  local sz = memory.read_u16_be(base+2, "VRAM")
  local at = memory.read_u16_be(base+4, "VRAM")
  local x  = memory.read_u16_be(base+6, "VRAM")
  fh:write(string.format("sat %02d: Y=%04X SL=%04X AT=%04X X=%04X\n", i, y, sz, at, x))
end

fh:close()
client.exit()
