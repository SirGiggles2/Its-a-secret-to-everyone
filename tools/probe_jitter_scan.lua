-- Screenshot every 4 frames from f1500 to f3500 on Gen, plus log VSRAM +
-- HINT_Q state. 500 screenshots covers the full items scroll window. Used to
-- spot jitter events where labels shift position between consecutive captures.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/jitter_scan"
local LOG = OUT .. "/jitter_scan_gen.txt"

local function rd8(a) return memory.read_u8(a, "68K RAM") end

local frame = 0
while frame < 1500 do
  emu.frameadvance()
  frame = frame + 1
end

local f = io.open(LOG, "w")
while frame < 3500 do
  emu.frameadvance()
  frame = frame + 1
  local curV = rd8(0xFC)
  local ctrl = rd8(0xFF)
  local nt   = (ctrl % 4 >= 2) and 1 or 0
  local vsram0 = memory.read_u16_be(0, "VSRAM")
  local hq_count = rd8(0x0816)
  local hq0_ctr  = rd8(0x0817)
  local hq0_v    = memory.read_u16_be(0x0818, "68K RAM")
  f:write(string.format(
    "f=%05d curV=%02X nt=%d VSRAM=%04X HQcnt=%d Q0ctr=%3d Q0v=%04X\n",
    frame, curV, nt, vsram0, hq_count, hq0_ctr, hq0_v))
  -- Screenshot every 4 frames
  if frame % 4 == 0 then
    client.screenshot(string.format("%s/jit_f%05d.png", OUT, frame))
  end
end
f:close()
client.exit()
