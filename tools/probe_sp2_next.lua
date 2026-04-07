-- Screenshot the frame AFTER state (phase=1 sub=2 curV=$40 nt=1) is first reached,
-- to check whether the VRAM written during that NMI actually displays next frame
-- (testing the off-by-one hypothesis for missing FAIRY/CLOCK labels).
local system = emu.getsystemid() or "?"
local is_gen = (system == "GEN" or system == "SAT")
local LABEL = is_gen and "gen" or "nes"
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/sp2_next"

local rd
if is_gen then rd = function(a) return memory.read_u8(a, "68K RAM") end
else rd = function(a) return mainmemory.read_u8(a) end end

local frame = 0
while frame < 5000 do
  emu.frameadvance()
  frame = frame + 1
  local phase = rd(0x42C)
  local sub   = rd(0x42D)
  local curV  = rd(0xFC)
  local ctrl  = rd(0xFF)
  local nt    = (ctrl % 4 >= 2) and 1 or 0
  if phase == 1 and sub == 2 and curV == 0x40 and nt == 1 then break end
end

-- Screenshot the trigger frame AND the next few frames.
for i=0,3 do
  client.screenshot(string.format("%s/%s_cV40nt1_plus%d_f%05d.png", OUT, LABEL, i, frame+i))
  if i < 3 then emu.frameadvance() end
end
client.exit()
