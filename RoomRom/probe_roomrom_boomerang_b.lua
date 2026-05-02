-- probe_roomrom_boomerang_b.lua
-- Default B-item is BOOMERANG; press B to throw, screenshot mid-flight.
-- Output: C:\tmp\boom_<facing>_<tag>.png

local OUT_DIR = "C:\\tmp"
local FACINGS = { "down", "up", "left", "right" }
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

    press_held({ B = true, ["P1 B"] = true }, 1)
    safe_set({})

    for f = 1, 70 do
        if f == 8 or f == 24 or f == 48 then
            client.screenshot(string.format("%s\\boom_%s_f%02d.png",
                OUT_DIR, facing, f))
        end
        emu.frameadvance()
    end
    settle(40)
end

client.exit()
