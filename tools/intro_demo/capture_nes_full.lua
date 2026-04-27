-- Capture screenshots every 60 frames from 0 to 6000 to find full intro span.
local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_capture_full"
local STEP = 60
local END_FRAME = 6000

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while fc() < END_FRAME do
    emu.frameadvance()
    local f = fc()
    if f > 0 and f % STEP == 0 then
        client.screenshot(OUT_DIR .. "/nes_f" .. string.format("%05d", f) .. ".png")
    end
end
