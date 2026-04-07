-- Sweep the intro window to see the story scroll animation on the Genesis
-- build. Dumps a shot every 100 frames from 1400 to 3000.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_sweep/"

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

for f = 1400, 3000, 100 do
  advance_to(f)
  client.screenshot(OUT .. string.format("gen_f%04d.png", f))
end

client.exit()
