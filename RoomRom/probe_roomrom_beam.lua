-- probe_roomrom_beam.lua
-- Sword beam fires when full HP. RoomRom boots with full HP. Press A to swing
-- sword → beam shoots out blade tip in s_face direction. Capture mid-flight
-- screenshots for all 4 facings.
-- Output: C:\tmp\beam_<facing>_f<NN>.png

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

    -- A press = sword swing → beam spawns at swing peak.
    press_held({ A = true, ["P1 A"] = true }, 1)
    safe_set({})

    -- Beam spawns ~13 frames after swing start. Capture beam mid-flight.
    for f = 1, 60 do
        if f == 16 or f == 24 or f == 36 or f == 48 then
            client.screenshot(string.format("%s\\beam_%s_f%02d.png",
                OUT_DIR, facing, f))
        end
        emu.frameadvance()
    end
    settle(40)
end

client.exit()
