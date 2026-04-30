-- probe_roomrom_uw_redux_toggle.lua
-- Boot RoomRom, switch to dungeon scene, navigate to room $73, screenshot
-- original. Press C, screenshot redux. Press C again, screenshot original.

local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\"

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local function press(button, hold, gap)
    input_state.button = button
    input_state.hold_left = hold or 4
    input_state.release_left = 0
    input_state.release_after = gap or 14
end

local function tick()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    safe_set(pad)
    emu.frameadvance()
end

for _ = 1, 60 do tick() end

press("B", 4, 30)
for _ = 1, 50 do tick() end

for r = 1, 7 do
    press("Down", 4, 20); for _ = 1, 28 do tick() end
end
for c = 1, 3 do
    press("Right", 4, 20); for _ = 1, 28 do tick() end
end
for _ = 1, 30 do tick() end
client.screenshot(OUT_DIR .. "uwtgl_l1r73_original.png")

press("C", 4, 30)
for _ = 1, 50 do tick() end
client.screenshot(OUT_DIR .. "uwtgl_l1r73_redux.png")

press("C", 4, 30)
for _ = 1, 50 do tick() end
client.screenshot(OUT_DIR .. "uwtgl_l1r73_back_to_original.png")

client.exit()
