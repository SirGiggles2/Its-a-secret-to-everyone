-- probe_nes_row3_reference.lua - live NES reference capture for OW row $3X.
--
-- Run against the original NES Zelda ROM, not the Genesis main ROM. The script
-- boots to overworld, forces rooms $30..$3F through the real NES room-load
-- path, dumps playmap/nametable/palette data, screenshots room $37, then exits.

local OUT_JSON = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_row3_reference.json"
local OUT_PNG_37 = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\nes_room37_reference.png"

local ROOM_ID        = 0x00EB
local WHIRL_PREV     = 0x00EA
local WHIRL_STATE    = 0x0522
local CAVE_SOURCE    = 0x0526
local CUR_LEVEL      = 0x0010
local GAME_MODE      = 0x0012
local GAME_SUB       = 0x0013
local IS_UPDATING    = 0x0011
local OBJ_DIR        = 0x0098
local OBJ_X          = 0x0070
local OBJ_Y          = 0x0084
local BUTTONS_PRESS  = 0x00F8
local BUTTONS_HELD   = 0x00FA
local CUR_VSCROLL    = 0x00FC
local CUR_HSCROLL    = 0x00FD
local ROOM_TRANS     = 0x004C
local CUR_SAVE_SLOT  = 0x0016
local NAME_PROGRESS  = 0x0421
local SAVE_ACTIVE0   = 0x0633
local SAVE_ACTIVE1   = 0x0634
local SAVE_ACTIVE2   = 0x0635
local PLAYMAP_BASE   = 0x6530
local CIRAM_BASE     = 0x0100
local ATTR_BASE      = 0x03C0

local ROOM_ROWS = 22
local ROOM_COLS = 32
local PLAY_AREA_NT_TOP = 8

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr & 0xFFFF)
end

local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr & 0xFFFF, val & 0xFF)
end

local function read_domain_u8(domain, addr)
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local function ciram_u8(addr)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local v = read_domain_u8(d, addr)
        if v ~= nil then return v end
    end
    return 0
end

local PAL_DOMAIN, PAL_BASE = nil, 0
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            local lower = name:lower()
            if lower:find("pal") or lower:find("palette") then
                local size_ok, size = pcall(memory.getmemorydomainsize, name)
                if size_ok and size and size <= 64 then
                    PAL_DOMAIN = name
                    PAL_BASE = 0
                    break
                end
            end
        end
    end
end

