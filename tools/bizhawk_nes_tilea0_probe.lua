-- Dump NES CHR RAM/ROM for sprite tile $A0 at f700.
-- NES uses 1bpp pairs: 16 bytes per tile. Tile $A0 at $0A00-$0A0F in PPU pattern table 0.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/nes_tile_a0.txt"
local fh = io.open(OUT, "w")
while emu.framecount() < 700 do emu.frameadvance() end

local function dump_nes(addr, label)
  fh:write(string.format("%s NES pattern $%04X:\n", label, addr))
  local lo = {}
  local hi = {}
  for i = 0, 7 do lo[i] = memory.read_u8(addr+i,  "PPU") end
  for i = 0, 7 do hi[i] = memory.read_u8(addr+8+i,"PPU") end
  for r = 0, 7 do
    local row = ""
    for c = 0, 7 do
      local bit = 7-c
      local b0 = (lo[r] >> bit) & 1
      local b1 = (hi[r] >> bit) & 1
      local v = b0 | (b1 << 1)
      row = row .. tostring(v)
    end
    fh:write("  " .. row .. "\n")
  end
end

fh:write("=== NES pattern tile $A0 (sprite bank 0) ===\n")
dump_nes(0x0A00, "$A0")
fh:write("=== NES pattern tile $A0 (bank 1 / $1A00) ===\n")
dump_nes(0x1A00, "$A0b1")
-- Also scan nearby title screen sprite tiles
for _, t in ipairs({0x9F, 0xA1, 0xA2, 0x70, 0x71}) do
  dump_nes(t*16, string.format("$%02X", t))
end
fh:close()
client.exit()
