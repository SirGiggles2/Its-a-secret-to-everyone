-- Probe Genesis runtime state during intro story scroll window.
-- Reports GameMode / DemoPhase / DemoSubphase / IsSprite0CheckActive and
-- HINT queue state at a set of sample frames across 1200-2000.
--
-- Memory map: NES zero-page / RAM lives at Genesis $FF0000 (68K WRAM).
-- NES $0012 -> $FF0012 (GameMode)
-- NES $00E3 -> $FF00E3 (IsSprite0CheckActive)
-- NES $042C -> $FF042C (DemoPhase)
-- NES $042D -> $FF042D (DemoSubphase)
-- HINT_Q_COUNT  = $FF0816
-- HINT_Q0_CTR   = $FF0817
-- HINT_Q0_VSRAM = $FF0818 (word)

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_state_probe.txt"
local fh = io.open(OUT, "w")
memory.usememorydomain("M68K BUS")

local function sample(tag)
  local gm   = memory.read_u8(0xFF0012)
  local s0   = memory.read_u8(0xFF00E3)
  local dp   = memory.read_u8(0xFF042C)
  local ds   = memory.read_u8(0xFF042D)
  local qc   = memory.read_u8(0xFF0816)
  local q0c  = memory.read_u8(0xFF0817)
  local q0v  = memory.read_u16_be(0xFF0818)
  local vs_shadow_hi = memory.read_u8(0xFF00FC)  -- CurVScroll
  local ctrl         = memory.read_u8(0xFF00FF) -- CurPpuControl
  fh:write(string.format(
    "%s f=%d  GameMode=%02X  DemoPhase=%02X  DemoSubphase=%02X  IsSpr0=%02X  " ..
    "HINT_Q_CNT=%02X  Q0_CTR=%02X  Q0_VSRAM=%04X  CurVScroll=%02X  PPUCTRL=%02X\n",
    tag, emu.framecount(), gm, dp, ds, s0, qc, q0c, q0v, vs_shadow_hi, ctrl))
end

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

for _, f in ipairs({600, 900, 1100, 1200, 1300, 1400, 1500, 1600, 1800, 2000, 2200, 2400}) do
  advance_to(f)
  sample(string.format("f%04d", f))
end

fh:close()
client.exit()
