-- probe_roomrom_bomb.lua — cycle B-item to BOMB, press B, capture
-- through fuse + explosion.

local OUT_DIR = "C:\\tmp"

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

-- Default B-item = BOOMERANG. Z presses to advance: BOOMERANG → ARROW → BOMB (2 presses).
press_held({ Z = true, ["P1 Z"] = true }, 1); settle(4)
press_held({ Z = true, ["P1 Z"] = true }, 1); settle(4)

-- Face down (already default).
press_held({ Down = true, ["P1 Down"] = true }, 6); settle(2)

-- Press B to place bomb.
press_held({ B = true, ["P1 B"] = true }, 1); safe_set({})

-- Capture: f15 (fuse), f50 (fuse mid), f70 (just exploded), f80 (mid explosion).
for f = 1, 100 do
    if f == 15 or f == 50 or f == 65 or f == 80 then
        client.screenshot(string.format("%s\\roomrom_bomb_f%02d.png",
            OUT_DIR, f))
    end
    emu.frameadvance()
end

client.exit()
