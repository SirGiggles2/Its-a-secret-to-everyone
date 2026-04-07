-- Capture a small consecutive frame window for Genesis intro debugging.
-- Uses the same screenshot timing as the full intro capture script, but avoids
-- the cost of dumping 2000+ frames when we only need a tight suspect window.

local START_FRAME = tonumber(os.getenv("INTRO_START") or "1768")
local END_FRAME = tonumber(os.getenv("INTRO_END") or "1778")
local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_window"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

while emu.framecount() < (START_FRAME - 1) do
  emu.frameadvance()
end

while emu.framecount() < END_FRAME do
  emu.frameadvance()
  local frame = emu.framecount()
  if frame >= START_FRAME and frame <= END_FRAME then
    client.screenshot(OUT_DIR .. string.format("/gen_f%05d.png", frame))
  end
end

client.exit()
