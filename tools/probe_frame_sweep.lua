-- Screenshot every frame from 2305 to 2315 on Gen, plus log VSRAM + HINT_Q state
-- each frame. We know row 55 has FAIRY/CLOCK for the entire window — so if any
-- frame fails to render them, the answer is in VSRAM / HINT_Q.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/frame_sweep"
local LOG = OUT .. "/frame_sweep_gen.txt"

local function rd8(a) return memory.read_u8(a, "68K RAM") end

local frame = 0
while frame < 2304 do
  emu.frameadvance()
  frame = frame + 1
end

local f = io.open(LOG, "w")
for i=0,15 do
  emu.frameadvance()
  frame = frame + 1
  client.screenshot(string.format("%s/sweep_f%05d.png", OUT, frame))
  local curV = rd8(0xFC)
  local ctrl = rd8(0xFF)
  local nt   = (ctrl % 4 >= 2) and 1 or 0
  local vsram0 = memory.read_u16_be(0, "VSRAM")
  local vsram1 = memory.read_u16_be(2, "VSRAM")
  local hq_count = rd8(0x0816)
  local hq0_ctr  = rd8(0x0817)
  local hq0_v    = memory.read_u16_be(0x0818, "68K RAM")
  local hq1_ctr  = rd8(0x081A)
  local hq1_v    = memory.read_u16_be(0x081B, "68K RAM")
  f:write(string.format(
    "f=%05d curV=%02X nt=%d VSRAM=%04X/%04X HQcnt=%02X Q0ctr=%02X Q0v=%04X Q1ctr=%02X Q1v=%04X\n",
    frame, curV, nt, vsram0, vsram1, hq_count, hq0_ctr, hq0_v, hq1_ctr, hq1_v))
end
f:close()
client.exit()
