-- capture_nes_intro.lua
-- Captures one screenshot every 30 frames from frame 0 to 2400.
-- Drop into BizHawk with NES core + Zelda ROM loaded.

local OUT_DIR = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/tools/intro_demo/nes_capture"
local START_FRAME = 0
local END_FRAME   = 2400
local STEP        = 30

local function emu_frame()
    local ok, v = pcall(function() return emu.framecount() end)
    return ok and v or 0
end

while emu_frame() < END_FRAME do
    emu.frameadvance()
    local f = emu_frame()
    if f >= START_FRAME and (f - START_FRAME) % STEP == 0 then
        client.screenshot(OUT_DIR .. "/nes_f" .. string.format("%05d", f) .. ".png")
    end
end
