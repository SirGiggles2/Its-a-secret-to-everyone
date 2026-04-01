local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_room_probe.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function use_domain(name)
    memory.usememorydomain(name)
end

local function read_u16(domain, addr)
    use_domain(domain)
    return memory.read_u16_be(addr)
end

local function read_u32(domain, addr)
    use_domain(domain)
    return memory.read_u32_be(addr)
end

local function main()
    for _ = 1, 20 do
        emu.frameadvance()
    end

    local plane_a_base = 0x8000
    local row_stride = 128
    local top_row = 4
    local room_base = 0xFF0600

    local function count_nonzero_words(domain, start_addr, bytes_per_row, rows, cols)
        local nonzero = 0
        for row = 0, rows - 1 do
            for col = 0, cols - 1 do
                local addr = start_addr + row * bytes_per_row + col * 2
                if read_u16(domain, addr) ~= 0 then
                    nonzero = nonzero + 1
                end
            end
        end
        return nonzero
    end

    local room_nonzero = count_nonzero_words("M68K BUS", room_base, 64, 22, 32)
    local vram_nonzero = count_nonzero_words("VRAM", plane_a_base + top_row * row_stride, row_stride, 22, 32)
    log(string.format("room buffer nonzero words=%d", room_nonzero))
    log(string.format("plane A visible room nonzero words=%d", vram_nonzero))

    local samples = {
        plane_a_base + top_row * row_stride + 30,
        plane_a_base + top_row * row_stride + 32,
        plane_a_base + top_row * row_stride + 34,
        plane_a_base + (top_row + 8) * row_stride + 40,
        plane_a_base + (top_row + 15) * row_stride + 52,
    }
    for _, addr in ipairs(samples) do
        local value = read_u16("VRAM", addr)
        log(string.format("VRAM[%04X]=%04X", addr, value))
    end

    local room_id = read_u16("M68K BUS", 0xFF003C)
    local stage = read_u16("M68K BUS", 0xFF0040)
    local detail = read_u16("M68K BUS", 0xFF0042)
    local frame = read_u32("M68K BUS", 0xFF0000)
    local processed = read_u32("M68K BUS", 0xFF001C)
    log(string.format("room=%04X stage=%04X detail=%04X frame=%d processed=%d", room_id, stage, detail, frame, processed))

    if room_id ~= 0x0077 then
        error(string.format("unexpected room id %04X", room_id))
    end
    if frame == 0 or processed == 0 then
        error("main loop or transfer queue did not advance")
    end
    if room_nonzero == 0 then
        error("room tilemap buffer in RAM is blank")
    end
    if vram_nonzero == 0 then
        error("plane A room region in VRAM is blank")
    end

    log("WHAT IF Phase 3 room probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 room probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()
