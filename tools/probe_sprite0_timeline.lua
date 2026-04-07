-- Find where IsSprite0CheckActive (NES $00E3) goes non-zero during the intro.
local system = emu.getsystemid() or "?"
local is_gen = (system == "GEN" or system == "SAT")
local LABEL = is_gen and "gen" or "nes"
local out = io.open("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/sprite0_timeline_" .. LABEL .. ".txt", "w")
out:write(string.format("# label=%s system=%s\n", LABEL, system))
out:write("# frame,gameMode,phase,subphase,curV,ppuCtrl,E3_sprite0Act,E2_vsLo,58_vsHi\n")
local rd
if is_gen then
  rd = function(a) return memory.read_u8(a, "68K RAM") end
else
  rd = function(a) return mainmemory.read_u8(a) end
end
local frame = 0
local last_e3 = -1
while frame < 4000 do
  emu.frameadvance()
  frame = frame + 1
  local e3 = rd(0xE3)
  if e3 ~= last_e3 or frame % 30 == 0 then
    out:write(string.format("%d,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X\n",
      frame, rd(0x12), rd(0x42C), rd(0x42D), rd(0xFC), rd(0xFF), e3, rd(0xE2), rd(0x58)))
    last_e3 = e3
  end
end
out:close()
client.exit()
