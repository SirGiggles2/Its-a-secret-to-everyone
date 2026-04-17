dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    if not tools_dir then
        error("unable to resolve tools directory from '" .. source .. "'")
    end
    return tools_dir .. "\\probe_root.lua"
end)())

local OUT_DIR = repo_path("builds\\reports")
local OUT_PATH = repo_path("builds\\reports\\ow_visible_sweep_nes.json")

local ROOM_ID = 0x00EB
local ROOM_TRANSITION_ACTIVE = 0x004C
local LINK_X = 0x0048
local LINK_Y = 0x004A
local CIRAM_BASE = 0x0100
local ROOM_ROWS = 22
local ROOM_COLS = 32

local LINK_MIN_X = 0x00
local LINK_MAX_X = 0xF0
local LINK_MIN_Y = 0x30
local LINK_MAX_Y = 0xD0
local MODE = 0x0012
local CUR_SAVE_SLOT = 0x0016
local NAME_PROGRESS = 0x0421
local SAVE_ACTIVE0 = 0x0633
local SAVE_ACTIVE1 = 0x0634
local SAVE_ACTIVE2 = 0x0635

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function read_u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr % 0x10000)
end

local function ciram_u8(addr)
    local domains = {"CIRAM (nametables)", "CIRAM", "Nametable RAM"}
    for i = 1, #domains do
        local ok, v = pcall(function()
            memory.usememorydomain(domains[i])
            return memory.read_u8(addr)
        end)
        if ok then
            return v
        end
    end
    return 0
end

local function frame(pad)
    joypad.set(pad or {})
    emu.frameadvance()
end

local function safe_set(pad)
    local ok = pcall(function()
        joypad.set(pad or {}, 1)
    end)
    if not ok then
        joypad.set(pad or {})
    end
end

local function schedule_input(state, button, hold_frames, release_frames)
    if state.hold_left > 0 or state.release_left > 0 then
        return false
    end
    state.button = button
    state.hold_left = hold_frames or 1
    state.release_left = 0
    state.release_after = release_frames or 8
    return true
end

local function build_pad_for_frame(state)
    local pad = {}
    if state.hold_left > 0 and state.button then
        if state.button:sub(1, 3) == "P1 " then
            pad[state.button] = true
            pad[state.button:sub(4)] = true
        else
            pad[state.button] = true
            pad["P1 " .. state.button] = true
        end
        state.hold_left = state.hold_left - 1
        if state.hold_left == 0 then
            state.release_left = state.release_after
        end
    elseif state.release_left > 0 then
        state.release_left = state.release_left - 1
    end
    return pad
end

local function wait_until_settled(max_frames)
    for _ = 1, max_frames do
        frame({})
        if read_u8(ROOM_TRANSITION_ACTIVE) == 0 then
            return true
        end
    end
    return false
end

local function trigger_step(direction)
    local pad = {}
    if direction == "right" then
        pad["Right"] = true
        pad["P1 Right"] = true
    elseif direction == "left" then
        pad["Left"] = true
        pad["P1 Left"] = true
    elseif direction == "up" then
        pad["Up"] = true
        pad["P1 Up"] = true
    elseif direction == "down" then
        pad["Down"] = true
        pad["P1 Down"] = true
    else
        error("bad direction: " .. tostring(direction))
    end
    local start_room = read_u8(ROOM_ID)
    for _ = 1, 240 do
        frame(pad)
        if read_u8(ROOM_ID) ~= start_room then
            return wait_until_settled(240)
        end
    end
    return false
end

local function step_toward(target)
    local cur = read_u8(ROOM_ID)
    if cur == target then
        return true
    end
    local cur_row = math.floor(cur / 16)
    local cur_col = cur % 16
    local tgt_row = math.floor(target / 16)
    local tgt_col = target % 16

    return trigger_step(
        tgt_col > cur_col and "right"
        or tgt_col < cur_col and "left"
        or tgt_row < cur_row and "up"
        or "down"
    )
end

