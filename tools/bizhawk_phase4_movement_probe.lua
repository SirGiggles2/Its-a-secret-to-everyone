local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase4_movement_probe.txt"

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

    local x0 = read_u16(0xFF0048)
    local y0 = read_u16(0xFF004A)
    log(string.format("start x=%d y=%d", x0, y0))

    for _ = 1, 40 do
        frame_with_input({ ["P1 Right"] = true })
    end

    frame_with_input({})

    local x1 = read_u16(0xFF0048)
    local y1 = read_u16(0xFF004A)
    local dx = x1 - x0
    local dy = y1 - y0

    log(string.format("end x=%d y=%d dx=%d dy=%d", x1, y1, dx, dy))

    if dy ~= 0 then
        error(string.format("expected no vertical drift while holding right, got dy=%d", dy))
    end

    if dx ~= 60 then
        error(string.format("expected exact NES displacement 60px over 40f (1.5 px/frame), got %d", dx))
    end

    log("WHAT IF Phase 4 movement probe: PASS")
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 4 movement probe: FAIL - " .. tostring(err))
end

log_file:close()
client.exit()
