-- probe_nes_uw_walk_diag.lua
-- Warp into Level 1, press Up for 1500 frames, log Link state every 30
-- frames to see whether he reaches the north door.

local OUT_LOG = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_uw_walk_diag.txt"

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
    input_state.button = button; input_state.hold_left = hold_frames or 1
    input_state.release_left = 0; input_state.release_after = release_frames or 4
end
local function build_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true; pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then input_state.release_left = input_state.release_after end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

local function boot_to_overworld()
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME, FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
    local flow = BOOT_TO_FS1
    local last_name = u8(NAME_PROGRESS); local name_events = 0
    for frame = 1, 20000 do
        local mode = u8(GAME_MODE); local slot = u8(CUR_SAVE_SLOT); local name = u8(NAME_PROGRESS)
        local active0 = u8(SAVE_ACTIVE0); local active1 = u8(SAVE_ACTIVE1); local active2 = u8(SAVE_ACTIVE2)
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
        safe_set(build_pad()); emu.frameadvance()
        if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0
           and u8(ROOM_ID) == 0x77 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function warp_into_level(level)
    w8(CUR_LEVEL, level); w8(TARGET_MODE, 2); w8(TARGET_MIRROR, 2)
    w8(GAME_MODE, 0x10); w8(GAME_SUB, 0)
    for _ = 1, 600 do
        safe_set({}); emu.frameadvance()
        if u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 and u8(CUR_LEVEL) == level then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local f = assert(io.open(OUT_LOG, "w"))
f:write("# walk diag\n")
f:flush()

if boot_to_overworld() and warp_into_level(1) then
    f:write(string.format("warp_settled: room=$%02X x=$%02X y=$%02X dir=$%02X mode=$%02X sub=$%02X\n",
        u8(ROOM_ID), u8(LINK_X), u8(LINK_Y), u8(LINK_DIR), u8(GAME_MODE), u8(GAME_SUB)))
    f:flush()

    -- Test 1: hold Up 600 frames at default x.
    for f_idx = 1, 600 do
        local pad = { Up = true, ["P1 Up"] = true }
        safe_set(pad); emu.frameadvance()
    end
    f:write(string.format("after_600u: room=$%02X x=$%02X y=$%02X mode=$%02X\n",
        u8(ROOM_ID), u8(LINK_X), u8(LINK_Y), u8(GAME_MODE)))
    f:flush()

    -- Test 2: poke Link's X to north-door-aligned column, hold Up 600.
    w8(LINK_X, 0x78)
    w8(LINK_Y, 0x60)
    w8(LINK_DIR, 0x08)
    for f_idx = 1, 600 do
        local pad = { Up = true, ["P1 Up"] = true }
        safe_set(pad); emu.frameadvance()
    end
    f:write(string.format("after_x78_y60_up: room=$%02X x=$%02X y=$%02X mode=$%02X\n",
        u8(ROOM_ID), u8(LINK_X), u8(LINK_Y), u8(GAME_MODE)))
    f:flush()

    -- Test 3: teleport Link to ABOVE play area, see if engine fires N transition.
    w8(LINK_X, 0x78); w8(LINK_Y, 0x10); w8(LINK_DIR, 0x08)
    for f_idx = 1, 240 do
        safe_set({}); emu.frameadvance()
    end
    f:write(string.format("after_y10_idle: room=$%02X x=$%02X y=$%02X mode=$%02X sub=$%02X lvl=%d\n",
        u8(ROOM_ID), u8(LINK_X), u8(LINK_Y), u8(GAME_MODE), u8(GAME_SUB), u8(CUR_LEVEL)))
    f:flush()

    -- Test 4: poke Link off-screen WITH Up button held to push transition.
    w8(LINK_X, 0x78); w8(LINK_Y, 0x10); w8(LINK_DIR, 0x08)
    for f_idx = 1, 240 do
        local pad = { Up = true, ["P1 Up"] = true }
        safe_set(pad); emu.frameadvance()
    end
    f:write(string.format("after_y10_up: room=$%02X x=$%02X y=$%02X mode=$%02X sub=$%02X lvl=%d\n",
        u8(ROOM_ID), u8(LINK_X), u8(LINK_Y), u8(GAME_MODE), u8(GAME_SUB), u8(CUR_LEVEL)))
    f:flush()

    f:write("done\n")
end

f:close()
client.exit()
