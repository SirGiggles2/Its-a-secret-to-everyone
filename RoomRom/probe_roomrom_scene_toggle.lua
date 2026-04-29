-- probe_roomrom_scene_toggle.lua
-- Verify scene toggle (button B) + level cycle (button A) work in RoomRom.

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
    input_state.release_after = gap or 8
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

-- Settle on OW
for _ = 1, 60 do tick() end
client.screenshot(OUT_DIR .. "scene_ow_initial.png")

-- Press B -> dungeon scene
press("B", 4, 30)
for _ = 1, 40 do tick() end
client.screenshot(OUT_DIR .. "scene_uw_level1.png")

-- Press A -> level 2
press("A", 4, 30)
for _ = 1, 40 do tick() end
client.screenshot(OUT_DIR .. "scene_uw_level2.png")

-- Press A again -> level 3
press("A", 4, 30)
for _ = 1, 40 do tick() end
client.screenshot(OUT_DIR .. "scene_uw_level3.png")

-- D-pad right -> next dungeon room
press("Right", 4, 30)
for _ = 1, 40 do tick() end
client.screenshot(OUT_DIR .. "scene_uw_level3_room1.png")

-- Press C -> redux dungeon
press("C", 4, 30)
for _ = 1, 40 do tick() end
client.screenshot(OUT_DIR .. "scene_uw_level3_room1_redux.png")

-- Press B -> back to OW
press("B", 4, 30)
for _ = 1, 40 do tick() end
client.screenshot(OUT_DIR .. "scene_ow_returned.png")

client.exit()
