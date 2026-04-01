local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_down_navigation_probe.txt"

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

local function frame_with_input(pad)
    joypad.set(pad)
    emu.frameadvance()
end

local function main()
    for _ = 1, 20 do
        frame_with_input({})
    end

    local room_before = read_u16(0xFF003C)
    log(string.format("start room=%04X x=%d y=%d", room_before, read_u16(0xFF0048), read_u16(0xFF004A)))

    for _ = 1, 80 do
        if read_u16(0xFF003C) ~= room_before then
            break
        end
        if read_u16(0xFF0048) >= 160 then
            break
        end
        frame_with_input({ ["P1 Right"] = true })
    end

    local prep_room = room_before
    for frame = 1, 140 do
        frame_with_input({ ["P1 Up"] = true })
        local room = read_u16(0xFF003C)
        local active = read_u16(0xFF004C)
        if room == 0x0067 and active == 0 then
            prep_room = room
            log(string.format("prep room=%04X after %d frames", room, frame))
            break
        end
    end

    if prep_room ~= 0x0067 then
        error(string.format("failed to reach prep room 0067, got %04X", prep_room))
    end

    local settled_room = prep_room
    local settled_x = read_u16(0xFF0048)
    local settled_y = read_u16(0xFF004A)
    local settled_frame = nil

    for frame = 1, 140 do
        frame_with_input({ ["P1 Down"] = true })
        local room = read_u16(0xFF003C)
        local x = read_u16(0xFF0048)
        local y = read_u16(0xFF004A)
        local active = read_u16(0xFF004C)
        if room ~= prep_room and active == 0 then
            settled_room = room
            settled_x = x
            settled_y = y
            settled_frame = frame
            break
        end
    end

    log(string.format("end room=%04X x=%d y=%d", settled_room, settled_x, settled_y))

    if room_before ~= 0x0077 then
        error(string.format("unexpected start room %04X", room_before))
    end
    if settled_frame == nil then
        error("room never settled after walking down")
    end
    if settled_room ~= 0x0077 then
        error(string.format("expected downward return to room 0077, got %04X", settled_room))
    end
    if settled_y > 48 then
        error(string.format("expected landing at top-edge settle y<=48, got y=%d", settled_y))
    end

    log(string.format("transition settled down after %d frames", settled_frame))
    log("WHAT IF Phase 3 down navigation probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 down navigation probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()
