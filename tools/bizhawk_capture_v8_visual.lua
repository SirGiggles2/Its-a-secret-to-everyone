-- T-CHR v8 visual verification: capture title, intro, items scenes.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/"

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

advance_to(90);   client.screenshot(OUT .. "v8_boot.png")
advance_to(600);  client.screenshot(OUT .. "v8_title.png")
advance_to(2000); client.screenshot(OUT .. "v8_intro.png")
advance_to(2400); client.screenshot(OUT .. "v8_items.png")

client.exit()
