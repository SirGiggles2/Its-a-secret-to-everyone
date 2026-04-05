-- T-CHR v8 regression sweep: capture a wide range of scenes to catch
-- anything we broke beyond the intro/items screens.
local OUT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/builds/reports/"

local function advance_to(target)
  while emu.framecount() < target do emu.frameadvance() end
end

-- Intro / title / items baseline
advance_to(90);    client.screenshot(OUT .. "v8reg_f0090_boot.png")
advance_to(600);   client.screenshot(OUT .. "v8reg_f0600_title.png")
advance_to(2000);  client.screenshot(OUT .. "v8reg_f2000_intro.png")
advance_to(2400);  client.screenshot(OUT .. "v8reg_f2400_items.png")

-- File select + name entry + gameplay approach (title loops back so these
-- may or may not be reached; just snapshot whatever is on-screen).
advance_to(3200);  client.screenshot(OUT .. "v8reg_f3200.png")
advance_to(4000);  client.screenshot(OUT .. "v8reg_f4000.png")
advance_to(5000);  client.screenshot(OUT .. "v8reg_f5000.png")
advance_to(6000);  client.screenshot(OUT .. "v8reg_f6000.png")

client.exit()
