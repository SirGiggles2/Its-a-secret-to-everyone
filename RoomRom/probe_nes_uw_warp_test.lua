-- probe_nes_uw_warp_test.lua
-- Boot NES Zelda to overworld, try to warp into Level 1 Room 0 via memory pokes.
-- Screenshot result to see whether warp succeeded.

local OUT_PNG  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_uw_warp_test.png"
local OUT_JSON = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_uw_warp_test.json"

local ROOM_ID        = 0x00EB
local CUR_LEVEL      = 0x0010
local GAME_MODE      = 0x0012
local GAME_SUB       = 0x0013
local CUR_SAVE_SLOT  = 0x0016
local NAME_PROGRESS  = 0x0421
local SAVE_ACTIVE0   = 0x0633
local SAVE_ACTIVE1   = 0x0634
local SAVE_ACTIVE2   = 0x0635
local ROOM_TRANS     = 0x004C
local CAVE_SOURCE    = 0x0526
local IS_UPDATING    = 0x0011

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

local function ciram_u8(addr)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local ok, v = pcall(function()
            memory.usememorydomain(d)
            return memory.read_u8(addr)
        end)
        if ok then return v end
    end
    return 0
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
           and u8(ROOM_ID) == 0x77 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 30 do safe_set({}); emu.frameadvance() end
            return true
        end
    end
    return false
end

local function dump_nt_play_area()
    local rows = {}
    for r = 0, 21 do
        local row = {}
        for c = 0, 31 do
            row[#row + 1] = ciram_u8((r + 8) * 32 + c)
        end
        rows[#rows + 1] = row
    end
    return rows
end

local function dump_nt_full()
    local rows = {}
    for r = 0, 29 do
        local row = {}
        for c = 0, 31 do
            row[#row + 1] = ciram_u8(r * 32 + c)
        end
        rows[#rows + 1] = row
    end
    return rows
end

local results = {}

local function record(label)
    results[#results + 1] = {
        label = label,
        cur_level = u8(CUR_LEVEL),
        room_id   = u8(ROOM_ID),
        game_mode = u8(GAME_MODE),
        game_sub  = u8(GAME_SUB),
        room_trans = u8(ROOM_TRANS),
        nt = dump_nt_full(),
    }
end

local system_id = emu.getsystemid() or "?"
local ok_boot = false

if system_id == "NES" then
    ok_boot = boot_to_overworld()
end

if ok_boot then
    record("baseline_overworld_77")

    -- Attempt 1: just poke CurLevel + RoomId, set GameMode 5 sub 0
    w8(CUR_LEVEL, 1)
    w8(ROOM_ID, 0x73)  -- Level 1 entry room (NES standard: room $73)
    w8(GAME_MODE, 0x05)
    w8(GAME_SUB, 0)
    w8(ROOM_TRANS, 0)
    w8(IS_UPDATING, 0)
    for _ = 1, 60 do safe_set({}); emu.frameadvance() end
    record("attempt1_lvl1_room73_pokes_only")
    client.screenshot(OUT_PNG)

    -- Attempt 2: trigger a "load room" via GameMode 4 (load level), Sub 0
    w8(CUR_LEVEL, 1)
    w8(ROOM_ID, 0x73)
    w8(GAME_MODE, 0x04)
    w8(GAME_SUB, 0)
    for _ = 1, 120 do safe_set({}); emu.frameadvance() end
    record("attempt2_lvl1_room73_mode4")
end

local f = assert(io.open(OUT_JSON, "w"))
local function j1(t)
    local s = {}
    for i = 1, #t do s[#s + 1] = tostring(t[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end
local function j2(rows)
    local s = {}
    for i = 1, #rows do s[#s + 1] = j1(rows[i]) end
    return "[" .. table.concat(s, ",") .. "]"
end

f:write("{\n")
f:write('  "system_id": "', system_id, '",\n')
f:write('  "boot_ok": ', tostring(ok_boot), ',\n')
f:write('  "results": [\n')
for i, r in ipairs(results) do
    f:write("    {\n")
    f:write('      "label": "', r.label, '",\n')
    f:write('      "cur_level": ', tostring(r.cur_level), ',\n')
    f:write('      "room_id": ', tostring(r.room_id), ',\n')
    f:write('      "game_mode": ', tostring(r.game_mode), ',\n')
    f:write('      "game_sub": ', tostring(r.game_sub), ',\n')
    f:write('      "room_trans": ', tostring(r.room_trans), ',\n')
    f:write('      "nt": ', j2(r.nt), '\n')
    f:write("    }")
    if i < #results then f:write(",") end
    f:write("\n")
end
f:write("  ]\n}\n")
f:close()

client.exit()
