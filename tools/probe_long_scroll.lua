-- Long scroll probe: frame, gameMode, phase, subphase, curV, ppuCtrl, nt_select, switchReq.
-- Capture NES (or Gen) state every frame for the full intro (0..3500).
local system = emu.getsystemid() or "?"
local is_gen = (system == "GEN" or system == "SAT")
local LABEL = is_gen and "gen" or "nes"
local out = io.open("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/long_scroll_" .. LABEL .. ".txt", "w")
out:write("# frame,gameMode,phase,subphase,curV,ppuCtrl,switchReq\n")
local rd
if is_gen then
  rd = function(a) return memory.read_u8(a, "68K RAM") end
else
  rd = function(a) return mainmemory.read_u8(a) end
end
local frame = 0
local prev_line
while frame < 3500 do
  emu.frameadvance()
  frame = frame + 1
  local line = string.format("%d,%02X,%02X,%02X,%02X,%02X,%02X",
    frame, rd(0x12), rd(0x42C), rd(0x42D), rd(0xFC), rd(0xFF), rd(0x5C))
  -- Only log frames where state differs from previous (change detection)
  local key = line:sub(line:find(",")+1)
  if key ~= prev_line then
    out:write(line.."\n")
    prev_line = key
  end
end
out:close()
client.exit()
