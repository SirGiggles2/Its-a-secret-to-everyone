-- capture_full_loop.lua
-- Captures every 5 frames from 0 to END_FRAME for full intro loop analysis.
-- Reads via OUT_DIR + END_FRAME env vars so same script works for NES and Gen.

local OUT_DIR   = os.getenv("CAPTURE_OUT_DIR") or "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/loop_capture"
local END_FRAME = tonumber(os.getenv("CAPTURE_END_FRAME") or "6500") or 6500
local STEP      = tonumber(os.getenv("CAPTURE_STEP") or "5") or 5
local PREFIX    = os.getenv("CAPTURE_PREFIX") or "f"

local function fc()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while fc() < END_FRAME do
    emu.frameadvance()
    local f = fc()
    if f > 0 and f % STEP == 0 then
        client.screenshot(OUT_DIR .. "/" .. PREFIX .. string.format("%05d", f) .. ".png")
    end
end
