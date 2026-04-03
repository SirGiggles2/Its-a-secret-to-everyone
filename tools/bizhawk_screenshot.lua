-- bizhawk_screenshot.lua
-- Takes a screenshot at frame 300 and saves it

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local SCREENSHOT = ROOT .. "builds/reports/screenshot_frame300.png"
local FRAMES = 300

for i = 1, FRAMES do
    emu.frameadvance()
end

client.screenshot(SCREENSHOT)
print("Screenshot saved to: " .. SCREENSHOT)

-- Also run 10 more frames and take another
for i = 1, 100 do emu.frameadvance() end
client.screenshot(ROOT .. "builds/reports/screenshot_frame400.png")
print("Screenshot 2 saved (frame 400)")

client.exit()
