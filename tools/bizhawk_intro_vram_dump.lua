-- Dump Plane A nametable (VRAM $C000, 64x64 v64) at a chosen intro frame.
-- Subphase2 story scroll. Shows what tile indices are actually in each row so
-- we can tell whether StoryTileAttrTransferBuf landed in VRAM or whether the
-- v64 blank fill is dominating.
--
-- Plane A map is at VRAM $C000 (32 tiles wide x 64 rows = 4096 bytes).

local FRAME = 1469
local OUT = string.format(
  "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_vram_dump_f%05d.txt",
  FRAME
)

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

advance_to(FRAME)

local fh = io.open(OUT, "w")
memory.usememorydomain("VRAM")

fh:write(string.format("Plane A nametable dump at Genesis frame %d\n", FRAME))
fh:write("VRAM base $C000, 64 cols wide, 64 rows tall\n")
fh:write("Each cell = tile index (low byte of map word)\n\n")

-- Dump the full 64-row v64 map so wrap-tail rows 60..63 are visible too.
for row = 0, 63 do
  local addr = 0xC000 + row * 64 * 2  -- 64-wide plane, 2 bytes per cell
  fh:write(string.format("r%02d: ", row))
  for col = 0, 31 do
    local w = memory.read_u16_be(addr + col * 2)
    fh:write(string.format("%03X ", w & 0x7FF))
  end
  fh:write("\n")
end

fh:write("\n--- CRAM (palettes) ---\n")
memory.usememorydomain("CRAM")
for pal = 0, 3 do
  fh:write(string.format("PAL%d: ", pal))
  for slot = 0, 15 do
    fh:write(string.format("%03X ", memory.read_u16_be(pal * 32 + slot * 2)))
  end
  fh:write("\n")
end

fh:write("\n--- VSRAM ---\n")
memory.usememorydomain("VSRAM")
fh:write(string.format("VSRAM[0]=%04X\n", memory.read_u16_be(0)))
fh:write(string.format("VSRAM[1]=%04X\n", memory.read_u16_be(2)))

fh:write("\n--- HINT Queue State ---\n")
memory.usememorydomain("68K RAM")
fh:write(string.format("HINT_Q_COUNT=%02X\n", memory.read_u8(0x0816)))
fh:write(string.format("HINT_Q0_CTR=%02X\n", memory.read_u8(0x0817)))
fh:write(string.format("HINT_Q0_VSRAM=%04X\n", memory.read_u16_be(0x0818)))
fh:write(string.format("HINT_PEND_SPLIT=%02X\n", memory.read_u8(0x081E)))
fh:write(string.format("PPU_SCRL_X=%02X\n", memory.read_u8(0x0806)))
fh:write(string.format("PPU_SCRL_Y=%02X\n", memory.read_u8(0x0807)))

fh:close()
client.exit()
