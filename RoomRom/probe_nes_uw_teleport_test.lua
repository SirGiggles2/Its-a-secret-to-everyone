-- probe_nes_uw_teleport_test.lua
-- Test whether poking Link's Y coord to "south of room" forces a south-door
-- room transition. If it works, we can iterate all dungeon rooms by
-- repeatedly setting (direction, off-screen-coord).

local OUT_PNG  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_uw_teleport_test.png"
local OUT_JSON = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_uw_teleport_test.json"

local ROOM_ID        = 0x00EB
local CUR_LEVEL      = 0x0010
local GAME_MODE      = 0x0012
local GAME_SUB       = 0x0013
local TARGET_MODE    = 0x005B
local TARGET_MIRROR  = 0x0602
local CUR_SAVE_SLOT  = 0x0016
local NAME_PROGRESS  = 0x0421
local SAVE_ACTIVE0   = 0x0633
local SAVE_ACTIVE1   = 0x0634
local SAVE_ACTIVE2   = 0x0635
local LINK_X         = 0x0070
local LINK_Y         = 0x0084
local LINK_DIR       = 0x0098

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 4
end

local function build_pad()
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
    return pad
end

local function boot_to_overworld()
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME, FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS)
    local name_events = 0
    for frame = 1, 20000 do
        local mode = u8(GAME_MODE)
        local slot = u8(CUR_SAVE_SLOT)
        local name = u8(NAME_PROGRESS)
        local active0 = u8(SAVE_ACTIVE0)
        local active1 = u8(SAVE_ACTIVE1)
        local active2 = u8(SAVE_ACTIVE2)
        if flow == BOOT_TO_FS1 then
            if mode == 0x01 then flow = SELECT_REGISTER else schedule("Start", 2, 3) end
        elseif flow == SELECT_REGISTER then
            if slot == 0x03 then flow = ENTER_REGISTER else schedule("Down", 1, 10) end
        elseif flow == ENTER_REGISTER then
            if mode == 0x0E then flow = TYPE_NAME; last_name = name
            elseif mode == 0x01 then schedule("Start", 2, 14) end
        elseif flow == TYPE_NAME then
            if name ~= last_name then name_events = name_events + 1; last_name = name end
            if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
        elseif flow == FINISH_NAME then
            if mode ~= 0x0E then flow = WAIT_GAMEPLAY
            elseif slot ~= 0x03 then schedule("Select", 1, 10)
            else schedule("Start", 2, 14) end
        elseif flow == WAIT_GAMEPLAY then
            if mode == 0x01 then flow = START_GAME end
        elseif flow == START_GAME then
            if mode ~= 0x01 then flow = WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if active0 == 0 and active1 ~= 0 then target_slot = 0x01
                elseif active0 == 0 and active1 == 0 and active2 ~= 0 then target_slot = 0x02 end
                if slot ~= target_slot then schedule(target_slot > slot and "Down" or "Up", 1, 10)
                else schedule("Start", 2, 14) end
            end
        end
        safe_set(build_pad())
        emu.frameadvance()
        if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(ROOM_ID) == 0x77 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function warp_into_level(level)
    w8(CUR_LEVEL, level)
    w8(TARGET_MODE, 2)
    w8(TARGET_MIRROR, 2)
    w8(GAME_MODE, 0x10)
    w8(GAME_SUB, 0)
    for _ = 1, 600 do
        safe_set({}); emu.frameadvance()
        if u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 and u8(CUR_LEVEL) == level then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function snapshot(label)
    return {
        label = label,
        frame = emu.framecount(),
        cur_level = u8(CUR_LEVEL),
        room_id   = u8(ROOM_ID),
        game_mode = u8(GAME_MODE),
        game_sub  = u8(GAME_SUB),
        link_x    = u8(LINK_X),
        link_y    = u8(LINK_Y),
        link_dir  = u8(LINK_DIR),
    }
end

local results = {}
local system_id = emu.getsystemid() or "?"
local ok_boot = false

if system_id == "NES" then ok_boot = boot_to_overworld() end

if ok_boot then
    warp_into_level(1)
    results[#results + 1] = snapshot("after_warp_l1")

    -- Hard-set Link's Y just below south boundary, direction = down ($04).
    -- South boundary in dungeon play area is around y=$BD.
    print(string.format("entry: room=$%02X x=$%02X y=$%02X dir=$%02X",
        u8(ROOM_ID), u8(LINK_X), u8(LINK_Y), u8(LINK_DIR)))

    -- Test 1: just push Down for 30 frames, see what changes.
    for f = 1, 30 do
        local pad = { Down = true, ["P1 Down"] = true }
        safe_set(pad); emu.frameadvance()
    end
    for _ = 1, 30 do safe_set({}); emu.frameadvance() end
    results[#results + 1] = snapshot("after_30f_down")

    -- Test 2: set Link Y past south edge, dir down, no input.
    w8(LINK_Y, 0xC8)
    w8(LINK_DIR, 0x04)
    for _ = 1, 60 do safe_set({}); emu.frameadvance() end
    results[#results + 1] = snapshot("after_y_C8_dir_down_60f")

    -- Test 3: set Link Y way past edge, hold down to "scroll into next".
    w8(LINK_Y, 0xD8)
    w8(LINK_DIR, 0x04)
    for f = 1, 60 do
        local pad = { Down = true, ["P1 Down"] = true }
        safe_set(pad); emu.frameadvance()
    end
    for _ = 1, 60 do safe_set({}); emu.frameadvance() end
    results[#results + 1] = snapshot("after_y_D8_dir_down_holding")

    client.screenshot(OUT_PNG)
end

local f = assert(io.open(OUT_JSON, "w"))
f:write("{\n")
f:write('  "system_id": "', system_id, '",\n')
f:write('  "boot_ok": ', tostring(ok_boot), ',\n')
f:write('  "results": [\n')
for i, r in ipairs(results) do
    f:write("    {\n")
    f:write('      "label": "', r.label, '",\n')
    f:write('      "frame": ', tostring(r.frame), ',\n')
    f:write('      "cur_level": ', tostring(r.cur_level), ',\n')
    f:write('      "room_id": ', tostring(r.room_id), ',\n')
    f:write('      "game_mode": ', tostring(r.game_mode), ',\n')
    f:write('      "game_sub": ', tostring(r.game_sub), ',\n')
    f:write('      "link_x": ', tostring(r.link_x), ',\n')
    f:write('      "link_y": ', tostring(r.link_y), ',\n')
    f:write('      "link_dir": ', tostring(r.link_dir), '\n')
    f:write("    }")
    if i < #results then f:write(",") end
    f:write("\n")
end
f:write("  ]\n}\n")
f:close()

client.exit()
