-- Dump the raw 32-byte VRAM data for tile $124 (the "blank" tile rendering
-- as a blue/white checker on Genesis) at f1900, plus the full plane A map
-- words for row 5 (one of the "between text" rows) to see palette bits.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/blank_tile_dump.txt"

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

advance_to(1900)

local fh = io.open(OUT, "w")
memory.usememorydomain("VRAM")

-- Tile $124 = VRAM byte addr $2480, 32 bytes
fh:write("Tile $124 (NES blank char w/ BG base $1000) — 32 bytes from VRAM $2480:\n")
local base = 0x124 * 32
for i = 0, 31 do
  if i % 8 == 0 then fh:write("\n  ") end
  fh:write(string.format("%02X ", memory.read_u8(base + i)))
end
fh:write("\n\n")

-- Tile $024 for comparison (NES blank with BG base $0000)
fh:write("Tile $024 (NES blank w/ BG base $0000) — 32 bytes from VRAM $480:\n")
base = 0x24 * 32
for i = 0, 31 do
  if i % 8 == 0 then fh:write("\n  ") end
  fh:write(string.format("%02X ", memory.read_u8(base + i)))
end
fh:write("\n\n")

-- Plane A row 5 map words (to see palette bits)
fh:write("Plane A row 5 (between text) — 32 cells, full 16-bit map words:\n")
local r5 = 0xC000 + 5 * 64 * 2
for c = 0, 31 do
  if c % 8 == 0 then fh:write("\n  ") end
  fh:write(string.format("%04X ", memory.read_u16_be(r5 + c * 2)))
end
fh:write("\n\n")

-- Plane A row 4 map words (text row "THE LEGEND OF ZELDA")
fh:write("Plane A row 4 (title) — 32 cells, full 16-bit map words:\n")
local r4 = 0xC000 + 4 * 64 * 2
for c = 0, 31 do
  if c % 8 == 0 then fh:write("\n  ") end
  fh:write(string.format("%04X ", memory.read_u16_be(r4 + c * 2)))
end
fh:write("\n")

fh:close()
client.exit()
