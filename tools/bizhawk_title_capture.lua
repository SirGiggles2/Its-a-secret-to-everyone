local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/title_cmp/"
local function advance_to(t) while emu.framecount() < t do emu.frameadvance() end end
for _,f in ipairs({350,400,500,600,650,700,750}) do
  advance_to(f)
  client.screenshot(OUT .. string.format("gen_f%04d.png", f))
end
client.exit()
