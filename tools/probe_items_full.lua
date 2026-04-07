-- Comprehensive items-phase probe:
--   * Screenshot + full 80-sprite dump at several frames
--   * Plane A VRAM tile palette-bits histogram at each frame
--   * CRAM snapshot
-- Goal: determine whether items render as BG tiles or sprites, and what
-- palette index they use, so we can stop guessing and fix the right path.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/items_full"
os.execute('mkdir "' .. OUT:gsub("/", "\\") .. '" 2>nul')
local LOG = OUT .. "/items_full.txt"

local targets = {1800, 2000, 2200, 2400, 2600, 2800, 3000}
local ti = 1
local frame = 0

local f = io.open(LOG, "w")

local function dump_cram()
  f:write("  CRAM:\n")
  for pal=0,3 do
    f:write(string.format("    PAL%d: ", pal))
    for col=0,15 do
      local w = memory.read_u16_be(pal*32 + col*2, "CRAM")
      f:write(string.format("%04X ", w))
    end
    f:write("\n")
  end
end

local function dump_sprites()
  f:write("  Visible sprites (Y in [128,352], X in [128,448]):\n")
  local n = 0
  for i=0,79 do
    local base = 0xF800 + i*8
    local y    = memory.read_u16_be(base,   "VRAM")
    local sl   = memory.read_u16_be(base+2, "VRAM")
    local tw   = memory.read_u16_be(base+4, "VRAM")
    local x    = memory.read_u16_be(base+6, "VRAM")
    if y >= 128 and y <= 352 and x >= 128 and x <= 448 then
      local pal = math.floor(tw/8192) % 4
      f:write(string.format("    SPR%02d: screenY=%3d screenX=%3d tile=%04X pal=%d size=%02X\n",
        i, y-128, x-128, tw, pal, math.floor(sl/256)))
      n = n + 1
    end
  end
  f:write(string.format("  (%d visible sprites)\n", n))
end

local function dump_plane_a_hist()
  -- Plane A is at $C000, 64x64 = 4096 words = 8192 bytes
  -- Count palette-bit distribution for non-zero tiles
  local hist = {0, 0, 0, 0}
  local nonzero = 0
  for addr=0xC000, 0xDFFE, 2 do
    local w = memory.read_u16_be(addr, "VRAM")
    local tile = w % 2048
    if tile ~= 0 then
      nonzero = nonzero + 1
      local pal = math.floor(w/8192) % 4
      hist[pal+1] = hist[pal+1] + 1
    end
  end
  f:write(string.format("  Plane A nonzero tiles=%d  pal histogram: P0=%d P1=%d P2=%d P3=%d\n",
    nonzero, hist[1], hist[2], hist[3], hist[4]))
end

while ti <= #targets do
  emu.frameadvance()
  frame = frame + 1
  if frame == targets[ti] then
    f:write(string.format("\n=== frame %d ===\n", frame))
    dump_cram()
    dump_sprites()
    dump_plane_a_hist()
    client.screenshot(string.format("%s/items_f%05d.png", OUT, frame))
    ti = ti + 1
  end
end
f:close()
client.exit()
