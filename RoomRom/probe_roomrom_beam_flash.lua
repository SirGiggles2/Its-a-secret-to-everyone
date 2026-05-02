-- probe_roomrom_beam_flash.lua
-- Capture 4 CONSECUTIVE frames during beam flight to verify palette flash.
-- 4 frames = full NES color cycle (FrameCounter & 3 = 0,1,2,3).
-- Output: C:\tmp\beam_flash_<facing>_f<NN>.png

local OUT_DIR = "C:\\tmp"
local FACINGS = { "right", "up" }
local DIR_KEY = { down="Down", up="Up", left="Left", right="Right" }

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
end

local function press_held(pad, hold)
    for _ = 1, (hold or 1) do safe_set(pad); emu.frameadvance() end
end

settle(180)

for _, facing in ipairs(FACINGS) do
    local dir_pad = { [DIR_KEY[facing]] = true,
                      ["P1 " .. DIR_KEY[facing]] = true }
    press_held(dir_pad, 8)
    settle(2)

    press_held({ A = true, ["P1 A"] = true }, 1)
    safe_set({})

    -- Beam spawns ~13 frames after swing start. Capture frames 16-23
    -- consecutively (8 frames = 2 full color cycles).
    for f = 1, 30 do
        if f >= 16 and f <= 23 then
            client.screenshot(string.format("%s\\beam_flash_%s_f%02d.png",
                OUT_DIR, facing, f))
        end
        emu.frameadvance()
    end
    settle(60)
end

client.exit()
