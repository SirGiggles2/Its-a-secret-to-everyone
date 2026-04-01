local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_overworld_full_probe.json"

local ROOM_ID = 0xFF003C
local ROOM_TRANSITION_ACTIVE = 0xFF004C
local LINK_X = 0xFF0048
local LINK_Y = 0xFF004A

local ROOM_BASE = 0xFF0600
local ROOM_ROWS = 22
local ROOM_COLS = 32
local ROOM_ROW_STRIDE = 64

local LINK_MIN_X = 0x0000
local LINK_MAX_X = 0x00F0
local LINK_MIN_Y = 0x0030
local LINK_MAX_Y = 0x00D0

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function read_u16(addr)
    memory.usememorydomain("M68K BUS")
    return memory.read_u16_be(addr)
end

local function write_u16(addr, value)
    memory.usememorydomain("M68K BUS")
    memory.write_u16_be(addr, value & 0xFFFF)
end

local function frame(pad)
    joypad.set(pad or {})
    emu.frameadvance()
end

local function wait_until_settled(max_frames)
    for _ = 1, max_frames do
        frame({})
        if read_u16(ROOM_TRANSITION_ACTIVE) == 0 then
            return true
        end
    end
    return false
end

local function wait_for_room(target_room, max_frames)
    for _ = 1, max_frames do
        frame({})
        if read_u16(ROOM_ID) == target_room and read_u16(ROOM_TRANSITION_ACTIVE) == 0 then
            return true
        end
    end
    return false
end

local function trigger_step(direction)
    if direction == "right" then
        write_u16(LINK_X, LINK_MAX_X + 1)
    elseif direction == "left" then
        write_u16(LINK_X, 0xFFFF)
    elseif direction == "up" then
        write_u16(LINK_Y, LINK_MIN_Y - 1)
    elseif direction == "down" then
        write_u16(LINK_Y, LINK_MAX_Y + 1)
    else
        error("bad direction: " .. tostring(direction))
    end

    frame({})
end

local function dump_room_rows()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local values = {}
        for col = 0, ROOM_COLS - 1 do
            local addr = ROOM_BASE + row * ROOM_ROW_STRIDE + col * 2
            values[#values + 1] = read_u16(addr)
        end
        rows[#rows + 1] = values
    end
    return rows
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

local function step_toward(target)
    local cur = read_u16(ROOM_ID)
    if cur == target then
        return true
    end

    local cur_row = (cur >> 4) & 0xF
    local cur_col = cur & 0xF
    local tgt_row = (target >> 4) & 0xF
    local tgt_col = target & 0xF

    if tgt_col > cur_col then
        trigger_step("right")
    elseif tgt_col < cur_col then
        trigger_step("left")
    elseif tgt_row < cur_row then
        trigger_step("up")
    elseif tgt_row > cur_row then
        trigger_step("down")
    end

    if not wait_until_settled(160) then
        return false
    end

    local next_room = read_u16(ROOM_ID)
    return next_room ~= cur
end

local function json_escape(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"')
end

local function to_json_array_1d(values)
    local parts = {}
    for i = 1, #values do
        parts[#parts + 1] = tostring(values[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function to_json_array_2d(rows)
    local lines = {}
    for i = 1, #rows do
        lines[#lines + 1] = "    " .. to_json_array_1d(rows[i])
    end
    return "[\n" .. table.concat(lines, ",\n") .. "\n  ]"
end

local function write_payload(visited)
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
        local k = keys[i]
        local room = visited[k]
        fh:write("    {\n")
        fh:write('      "room_id": ', tostring(room.room_id), ',\n')
        fh:write('      "room_rows": ', to_json_array_2d(room.room_rows), "\n")
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

local function main()
    for _ = 1, 30 do
        frame({})
    end

    if not wait_until_settled(120) then
        error("scene never settled before full probe")
    end

    local visited = {}
    local path = build_serpentine_path()

    for _, target in ipairs(path) do
        local guard = 0
        while read_u16(ROOM_ID) ~= target do
            guard = guard + 1
            if guard > 64 then
                error(string.format("could not reach target room %02X from %02X", target, read_u16(ROOM_ID)))
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
                room_rows = dump_room_rows(),
            }
        end
    end

    write_payload(visited)
end

local ok, err = pcall(main)
if not ok then
    local fh = io.open(OUT_PATH, "w")
    if fh then
        fh:write('{"error":"', json_escape(tostring(err)), '"}\n')
        fh:close()
    end
end

client.exit()
