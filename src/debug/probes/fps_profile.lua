-- FPS profiler: reads the RoomRom debug frame mirror and reports whether
-- game ticks keep pace with emulator frames after the A+B+C title chord.

local OUTPUT_DIR = os.getenv("CODEX_PROBE_OUT") or "."
local STAGE1_FRAMES = 60
local CHORD_FRAMES = 30
local STAGE2_FRAMES = 60
local SAMPLE_FRAMES = 600
local BYPASS_MASK = tonumber(os.getenv("ROOMROM_BYPASS_MASK") or "0") or 0

local function domain_exists(name)
    for _, domain in ipairs(memory.getmemorydomainlist()) do
        if domain == name then
            return true
        end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local RAM_BASE = 0x00FF0000
if domain_exists("68K RAM") then
    RAM_DOMAIN = "68K RAM"
    RAM_BASE = 0
elseif domain_exists("M68K RAM") then
    RAM_DOMAIN = "M68K RAM"
    RAM_BASE = 0
end

local function press(buttons, frames)
    for _ = 1, frames do
        joypad.set(buttons, 1)
        emu.frameadvance()
    end
end

local function read_ram_u8(offset)
    return memory.read_u8(RAM_BASE + offset, RAM_DOMAIN)
end

local function write_ram_u8(offset, value)
    memory.write_u8(RAM_BASE + offset, value, RAM_DOMAIN)
end

local function read_frame_counter()
    local hi = read_ram_u8(0x7202)
    local lo = read_ram_u8(0x7203)
    return hi * 256 + lo
end

local function read_marker()
    return read_ram_u8(0x7200), read_ram_u8(0x7201)
end

local function write_error(err)
    local f = io.open(OUTPUT_DIR .. "/fps_profile.txt", "w")
    if f then
        f:write("FPS Profile\n===========\n\n")
        f:write("ERROR: " .. tostring(err) .. "\n")
        f:write("RAM domain: " .. RAM_DOMAIN .. "\n")
        f:close()
    end
end

local function main()
    press({}, STAGE1_FRAMES)
    press({A=true, B=true, C=true}, CHORD_FRAMES)
    write_ram_u8(0x73FD, BYPASS_MASK)
    press({}, STAGE2_FRAMES)

    local mhi, mlo = read_marker()
    local start_gfc = read_frame_counter()
    local emu_total = 0

    for _ = 1, SAMPLE_FRAMES do
        emu.frameadvance()
        emu_total = emu_total + 1
    end

    local end_gfc = read_frame_counter()
    local game_total = end_gfc - start_gfc
    if game_total < 0 then game_total = game_total + 65536 end

    local avg_ratio = 0.0
    if game_total > 0 then
        avg_ratio = emu_total / game_total
    end
    local effective_fps = (avg_ratio > 0) and (60.0 / avg_ratio) or 0.0

    local sat = {}
    for s = 0, 2 do
        local base = 0xF800 + s * 8
        sat[s] = string.format("%02X %02X %02X %02X %02X %02X %02X %02X",
            memory.read_u8(base,   "VRAM"),
            memory.read_u8(base+1, "VRAM"),
            memory.read_u8(base+2, "VRAM"),
            memory.read_u8(base+3, "VRAM"),
            memory.read_u8(base+4, "VRAM"),
            memory.read_u8(base+5, "VRAM"),
            memory.read_u8(base+6, "VRAM"),
            memory.read_u8(base+7, "VRAM"))
    end

    client.screenshot(OUTPUT_DIR .. "/fps_profile.png")

    local f = io.open(OUTPUT_DIR .. "/fps_profile.txt", "w")
    f:write("FPS Profile\n")
    f:write("===========\n\n")
    f:write(string.format("Sample window: %d emu frames\n", SAMPLE_FRAMES))
    f:write(string.format("Game frames advanced: %d\n", game_total))
    f:write(string.format("Emu frames advanced:  %d\n", emu_total))
    f:write(string.format("Avg emu/game ratio: %.3f\n", avg_ratio))
    f:write(string.format("Effective game fps: %.2f (target 60.00)\n", effective_fps))
    f:write(string.format("Start frame_counter: %d  End: %d  Marker: %02X %02X\n",
        start_gfc, end_gfc, mhi, mlo))
    f:write(string.format("RAM domain: %s\n", RAM_DOMAIN))
    f:write(string.format("Bypass mask: 0x%02X\n", BYPASS_MASK))
    f:write("\nSAT slots 0..2:\n")
    for s = 0, 2 do
        f:write(string.format("  slot %d: %s\n", s, sat[s]))
    end
    if avg_ratio > 1.5 then
        f:write("\nVERDICT: LAG - game running at half speed or worse.\n")
    elseif avg_ratio > 1.1 then
        f:write("\nVERDICT: minor lag - occasional frame drops.\n")
    else
        f:write("\nVERDICT: CLEAN 60fps.\n")
    end
    f:close()

    print(string.format("FPS profile: emu=%d game=%d ratio=%.3f fps=%.2f",
        emu_total, game_total, avg_ratio, effective_fps))
end

local ok, err = pcall(main)
if not ok then
    write_error(err)
end
client.exit()
