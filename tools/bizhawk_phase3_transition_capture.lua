local out_path = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\builds\reports\bizhawk_phase3_transition.png]]
local info_path = [[C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\builds\reports\bizhawk_phase3_transition.txt]]

local function frame_with_input(pad)
  joypad.set(pad)
  emu.frameadvance()
end

for _ = 1, 20 do
  frame_with_input({})
end

for _ = 1, 75 do
  frame_with_input({ ["P1 Right"] = true })
end

client.screenshot(out_path)

local fh = io.open(info_path, "w")
if fh then
  fh:write("capture_frame=", emu.framecount(), "\n")
  fh:close()
end

client.exit()
