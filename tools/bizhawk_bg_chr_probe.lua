-- Dump VRAM bytes for BG tiles 0x1C0-0x1D0 (sword middle area).
-- Each tile is 32 bytes (4bpp, 8x8).
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/bg_chr_probe.txt"
local fh = io.open(OUT, "w")
while emu.framecount() < 700 do emu.frameadvance() end

fh:write("=== BG CHR tiles $1C0-$1D0 (sword middle row) at f700 ===\n")
for tile = 0x1C0, 0x1D0 do
  local base = tile * 32
  fh:write(string.format("tile $%03X @ VRAM $%04X:\n  ", tile, base))
  for i = 0, 31 do
    fh:write(string.format("%02X ", memory.read_u8(base+i, "VRAM")))
    if i == 15 then fh:write("\n  ") end
  end
  fh:write("\n")
end
fh:close()
client.exit()
