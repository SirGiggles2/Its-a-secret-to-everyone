local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_sweep/"
local function advance_to(t) while emu.framecount() < t do emu.frameadvance() end end
for _,f in ipairs({200,400,600,800,900,1000,1100,1200,1300}) do
  advance_to(f)
  client.screenshot(OUT .. string.format("gen_f%04d.png", f))
end
client.exit()
