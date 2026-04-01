local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_transition_probe.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function read_u16(addr)
    memory.usememorydomain("M68K BUS")
    return memory.read_u16_be(addr)
end

local function frame_with_input(pad)
    joypad.set(pad)
    emu.frameadvance()
end

local fh = assert(io.open(OUT_PATH, "w"))

local function log_frame(tag, frame)
    fh:write(string.format(
        "%s frame=%03d room=%04X x=%03d active=%d dir=%d offset=%03d hscroll=%d target=%04X\n",
        tag,
        frame,
        read_u16(0xFF003C),
        read_u16(0xFF0048),
        read_u16(0xFF004C),
        read_u16(0xFF004E),
        read_u16(0xFF0050),
        read_u16(0xFF0024),
        read_u16(0xFF0052)
    ))
    fh:flush()
end

for i = 1, 20 do
    frame_with_input({})
    log_frame("idle", i)
end

for i = 1, 100 do
    frame_with_input({ ["P1 Right"] = true })
    log_frame("walk", i)
end

fh:close()
client.exit()
