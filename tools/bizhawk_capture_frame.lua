local out_path = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\builds\reports\bizhawk_capture.png]]
local info_path = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\builds\reports\bizhawk_capture.txt]]

for _ = 1, 90 do
  emu.frameadvance()
end

client.screenshot(out_path)

local fh = io.open(info_path, "w")
if fh then
  fh:write("capture_frame=", emu.framecount(), "\n")
  fh:close()
end

client.exit()
