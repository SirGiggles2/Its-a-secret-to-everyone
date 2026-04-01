local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_navigation_probe.txt"

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

local function read_u32(addr)
    memory.usememorydomain("M68K BUS")
    return memory.read_u32_be(addr)
end

local function frame_with_input(pad)
    joypad.set(pad)
    emu.frameadvance()
end

local function main()
    for _ = 1, 20 do
        frame_with_input({})
    end

    local room_before = read_u16(0xFF003C)
    local x_before = read_u16(0xFF0048)
    local y_before = read_u16(0xFF004A)
    log(string.format("start room=%04X x=%d y=%d", room_before, x_before, y_before))

    local room_after = room_before
    local x_after = x_before
    local y_after = y_before
    local settled_frame = nil

    for frame = 1, 200 do
        frame_with_input({ ["P1 Right"] = true })
        room_after = read_u16(0xFF003C)
        x_after = read_u16(0xFF0048)
        y_after = read_u16(0xFF004A)
        local active = read_u16(0xFF004C)
        if room_after ~= room_before and active == 0 then
            settled_frame = frame
            break
        end
    end

    frame_with_input({})
    local processed = read_u32(0xFF001C)
    log(string.format("end room=%04X x=%d y=%d processed=%d", room_after, x_after, y_after, processed))

    if room_before ~= 0x0077 then
        error(string.format("unexpected start room %04X", room_before))
    end
    if settled_frame == nil then
        error("room never settled after walking right")
    end
    if room_after ~= 0x0078 then
        error(string.format("expected right-adjacent room 0078, got %04X", room_after))
    end
    if x_after > 10 then
        error(string.format("expected landing near left edge, got x=%d", x_after))
    end
    if processed == 0 then
        error("transfer queue never processed")
    end

    log(string.format("transition settled right after %d frames", settled_frame))
    log("WHAT IF Phase 3 navigation probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 navigation probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()
