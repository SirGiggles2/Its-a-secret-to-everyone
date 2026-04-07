-- Log every PPUDATA ($2007) write during a window around the sp2 curV=$40 nt=1 trigger,
-- on both NES and Gen, so we can diff exactly when each NT tile is written.
--
-- NES: use mainmemory execute callback via debugger; easier approach = poll the
-- emulated CPU PC each instruction via memory.registerexec at the STA $2007
-- instruction addresses. Simplest approach: hook $2007 write via memory.register_write.
--
-- Gen: hook _ppu_write_7 entry in 68K code, log PPU_VADDR + byte + frame.
--
-- Since _ppu_write_7's address differs per build, we instead hook the NES $2007
-- write register on both cores via memory.registerwrite on address $2007 in the
-- "System Bus"/"PPU Bus" domain for NES, or by tracking PPU_VADDR + A-side changes.
--
-- For simplicity and portability, we poll every frame and dump the current plane-A
-- NT_B row 25 (tile idx span where FAIRY/CLOCK live) plus NES $2825 region bytes.
-- This tells us, frame-by-frame, when those specific tiles become non-background.
--
-- Output: ppudata_log_<label>.txt

local system = emu.getsystemid() or "?"
local is_gen = (system == "GEN" or system == "SAT")
local LABEL = is_gen and "gen" or "nes"
local out = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/ppudata_log_" .. LABEL .. ".txt"

local function rd8(a)
  if is_gen then return memory.read_u8(a, "68K RAM")
  else return mainmemory.read_u8(a) end
end

-- On NES: read PPU Bus $2800 nametable directly
-- On Gen: read VRAM plane A row 55 (plane Y = NT_B row 25) directly
local function read_label_row()
  local bytes = {}
  if is_gen then
    -- Plane A row 55, cols 0-31 (16-bit words). Extract tile index low byte.
    for col=0,31 do
      local w = memory.read_u16_be(0xC000 + 55*0x80 + col*2, "VRAM")
      bytes[col+1] = w % 256
    end
  else
    -- NES NT_B ($2800) row 25, cols 0-31
    for col=0,31 do
      bytes[col+1] = memory.read_u8(0x2800 + 25*32 + col, "PPU Bus")
    end
  end
  return bytes
end

local function bytes_to_hex(b)
  local s = ""
  for i=1,32 do s = s .. string.format(" %02X", b[i]) end
  return s
end

-- Log row 55 from frame 2280 onward (well before trigger at ~2310) to see when it
-- first gets populated. This captures the PRE-trigger write history.
local frame = 0
local trigger = -1
local log_start = is_gen and 2295 or 2275
local log_end   = is_gen and 2320 or 2300

local f = io.open(out, "w")
f:write(string.format("label=%s log_range=%d..%d\n", LABEL, log_start, log_end))
f:write("format: frame curV sub phase | row55_tile_lo_bytes (32)\n")

while frame < log_end do
  emu.frameadvance()
  frame = frame + 1
  if frame >= log_start then
    local curV = rd8(0xFC)
    local sub  = rd8(0x42D)
    local phase = rd8(0x42C)
    local b = read_label_row()
    f:write(string.format("f=%05d curV=%02X sub=%02X ph=%02X |%s\n",
      frame, curV, sub, phase, bytes_to_hex(b)))
  end
end
f:close()
client.exit()
