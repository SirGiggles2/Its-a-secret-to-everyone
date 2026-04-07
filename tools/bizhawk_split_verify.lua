-- Verify whether HBlankISR is actually switching VSRAM mid-frame.
-- At end of frame Lua sees VSRAM values set by the LAST writer.
-- If the split fires: _ags_flush writes VSRAM=0 at vblank, then HBlankISR
--                    writes VSRAM=D0 at scanline 40 → end-of-frame value = D0
-- If the split does NOT fire: _ags_flush writes VSRAM=0 → end-of-frame = 0
-- Compare against expected D0 computed from CurVScroll+8 etc.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/split_verify.txt"
local fh = io.open(OUT, "w")

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

local function sample(f)
  advance_to(f)
  local vsramA = memory.read_u16_be(0, "VSRAM")
  memory.usememorydomain("M68K BUS")
  local qc    = memory.read_u8(0xFF0816)
  local q0c   = memory.read_u8(0xFF0817)
  local q0v   = memory.read_u16_be(0xFF0818)
  local cvs   = memory.read_u8(0xFF00FC)
  local ctrl  = memory.read_u8(0xFF00FF)
  local gm    = memory.read_u8(0xFF0012)
  local dp    = memory.read_u8(0xFF042C)
  local ds    = memory.read_u8(0xFF042D)
  fh:write(string.format(
    "f%04d GM=%02X DP=%02X DS=%02X  VSRAM_A=%04X Q_CNT=%02X Q0_V=%04X  CurVS=%02X Ctrl=%02X\n",
    f, gm, dp, ds, vsramA, qc, q0v, cvs, ctrl))
end

for _, f in ipairs({1700, 1750, 1800, 1850, 1900, 1950, 2000, 2100, 2200, 2400}) do
  sample(f)
end

fh:close()
client.exit()