local function palram_u8(addr)
    if PAL_DOMAIN then
        local v = read_domain_u8(PAL_DOMAIN, PAL_BASE + addr)
        if v ~= nil then return v end
    end
    return 0
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function schedule(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then
        return
    end
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
    local BOOT_TO_FS1 = 1
    local SELECT_REGISTER = 2
    local ENTER_REGISTER = 3
    local TYPE_NAME = 4
    local FINISH_NAME = 5
    local WAIT_GAMEPLAY = 6
    local START_GAME = 7

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
            if mode == 0x0E then
                flow = TYPE_NAME
                last_name = name
            elseif mode == 0x01 then
                schedule("Start", 2, 14)
            end
        elseif flow == TYPE_NAME then
            if name ~= last_name then
                name_events = name_events + 1
                last_name = name
            end
            if name_events >= 5 then flow = FINISH_NAME else schedule("A", 1, 10) end
        elseif flow == FINISH_NAME then
            if mode ~= 0x0E then
                flow = WAIT_GAMEPLAY
            elseif slot ~= 0x03 then
                schedule("Select", 1, 10)
            else
                schedule("Start", 2, 14)
            end
        elseif flow == WAIT_GAMEPLAY then
            if mode == 0x01 then flow = START_GAME end
        elseif flow == START_GAME then
            if mode ~= 0x01 then
                flow = WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if active0 == 0 and active1 ~= 0 then
                    target_slot = 0x01
                elseif active0 == 0 and active1 == 0 and active2 ~= 0 then
                    target_slot = 0x02
                end
                if slot ~= target_slot then
                    schedule(target_slot > slot and "Down" or "Up", 1, 10)
                else
                    schedule("Start", 2, 14)
                end
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

local function warp_to_room(room)
    local trace = {
        ptr_02_03 = -1,
        ptr_04_05 = -1,
        layout_bytes = {},
        column_bytes = {},
    }
    -- Mode 3 Sub1 uses CaveSourceRoomId as the OW start room when it is
    -- not $FF. This exercises the real unfurl/load-room path for any OW
    -- room without walking there.
    w8(CAVE_SOURCE, room)
    w8(WHIRL_PREV, 0xFF)
    w8(WHIRL_STATE, 0)
    w8(OBJ_DIR, 0x04)
    w8(OBJ_X, 0x78)
    w8(OBJ_Y, 0x8D)
    w8(CUR_VSCROLL, 0)
    w8(CUR_HSCROLL, 0)
    w8(BUTTONS_PRESS, 0)
    w8(BUTTONS_HELD, 0)
    w8(IS_UPDATING, 0)
    w8(GAME_MODE, 0x03)
    w8(GAME_SUB, 0)

    local prev_mode = u8(GAME_MODE)
    local prev_sub = u8(GAME_SUB)
    for _ = 1, 720 do
        safe_set({})
        emu.frameadvance()
        local mode = u8(GAME_MODE)
        local sub = u8(GAME_SUB)
        if prev_mode == 0x03 and prev_sub == 0x08 and not (mode == 0x03 and sub == 0x08) then
            trace.ptr_02_03 = u8(0x0002) | (u8(0x0003) << 8)
            trace.ptr_04_05 = u8(0x0004) | (u8(0x0005) << 8)
            for i = 0, 15 do trace.layout_bytes[#trace.layout_bytes + 1] = u8(trace.ptr_02_03 + i) end
            for i = 0, 15 do trace.column_bytes[#trace.column_bytes + 1] = u8(trace.ptr_04_05 + i) end
        end
        prev_mode = mode
        prev_sub = sub
        if mode == 0x05 and sub == 0 and u8(ROOM_TRANS) == 0 then
            for _ = 1, 12 do safe_set({}); emu.frameadvance() end
            return u8(ROOM_ID) == room, trace
        end
    end
    return false, trace
end

local function dump_playmap_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        for col = 0, ROOM_COLS - 1 do
            vals[#vals + 1] = u8(PLAYMAP_BASE + row + col * ROOM_ROWS)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

local function dump_visible_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        local base = CIRAM_BASE + row * ROOM_COLS
        for col = 0, ROOM_COLS - 1 do
            vals[#vals + 1] = ciram_u8(base + col)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

local function attr_palette_for(col, nt_row)
    local byte = ciram_u8(ATTR_BASE + (nt_row >> 2) * 8 + (col >> 2))
    local qx = (col >> 1) & 1
    local qy = (nt_row >> 1) & 1
    return (byte >> ((qy * 2 + qx) * 2)) & 3
end

local function dump_palette_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        for col = 0, ROOM_COLS - 1 do
            vals[#vals + 1] = attr_palette_for(col, PLAY_AREA_NT_TOP + row)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

local function dump_palette_ram()
    local vals = {}
    for i = 0, 31 do vals[#vals + 1] = palram_u8(i) end
    return vals
end

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

local system_id = emu.getsystemid() or "?"
local rooms = {}
local ok_boot = false
local err = nil

if system_id ~= "NES" then
    err = "wrong_system_" .. system_id
else
    ok_boot = boot_to_overworld()
    if not ok_boot then
        err = "failed_to_boot_to_overworld"
    else
        local targets = {}
        for room = 0x30, 0x3F do targets[#targets + 1] = room end
        targets[#targets + 1] = 0x76
        targets[#targets + 1] = 0x77
        for _, room in ipairs(targets) do
            local ok, trace = warp_to_room(room)
            rooms[#rooms + 1] = {
                room_id = room,
                warp_ok = ok,
                actual_room_id = u8(ROOM_ID),
                ptr_02_03 = trace.ptr_02_03,
                ptr_04_05 = trace.ptr_04_05,
                layout_bytes = trace.layout_bytes,
                column_bytes = trace.column_bytes,
                attr_a = u8(0x687E + room),
                attr_b = u8(0x68FE + room),
                attr_c = u8(0x697E + room),
                attr_d = u8(0x69FE + room),
                attr_e = u8(0x6A7E + room),
                attr_f = u8(0x6AFE + room),
                playmap_rows = dump_playmap_rows(),
                visible_rows = dump_visible_rows(),
                palette_rows = dump_palette_rows(),
                palette_ram = dump_palette_ram(),
            }
            if room == 0x37 then
                client.screenshot(OUT_PNG_37)
            end
        end
    end
end

local f = assert(io.open(OUT_JSON, "w"))
f:write("{\n")
f:write('  "system_id": "', system_id, '",\n')
f:write('  "boot_ok": ', tostring(ok_boot), ',\n')
if err then f:write('  "error": "', err, '",\n') end
f:write('  "rooms": [\n')
for i = 1, #rooms do
    local r = rooms[i]
    f:write("    {\n")
    f:write('      "room_id": ', tostring(r.room_id), ',\n')
    f:write('      "actual_room_id": ', tostring(r.actual_room_id), ',\n')
    f:write('      "warp_ok": ', tostring(r.warp_ok), ',\n')
    f:write('      "ptr_02_03": ', tostring(r.ptr_02_03), ',\n')
    f:write('      "ptr_04_05": ', tostring(r.ptr_04_05), ',\n')
    f:write('      "layout_bytes": ', j1(r.layout_bytes), ',\n')
    f:write('      "column_bytes": ', j1(r.column_bytes), ',\n')
    f:write('      "attr_a": ', tostring(r.attr_a), ',\n')
    f:write('      "attr_b": ', tostring(r.attr_b), ',\n')
    f:write('      "attr_c": ', tostring(r.attr_c), ',\n')
    f:write('      "attr_d": ', tostring(r.attr_d), ',\n')
    f:write('      "attr_e": ', tostring(r.attr_e), ',\n')
    f:write('      "attr_f": ', tostring(r.attr_f), ',\n')
    f:write('      "playmap_rows": ', j2(r.playmap_rows), ',\n')
    f:write('      "visible_rows": ', j2(r.visible_rows), ',\n')
    f:write('      "palette_rows": ', j2(r.palette_rows), ',\n')
    f:write('      "palette_ram": ', j1(r.palette_ram), '\n')
    f:write("    }")
    if i < #rooms then f:write(",") end
    f:write("\n")
end
f:write("  ]\n")
f:write("}\n")
f:close()

client.exit()
