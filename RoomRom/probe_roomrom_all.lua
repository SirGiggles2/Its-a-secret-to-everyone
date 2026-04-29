local out = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_all_dump.json"

local PLANE_A = 0xE000
local ROW_BYTES = 128
local FIRST_ROW = 2
local ROOM_ROWS = 22
local ROOM_COLS = 32

local function frame(pad)
    joypad.set(pad or {}, 1)
    emu.frameadvance()
end

local function tap(button)
    local pad = {}
    pad[button] = true
    pad["P1 " .. button] = true
    for _ = 1, 8 do
        frame(pad)
    end
    for _ = 1, 8 do
        frame({})
    end
end

local function vram_u16(addr)
    return memory.read_u16_be(addr, "VRAM")
end

local function cram_u16(addr)
    return memory.read_u16_be(addr, "CRAM")
end

local function dump_room_words()
    local rows = {}
    for row = 0, ROOM_ROWS - 1 do
        local vals = {}
        local base = PLANE_A + (FIRST_ROW + row) * ROW_BYTES
        for col = 0, ROOM_COLS - 1 do
            vals[#vals + 1] = vram_u16(base + col * 2)
        end
        rows[#rows + 1] = vals
    end
    return rows
end

local function dump_cram()
    local vals = {}
    for i = 0, 63 do
        vals[#vals + 1] = cram_u16(i * 2)
    end
    return vals
end

local function json_array(vals)
    local out_vals = {}
    for i = 1, #vals do
        out_vals[#out_vals + 1] = tostring(vals[i])
    end
    return "[" .. table.concat(out_vals, ",") .. "]"
end

local function json_rows(rows)
    local out_rows = {}
    for i = 1, #rows do
        out_rows[#out_rows + 1] = json_array(rows[i])
    end
    return "[" .. table.concat(out_rows, ",") .. "]"
end

local cur_room = 0x77

local function move_to(target)
    local cur_col = cur_room % 16
    local cur_row = math.floor(cur_room / 16)
    local tgt_col = target % 16
    local tgt_row = math.floor(target / 16)

    while cur_col < tgt_col do
        tap("Right")
        cur_col = cur_col + 1
    end
    while cur_col > tgt_col do
        tap("Left")
        cur_col = cur_col - 1
    end
    while cur_row < tgt_row do
        tap("Down")
        cur_row = cur_row + 1
    end
    while cur_row > tgt_row do
        tap("Up")
        cur_row = cur_row - 1
    end

    cur_room = target
    for _ = 1, 10 do
        frame({})
    end
end

for _ = 1, 120 do
    frame({})
end

local f = assert(io.open(out, "w"))
f:write("{\n")
f:write('  "maps": [\n')
for map_id = 0, 1 do
    if map_id == 1 then
        tap("C")
    end
    f:write("    {\n")
    f:write('      "map_id": ' .. tostring(map_id) .. ',\n')
    f:write('      "rooms": [\n')
    for room = 0, 127 do
        move_to(room)
        f:write("        {")
        f:write('"room_id": ' .. tostring(room) .. ', ')
        f:write('"plane_a": ' .. json_rows(dump_room_words()))
        f:write("}")
        if room ~= 127 then
            f:write(",")
        end
        f:write("\n")
    end
    f:write("      ]\n")
    f:write("    }")
    if map_id ~= 1 then
        f:write(",")
    end
    f:write("\n")
end
f:write("  ],\n")
f:write('  "cram": ' .. json_array(dump_cram()) .. "\n")
f:write("}\n")
f:close()

client.exit()
