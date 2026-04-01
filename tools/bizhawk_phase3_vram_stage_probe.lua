local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_vram_stage_probe.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function read_u16(domain, addr)
    memory.usememorydomain(domain)
    return memory.read_u16_be(addr)
end

local function frame_with_input(pad)
    joypad.set(pad)
    emu.frameadvance()
end

local function count_nonzero(start_addr, rows, cols, stride)
    local count = 0
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local addr = start_addr + row * stride + col * 2
            if read_u16("VRAM", addr) ~= 0 then
                count = count + 1
            end
        end
    end
    return count
end

local function count_nonzero_domain(domain, start_addr, rows, cols, stride)
    local count = 0
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local addr = start_addr + row * stride + col * 2
            if read_u16(domain, addr) ~= 0 then
                count = count + 1
            end
        end
    end
    return count
end

local fh = assert(io.open(OUT_PATH, "w"))

for _ = 1, 20 do
    frame_with_input({})
end

for _ = 1, 75 do
    frame_with_input({ ["P1 Right"] = true })
end

local plane_a = 0x8000
local row_stride = 128
local top_row = 4
local left_base = plane_a + top_row * row_stride
local right_base = left_base + 32 * 2
local room_buffer = 0xFF0600

fh:write(string.format("room=%04X active=%d dir=%d offset=%d hscroll=%d target=%04X\n",
    read_u16("M68K BUS", 0xFF003C),
    read_u16("M68K BUS", 0xFF004C),
    read_u16("M68K BUS", 0xFF004E),
    read_u16("M68K BUS", 0xFF0050),
    read_u16("M68K BUS", 0xFF0024),
    read_u16("M68K BUS", 0xFF0052)
))
fh:write(string.format("room_buffer_nonzero=%d\n", count_nonzero_domain("M68K BUS", room_buffer, 22, 32, 64)))
fh:write(string.format("left_nonzero=%d\n", count_nonzero(left_base, 22, 32, row_stride)))
fh:write(string.format("right_nonzero=%d\n", count_nonzero(right_base, 22, 32, row_stride)))

for row = 0, 5 do
    fh:write(string.format("row%02d_left=", row))
    for col = 0, 7 do
        fh:write(string.format("%04X", read_u16("VRAM", left_base + row * row_stride + col * 2)))
        if col < 7 then fh:write(",") end
    end
    fh:write("\n")

    fh:write(string.format("row%02d_right=", row))
    for col = 0, 7 do
        fh:write(string.format("%04X", read_u16("VRAM", right_base + row * row_stride + col * 2)))
        if col < 7 then fh:write(",") end
    end
    fh:write("\n")
end

fh:close()
client.exit()
