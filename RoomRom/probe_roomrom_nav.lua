local out = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\\out\\roomrom_nav_dump.json"

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

for _ = 1, 120 do
    frame({})
end

local samples = {
    { label = "initial" },
    { label = "left", button = "Left" },
    { label = "right", button = "Right" },
    { label = "up", button = "Up" },
    { label = "down", button = "Down" },
}

local f = assert(io.open(out, "w"))
f:write("{\n")
f:write('  "samples": [\n')
for i = 1, #samples do
    local sample = samples[i]
    if sample.button then
        tap(sample.button)
    end
    f:write("    {")
    f:write('"label": "' .. sample.label .. '", ')
    f:write('"plane_a": ' .. json_rows(dump_room_words()))
    f:write("}")
    if i ~= #samples then
        f:write(",")
    end
    f:write("\n")
end
f:write("  ]\n")
f:write("}\n")
f:close()

client.exit()
