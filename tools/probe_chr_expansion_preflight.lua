-- CHR-expansion pre-flight probe.
-- Validates 3 assumptions before we refactor CHR upload + OAM DMA:
--   A) PPUCTRL bit 3 (sprite pattern table select) = 1 across all
--      sprite-rendering scenes.  If it ever reads 0, _oam_dma cannot safely
--      hardcode the sprite tile base at $100.
--   B) In 8x16 mode (PPUCTRL bit 5 = 1), the OAM tile byte bit 0 is never
--      set.  If it is, sprite tiles span both 4KB CHR halves and the 4x
--      copy layout must be expanded.
--   C) Sprite CHR upload volume per NMI (via CHR_HIT_COUNT delta) stays
--      inside a budget that supports 4x expansion in VBlank.
--
-- Sampling: every 10 frames from boot to f3500, plus dense bursts at
-- known upload moments.  Logs to reports/chr_preflight.txt.

local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/chr_preflight.txt"
local f = io.open(OUT, "w")
f:write("# CHR-expansion pre-flight probe\n")
f:write("# cols: frame  ppuctrl  spr_tbl(bit3)  8x16(bit5)  chr_hits  oam_8x16_bit0_any\n\n")

-- NES 2C02 state is in 68K RAM at known WHAT-IF offsets.
-- PPU_CTRL shadow is at NES_RAM_BASE ($FF0000) + $2000? Actually it's
-- tracked at PPU_CTRL equate. From nes_io.asm, PPU_CTRL is at $FF0800+$02
-- region. Let's read the actual 68K address symbolically via memory domain.
-- The safer approach: read the NES 6502 RAM mirror; but _ppu_write_6 writes
-- a shadow we can find. From nes_io.asm line 1289: btst #5,(PPU_CTRL).l.
-- PPU_CTRL address is declared in genesis_shell.asm.  We'll just read the
-- 68K RAM range where PPU shadow lives: likely $FF0800+. Fallback: scan.

-- Simpler/robust: read from 68K RAM at $FF0800 forward; PPU_CTRL is one byte.
-- From genesis_shell.asm PPU_STATE_BASE = $FF0800.  PPU_CTRL is the first byte.

local function rd8(addr) return memory.read_u8(addr, "68K RAM") end
local function rd16be(addr) return memory.read_u16_be(addr, "68K RAM") end

local PPU_CTRL      = 0x0804  -- 68K RAM offset (PPU_STATE_BASE $FF0800 + 4)
local CHR_HIT_COUNT = 0x0834  -- PPU_STATE_BASE + $20 + 20 = $FF0834
local OAM_SHADOW    = 0x0200  -- NES_RAM_BASE $FF0000 + $0200

local last_chr_hits = 0
local frame = 0

-- Scan OAM for 8x16 tile bit-0 usage
local function scan_oam_8x16_bit0()
  local ctrl = rd8(PPU_CTRL)
  if (ctrl & 0x20) == 0 then return "-" end  -- not in 8x16 mode
  local any = false
  for i=0,63 do
    local y   = rd8(OAM_SHADOW + i*4)
    local tile = rd8(OAM_SHADOW + i*4 + 1)
    if y < 240 and (tile & 0x01) == 1 then
      any = true
      break
    end
  end
  if any then return "YES" else return "no" end
end

while frame < 3500 do
  emu.frameadvance()
  frame = frame + 1
  if frame % 10 == 0 then
    local ctrl = rd8(PPU_CTRL)
    local spr_tbl = ((ctrl & 0x08) ~= 0) and 1 or 0
    local big = ((ctrl & 0x20) ~= 0) and 1 or 0
    local hits = rd8(CHR_HIT_COUNT)
    local delta = (hits - last_chr_hits) % 256
    last_chr_hits = hits
    local bit0 = scan_oam_8x16_bit0()
    f:write(string.format("f=%05d ctrl=%02X spr3=%d big5=%d chr_delta=%3d 8x16bit0=%s\n",
      frame, ctrl, spr_tbl, big, delta, bit0))
  end
end

f:close()
client.exit()