local function build_serpentine_path()
    local path = {}
    for row = 7, 0, -1 do
        local forward = ((7 - row) % 2) == 0
        if forward then
            for col = 0, 15 do
                path[#path + 1] = row * 16 + col
            end
        else
            for col = 15, 0, -1 do
                path[#path + 1] = row * 16 + col
            end
        end
    end
    return path
end

local function boot_to_overworld()
    local FLOW_BOOT_TO_FS1 = 1
    local FLOW_FS1_SELECT_REGISTER = 2
    local FLOW_FS1_ENTER_REGISTER = 3
    local FLOW_MODEE_TYPE_NAME = 4
    local FLOW_MODEE_FINISH = 5
    local FLOW_WAIT_GAMEPLAY = 6
    local FLOW_FS1_START_GAME = 7

    local flow = FLOW_BOOT_TO_FS1
    local input_state = {button = nil, hold_left = 0, release_left = 0, release_after = 0}
    local last_name_offset = read_u8(NAME_PROGRESS)
    local name_progress_events = 0

    for _ = 1, 6500 do
        local mode = read_u8(MODE)
        local cur_slot = read_u8(CUR_SAVE_SLOT)
        local name_ofs = read_u8(NAME_PROGRESS)
        local slot_active0 = read_u8(SAVE_ACTIVE0)
        local slot_active1 = read_u8(SAVE_ACTIVE1)
        local slot_active2 = read_u8(SAVE_ACTIVE2)

        if flow == FLOW_BOOT_TO_FS1 then
            if mode == 0x01 then
                flow = FLOW_FS1_SELECT_REGISTER
            else
                schedule_input(input_state, "Start", 2, 3)
            end
        elseif flow == FLOW_FS1_SELECT_REGISTER then
            if cur_slot == 0x03 then
                flow = FLOW_FS1_ENTER_REGISTER
            else
                schedule_input(input_state, "Down", 1, 10)
            end
        elseif flow == FLOW_FS1_ENTER_REGISTER then
            if mode == 0x0E then
                flow = FLOW_MODEE_TYPE_NAME
                last_name_offset = name_ofs
            elseif mode == 0x01 then
                schedule_input(input_state, "Start", 2, 14)
            end
        elseif flow == FLOW_MODEE_TYPE_NAME then
            if name_ofs ~= last_name_offset then
                name_progress_events = name_progress_events + 1
                last_name_offset = name_ofs
            end
            if name_progress_events >= 5 then
                flow = FLOW_MODEE_FINISH
            else
                schedule_input(input_state, "A", 1, 10)
            end
        elseif flow == FLOW_MODEE_FINISH then
            if mode ~= 0x0E then
                flow = FLOW_WAIT_GAMEPLAY
            elseif cur_slot ~= 0x03 then
                schedule_input(input_state, "C", 1, 10)
            else
                schedule_input(input_state, "Start", 2, 14)
            end
        elseif flow == FLOW_WAIT_GAMEPLAY then
            if mode == 0x01 then
                flow = FLOW_FS1_START_GAME
            end
        elseif flow == FLOW_FS1_START_GAME then
            if mode ~= 0x01 then
                flow = FLOW_WAIT_GAMEPLAY
            else
                local target_slot = 0x00
                if slot_active0 == 0 and slot_active1 ~= 0 then
                    target_slot = 0x01
                elseif slot_active0 == 0 and slot_active1 == 0 and slot_active2 ~= 0 then
                    target_slot = 0x02
                end
                if cur_slot ~= target_slot then
                    local move_btn = "Up"
                    if target_slot > cur_slot then
                        move_btn = "Down"
                    end
                    schedule_input(input_state, move_btn, 1, 10)
                else
                    schedule_input(input_state, "Start", 2, 14)
                end
            end
        end

        local pad = build_pad_for_frame(input_state)
        safe_set(pad)
        emu.frameadvance()

        if read_u8(MODE) == 0x05 and read_u8(ROOM_ID) == 0x77 and read_u8(ROOM_TRANSITION_ACTIVE) == 0 then
            return true
        end
    end

    return false
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

-- NES nametable attribute table lives at PPU $23C0-$23FF for NT0 =
-- CIRAM $03C0-$03FF. Each byte covers a 4x4 tile area (= 2x2 16x16
-- metatiles). Bit layout: BR(7:6) BL(5:4) TR(3:2) TL(1:0). Pick the
-- 2-bit palette index that matches the (tile_col, tile_row) coordinate
-- within the 32x32-tile NT0.
local ATTR_BASE = 0x03C0
local function attr_palette_for(nt_tile_col, nt_tile_row)
    local attr_col = nt_tile_col >> 2   -- 0..7
    local attr_row = nt_tile_row >> 2   -- 0..7
    local byte = ciram_u8(ATTR_BASE + attr_row * 8 + attr_col)
    local qx = (nt_tile_col >> 1) & 1
    local qy = (nt_tile_row >> 1) & 1
    local shift = (qy * 2 + qx) * 2
    return (byte >> shift) & 3
end

-- Play area starts at NT row 4 (rows 0..3 are HUD). But the sweep reads
-- tiles at CIRAM_BASE + row*32 which already maps to NT row 4+ because
-- CIRAM_BASE = $0100 = NT0 offset $100 = row 8 * 32. Wait — actually
-- CIRAM $0100 corresponds to PPU $2100 which is tile row 8 (row 8 * 32
-- bytes = $100). The play area starts at row 8. So for row r in the
-- 22-row play area, NT tile row = 8 + r. That's what we need for attr
-- lookup.
local PLAY_AREA_NT_TOP = 8

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

-- PPU palette RAM at $3F00-$3F0F (BG palettes 0..3, 4 colors each).
-- In BizHawk NES, PPU memory is in the "PPU Bus" or "PPU Memory" domain.
-- Fall back across common names.
local function ppu_bus_u8(addr)
    local domains = {"PPU Bus", "PPU Memory", "PPU", "System Bus"}
    for i = 1, #domains do
        local ok, v = pcall(function()
            memory.usememorydomain(domains[i])
            return memory.read_u8(addr)
        end)
        if ok then
            memory.usememorydomain("System Bus")
            return v
        end
    end
    memory.usememorydomain("System Bus")
    return 0
end

local function dump_palette_ram()
    local vals = {}
    for i = 0, 15 do
        vals[#vals + 1] = ppu_bus_u8(0x3F00 + i)
    end
    return vals
end

local function json_escape(s)
    return tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function json_array_1d(values)
    local parts = {}
    for i = 1, #values do
        parts[#parts + 1] = tostring(values[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function json_array_2d(rows)
    local parts = {}
    for i = 1, #rows do
        parts[#parts + 1] = json_array_1d(rows[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function main()
    if not boot_to_overworld() then
        error("failed to reach overworld gameplay before OW NES sweep")
    end
    if not wait_until_settled(180) then
        error("scene never settled before OW NES sweep")
    end

    local visited = {}
    local path = build_serpentine_path()
    for _, target in ipairs(path) do
        local guard = 0
        while read_u8(ROOM_ID) ~= target do
            guard = guard + 1
            if guard > 64 then
                error(string.format("could not reach target room %02X from %02X", target, read_u8(ROOM_ID)))
            end
            if not step_toward(target) then
                error(string.format("step failed while moving to room %02X", target))
            end
        end
        if not wait_until_settled(120) then
            error(string.format("room %02X failed to settle", target))
        end
        if not visited[target] then
            visited[target] = {
                room_id = target,
                visible_rows = dump_visible_rows(),
                palette_rows = dump_palette_rows(),
                palette_ram = dump_palette_ram(),
            }
        end
    end

    local keys = {}
    for k, _ in pairs(visited) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    local fh = assert(io.open(OUT_PATH, "w"))
    fh:write("{\n")
    fh:write('  "room_count": ', tostring(#keys), ',\n')
    fh:write('  "rooms": [\n')
    for i = 1, #keys do
        local room = visited[keys[i]]
        fh:write("    {\n")
        fh:write('      "room_id": ', tostring(room.room_id), ',\n')
        fh:write('      "visible_rows": ', json_array_2d(room.visible_rows), ',\n')
        fh:write('      "palette_rows": ', json_array_2d(room.palette_rows), ',\n')
        fh:write('      "palette_ram": ', json_array_1d(room.palette_ram), '\n')
        fh:write("    }")
        if i < #keys then
            fh:write(",")
        end
        fh:write("\n")
    end
    fh:write("  ]\n")
    fh:write("}\n")
    fh:close()
end

local ok, err = pcall(main)
if not ok then
    local fh = io.open(OUT_PATH, "w")
    if fh then
        fh:write('{"error":"', json_escape(err), '"}\n')
        fh:close()
    end
end

client.exit()
