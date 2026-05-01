-- probe_roomrom_arrow.lua — fire arrow per facing.
-- Cycle B-item: default BOOMERANG (1) -> ARROW (2) requires 1 Z press.
-- Then press B per facing.

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

-- Cycle B-item once: BOOMERANG -> ARROW.
press_held({ Z = true, ["P1 Z"] = true }, 1)
settle(4)

for _, facing in ipairs(FACINGS) do
    press_held({ [DIR_KEY[facing]] = true,
                 ["P1 " .. DIR_KEY[facing]] = true }, 8)
    settle(2)

    press_held({ B = true, ["P1 B"] = true }, 1)
    safe_set({})

    for f = 1, 30 do
        if f == 4 or f == 12 or f == 20 then
            client.screenshot(string.format("%s\\roomrom_arrow_%s_f%02d.png",
                OUT_DIR, facing, f))
        end
        emu.frameadvance()
    end
    settle(20)
end

client.exit()
