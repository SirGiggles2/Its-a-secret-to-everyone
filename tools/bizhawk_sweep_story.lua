local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/intro_sweep/"
local function advance_to(t) while emu.framecount() < t do emu.frameadvance() end end
for _,f in ipairs({1050,1100,1150,1200,1250,1300,1350,1400,1450,1500,1600,1700,1800,2000,2200}) do
  advance_to(f)
  client.screenshot(OUT .. string.format("gen_f%04d.png", f))
end
client.exit()
