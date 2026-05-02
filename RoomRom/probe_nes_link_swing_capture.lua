-- probe_nes_link_swing_capture.lua
-- Captures FULL Link + sword OAM state during all 4 facing swings.
-- Goal: identify Link's attack-pose body tile IDs per facing (Z1 swaps
-- Link's body sprite during swing — walking-pose Link + floating sword
-- next to him is wrong).
--
-- For each facing (DOWN, UP, LEFT, RIGHT):
--   1. Hold direction 8 frames (set facing, take a step).
--   2. Snapshot full OAM as PRE.
--   3. Press A 3 frames.
--   4. Snapshot full OAM each frame for 16 frames after press.
--
-- All sprites near Link (within ±32 px Y) are captured. Offline diff
-- between PRE and the active frames reveals Link's attack-pose tiles.
--
-- Output: C:\tmp\nes_link_swing.json   {down,up,left,right}.{pre,frames[]}

local OUT_JSON = "C:\\tmp\\nes_link_swing.json"

local CUR_LEVEL          = 0x0010
local GAME_MODE          = 0x0012
local GAME_SUB           = 0x0013
local CUR_SAVE_SLOT      = 0x0016
local ROOM_ID            = 0x00EB
local ROOM_TRANS         = 0x004C
local NAME_PROGRESS      = 0x0421
local SAVE_ACTIVE0       = 0x0633
local SAVE_ACTIVE1       = 0x0634
local SAVE_ACTIVE2       = 0x0635
local LINK_X             = 0x0070
local LINK_Y             = 0x0084
local LINK_FACING        = 0x0098
local SWORD_INVENTORY    = 0x0657

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

local function settle(frames)
    for _ = 1, frames do safe_set({}); emu.frameadvance() end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }
local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 8
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
    local BOOT_TO_FS1, SELECT_REGISTER, ENTER_REGISTER, TYPE_NAME,
          FINISH_NAME, WAIT_GAMEPLAY, START_GAME = 1,2,3,4,5,6,7
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
           and u8(ROOM_ID) == 0x77 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

-- Snapshot all OAM entries within ±32 px Y of Link, on-screen.
local function snapshot_near_link()
    local link_y = u8(LINK_Y)
    local out = {}
    memory.usememorydomain("System Bus")
    for slot = 0, 63 do
        local base = 0x0200 + slot * 4
        local y    = memory.read_u8(base + 0)
        local tile = memory.read_u8(base + 1)
        local attr = memory.read_u8(base + 2)
        local x    = memory.read_u8(base + 3)
        if y < 0xF0 and math.abs(y - link_y) <= 40 then
            table.insert(out, { slot = slot, y = y, tile = tile,
                                attr = attr, x = x })
        end
    end
    return out
end

local DIRS = { down = "Down", up = "Up", left = "Left", right = "Right" }

local function capture_swing(facing_label)
    local dir_button = DIRS[facing_label]
    -- Hold direction 8 frames so engine sets facing AND animates a step
    -- (so we see body tiles in the canonical walk-pose-frame-1 state).
    for _ = 1, 8 do
        safe_set({ [dir_button] = true,
                   ["P1 " .. dir_button] = true })
        emu.frameadvance()
    end
    settle(2)

    local link_x = u8(LINK_X)
    local link_y = u8(LINK_Y)
    local pre = snapshot_near_link()

    -- Press A held 3 frames.
    for _ = 1, 3 do
        safe_set({ A = true, ["P1 A"] = true })
        emu.frameadvance()
    end
    safe_set({})

    -- Capture full OAM each frame for 16 frames.
    local frames = {}
    for f = 1, 16 do
        frames[f] = snapshot_near_link()
        emu.frameadvance()
    end

    settle(40)
    return {
        facing = facing_label,
        link_x = link_x,
        link_y = link_y,
        pre = pre,
        frames = frames,
    }
end

local sysid = emu.getsystemid() or "?"
if sysid ~= "NES" then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("wrong_system_" .. sysid); f:close() end
    client.exit()
end

if not boot_to_overworld() then
    local f = io.open(OUT_JSON .. ".error", "w")
    if f then f:write("boot_failed"); f:close() end
    client.exit()
end

w8(SWORD_INVENTORY, 0x01)
settle(60)

local result = {
    down  = capture_swing("down"),
    up    = capture_swing("up"),
    left  = capture_swing("left"),
    right = capture_swing("right"),
}

-- JSON encoder.
local function jval(v)
    if v == nil then return "null" end
    local t = type(v)
    if t == "number" then return tostring(v) end
    if t == "string" then return '"' .. v .. '"' end
    if t == "boolean" then return v and "true" or "false" end
    if t == "table" then
        local n = 0
        for k, _ in pairs(v) do
            if type(k) == "number" then n = n + 1
            else n = -1; break end
        end
        if n > 0 then
            local parts = {}
            for i = 1, n do parts[i] = jval(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, vv in pairs(v) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. jval(vv))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

do
    local f = assert(io.open(OUT_JSON, "w"))
    f:write(jval(result))
    f:close()
end

client.exit()
