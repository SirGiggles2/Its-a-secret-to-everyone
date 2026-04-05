-- S3-S7 verification probe for CHR expansion rollout.
--
-- Goal: prove that enabling CHR_EXPANSION_ENABLED with S3-S7 wired (but
-- S8/S9 not yet done) produces a ROM that is visually identical to the
-- flag=0 baseline at key scenes.
--
-- Expected outcome:
--   * Copy 0 at Gen VRAM $0000-$1FFF is bit-identical to the baseline
--     sprite CHR upload (bias +0 = no-op).
--   * Copies 1/2/3 at $4000/$6000/$8000 get written but OAM never
--     references them (S9 not done yet), so they are harmless.
--   * All CRAM, Plane A contents, sprite attr tables identical.
--
-- Samples 4 scenes: boot splash, title, story intro, items.
-- For each, dumps CRAM + VRAM region hashes + screenshot.

local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/chr_s7_verify/"
local TXT     = OUT_DIR .. "s7_verify.txt"

-- Ensure directory exists by attempting to open a file there
local f = io.open(TXT, "w")
if not f then
  -- directory may not exist; try the simple path
  TXT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/chr_s7_verify.txt"
  f = io.open(TXT, "w")
end

f:write("# CHR expansion S3-S7 verification probe\n")
f:write("# Build tag written by probe caller\n\n")

local function hash_region(domain, base, size)
  -- Simple FNV-1a-like 32-bit hash over bytes.
  local h = 0x811C9DC5
  for i = 0, size - 1 do
    local b = memory.read_u8(base + i, domain)
    h = (h ~ b) & 0xFFFFFFFF
    h = (h * 16777619) & 0xFFFFFFFF
  end
  return h
end

local function dump_scene(label, target_frame)
  while emu.framecount() < target_frame do
    emu.frameadvance()
  end

  f:write(string.format("=== %s  frame=%d ===\n", label, emu.framecount()))

  -- CRAM (4 palettes x 16 entries x 2 bytes = 128 bytes)
  f:write("  CRAM:\n")
  for pal = 0, 3 do
    f:write(string.format("    PAL%d:", pal))
    for i = 0, 15 do
      local w = memory.read_u16_be(pal * 32 + i * 2, "CRAM")
      f:write(string.format(" %04X", w))
    end
    f:write("\n")
  end

  -- VRAM region hashes
  local h_sp0 = hash_region("VRAM", 0x0000, 0x2000)  -- sprite copy 0
  local h_bg  = hash_region("VRAM", 0x2000, 0x2000)  -- BG pattern
  local h_sp1 = hash_region("VRAM", 0x4000, 0x2000)  -- sprite copy 1 (new)
  local h_sp2 = hash_region("VRAM", 0x6000, 0x2000)  -- sprite copy 2 (new)
  local h_sp3 = hash_region("VRAM", 0x8000, 0x2000)  -- sprite copy 3 (new)
  local h_plA = hash_region("VRAM", 0xC000, 0x2000)  -- Plane A

  f:write(string.format("  VRAM: sp0=%08X bg=%08X sp1=%08X sp2=%08X sp3=%08X planeA=%08X\n",
    h_sp0, h_bg, h_sp1, h_sp2, h_sp3, h_plA))

  -- Dump first 4 tiles (128 bytes) of sprite copy 0 in hex for direct diff
  f:write("  VRAM $0000-$007F (first 4 tiles of copy 0):\n")
  for row = 0, 7 do
    f:write("    ")
    for col = 0, 15 do
      f:write(string.format("%02X ", memory.read_u8(row*16 + col, "VRAM")))
    end
    f:write("\n")
  end
  -- Also dump first tile of copy 1 for comparison
  f:write("  VRAM $4000-$401F (first tile of copy 1):\n")
  f:write("    ")
  for col = 0, 31 do
    f:write(string.format("%02X ", memory.read_u8(0x4000 + col, "VRAM")))
  end
  f:write("\n\n")
end

dump_scene("boot",  90)
dump_scene("title", 600)
dump_scene("intro", 2000)
dump_scene("items", 2400)

f:close()
client.exit()
