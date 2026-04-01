local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_room_dump.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function read_u16(addr)
    memory.usememorydomain("M68K BUS")
    return memory.read_u16_be(addr)
end

local function main()
    for _ = 1, 20 do
        emu.frameadvance()
    end

    local base = 0xFF0600
    for row = 0, 21 do
        local parts = {}
        for col = 0, 15 do
            local addr = base + row * 64 + col * 2
            parts[#parts + 1] = string.format("%04X", read_u16(addr))
        end
        log(string.format("row%02d %s", row, table.concat(parts, " ")))
    end
end

local ok, err = pcall(main)
if not ok then
    log("FAIL: " .. tostring(err))
end

log_file:close()
client.exit()
