local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_up_navigation_probe.txt"

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
    local x_before = read_u16(0xFF0048)
    local y_before = read_u16(0xFF004A)
    log(string.format("start room=%04X x=%d y=%d", room_before, x_before, y_before))

    local settled_room = room_before
    local settled_x = x_before
    local settled_y = y_before
    local settled_frame = nil
    local last_room = room_before
    local last_x = x_before
    local last_y = y_before
    local last_active = read_u16(0xFF004C)
    local last_context = read_u16(0xFF0056)
    local last_cave_transition = read_u16(0xFF005E)

    for _ = 1, 80 do
        if read_u16(0xFF003C) ~= room_before then
            break
        end
        if read_u16(0xFF0048) >= 160 then
            break
        end
        frame_with_input({ ["P1 Right"] = true })
    end

    for frame = 1, 140 do
        frame_with_input({ ["P1 Up"] = true })
        local room = read_u16(0xFF003C)
        local x = read_u16(0xFF0048)
        local y = read_u16(0xFF004A)
        local active = read_u16(0xFF004C)
        local context = read_u16(0xFF0056)
        local cave_transition = read_u16(0xFF005E)
        last_room = room
        last_x = x
        last_y = y
        last_active = active
        last_context = context
        last_cave_transition = cave_transition
        if room ~= room_before and active == 0 then
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
        error(string.format(
            "room never settled after walking up (last room=%04X x=%d y=%d active=%d context=%d cave_trans=%d)",
            last_room, last_x, last_y, last_active, last_context, last_cave_transition
        ))
    end
    if settled_room ~= 0x0067 then
        error(string.format("expected up-adjacent room 0067, got %04X", settled_room))
    end
    if settled_y < 180 then
        error(string.format("expected landing near bottom edge, got y=%d", settled_y))
    end

    log(string.format("transition settled up after %d frames", settled_frame))
    log("WHAT IF Phase 3 up navigation probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 up navigation probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()
