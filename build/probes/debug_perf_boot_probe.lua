local OUT_PATH = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes\\debug_perf_boot.json"

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

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

local A4_BASE = RAM_BASE + 0x7000
local RAM_A4_BASE = RAM_BASE + 0x8000

local function rd(addr)
    return memory.read_u8(RAM_BASE + addr, RAM_DOMAIN)
end

local function rd_a4(offset)
    return memory.read_u8(A4_BASE + offset, RAM_DOMAIN)
end

local function rd_nes(offset)
    return memory.read_u8(RAM_A4_BASE + offset, RAM_DOMAIN)
end

local function rd16_abs(addr)
    return rd(addr) * 0x100 + rd(addr + 1)
end

local function rd16_a4(offset)
    return rd_a4(offset) * 0x100 + rd_a4(offset + 1)
end

local function read_a4_frame()
    return rd16_a4(2)
end

local function pad(buttons)
    local p = {}
    for _, b in ipairs(buttons or {}) do
        p[b] = true
        p["P1 " .. b] = true
    end
    return p
end

local function advance(frames, buttons)
    local p = pad(buttons)
    for _ = 1, frames do
        joypad.set(p, 1)
        emu.frameadvance()
    end
end

local report = {
    probe = "debug_perf_boot",
    status = "ERROR",
    detail = "not completed",
    domain = RAM_DOMAIN,
}

local function array_json(values)
    local parts = {}
    for i, v in ipairs(values) do
        parts[i] = tostring(v)
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function write_report()
    mkdir_for(OUT_PATH)
    local f = assert(io.open(OUT_PATH, "w"))
    f:write("{\n")
    f:write('  "probe": "' .. report.probe .. '",\n')
    f:write('  "status": "' .. report.status .. '",\n')
    f:write('  "detail": "' .. tostring(report.detail):gsub("\\", "\\\\"):gsub('"', '\\"') .. '",\n')
    f:write('  "domain": "' .. report.domain .. '",\n')
    f:write('  "a4_state": ' .. tostring(report.a4_state or -1) .. ',\n')
    f:write('  "a4_scene": ' .. tostring(report.a4_scene or -1) .. ',\n')
    f:write('  "room_id": ' .. tostring(report.room_id or -1) .. ',\n')
    f:write('  "title_phase": ' .. tostring(report.title_phase or -1) .. ',\n')
    f:write('  "state_mirror_magic": "' .. tostring(report.state_mirror_magic or "") .. '",\n')
    f:write('  "control": ' .. array_json(report.control or {}) .. ',\n')
    f:write('  "legacy_control": ' .. array_json(report.legacy_control or {}) .. ',\n')
    f:write('  "stress_probe_bytes": ' .. array_json(report.stress_probe_bytes or {}) .. ',\n')
    f:write('  "obj_types_1_to_11": ' .. array_json(report.obj_types or {}) .. ',\n')
    f:write('  "stress_signature": ' .. tostring(report.stress_signature and "true" or "false") .. ',\n')
    f:write('  "sample_emu_frames": ' .. tostring(report.sample_emu_frames or 0) .. ',\n')
    f:write('  "sample_game_frames": ' .. tostring(report.sample_game_frames or 0) .. ',\n')
    f:write('  "early_emu_frames": ' .. tostring(report.early_emu_frames or 0) .. ',\n')
    f:write('  "early_game_frames": ' .. tostring(report.early_game_frames or 0) .. ',\n')
    f:write('  "settled_emu_frames": ' .. tostring(report.settled_emu_frames or 0) .. ',\n')
    f:write('  "settled_game_frames": ' .. tostring(report.settled_game_frames or 0) .. ',\n')
    f:write('  "frame_counter_start": ' .. tostring(report.frame_counter_start or 0) .. ',\n')
    f:write('  "frame_counter_end": ' .. tostring(report.frame_counter_end or 0) .. '\n')
    f:write("}\n")
    f:close()
end

local function fail(detail)
    report.status = "FAIL"
    report.detail = detail
    write_report()
end

local function main()
    local saw_magic = false
    for _ = 1, 180 do
        emu.frameadvance()
        if rd_a4(0) == 0xA4 and rd_a4(1) == 0x4A then
            saw_magic = true
            break
        end
    end
    if not saw_magic then
        fail("A4 probe magic never appeared")
        return
    end

    for _ = 1, 120 do
        if rd_nes(0x07F0) == 1 then break end
        emu.frameadvance()
    end
    report.title_phase = rd_nes(0x07F0)
    if report.title_phase ~= 1 then
        fail("title did not reach display phase before debug chord")
        return
    end

    advance(30, {"A", "B", "C"})
    advance(1, {})

    local entered = false
    for _ = 1, 240 do
        emu.frameadvance()
        if rd16_a4(4) ~= 0 then
            fail("A4 fail_stage became non-zero after chord")
            return
        end
        if rd_a4(13) == 1 then
            entered = true
            break
        end
    end
    if not entered then
        fail("A+B+C did not enter RoomRom runtime")
        return
    end

    advance(240, {})

    report.a4_state = rd_a4(13)
    report.a4_scene = rd_a4(14)
    report.room_id = rd_a4(15)
    report.state_mirror_magic = string.char(rd(0x7200)) .. string.char(rd(0x7201))
    report.control = { rd(0x73F8), rd(0x73F9), rd(0x73FA) }
    report.legacy_control = { rd(0x73FC), rd(0x73FD) }
    report.stress_probe_bytes = {
        rd(0x7E00), rd(0x7E01), rd(0x7E02), rd(0x7E03),
        rd(0x7E04), rd(0x7E05), rd(0x7E06), rd(0x7E07)
    }

    local expected_stress = {0x07,0x03,0x05,0x2A,0x0B,0x13,0x15,0x1A,0x1B,0x28,0x12}
    local obj_types = {}
    local signature = true
    for slot = 1, 11 do
        local t = rd_nes(0x034F + slot)
        obj_types[slot] = t
        if t ~= expected_stress[slot] then
            signature = false
        end
    end
    report.obj_types = obj_types
    report.stress_signature = signature

    if report.a4_state ~= 1 then
        fail("entered runtime but did not stay in runtime state")
        return
    end
    if report.a4_scene ~= 1 or report.room_id ~= 0x73 then
        fail("debug runtime did not settle in UW room 0x73")
        return
    end
    if report.state_mirror_magic ~= "WP" then
        fail("minimum debug state mirror did not publish WP magic")
        return
    end
    if report.control[1] == 0x52 and report.control[2] == 0x50 and report.control[3] ~= 0 then
        fail("explicit debug probe control was armed during default A+B+C")
        return
    end
    if report.legacy_control[1] == 0x45 and report.legacy_control[2] == 0x50 then
        fail("legacy enemy stress arm was set during default A+B+C")
        return
    end
    if report.stress_signature then
        fail("enemy stress force-spawn signature appeared in default debug mode")
        return
    end
    if report.stress_probe_bytes[8] == 0x05 then
        fail("enemy_loop_probe_run wrote its stress check block")
        return
    end

    local start_fc = read_a4_frame()
    for _ = 1, 600 do
        emu.frameadvance()
    end
    local end_fc = read_a4_frame()
    local game_frames = end_fc - start_fc
    if game_frames < 0 then game_frames = game_frames + 65536 end

    report.sample_emu_frames = 600
    report.sample_game_frames = game_frames
    report.early_emu_frames = 600
    report.early_game_frames = game_frames
    report.frame_counter_start = start_fc
    report.frame_counter_end = end_fc

    advance(600, {})

    start_fc = read_a4_frame()
    for _ = 1, 600 do
        emu.frameadvance()
    end
    end_fc = read_a4_frame()
    game_frames = end_fc - start_fc
    if game_frames < 0 then game_frames = game_frames + 65536 end
    report.settled_emu_frames = 600
    report.settled_game_frames = game_frames

    if game_frames < 590 then
        fail("settled debug gameplay advanced fewer than 590 game frames in 600 emulator frames")
        return
    end

    report.status = "PASS"
    report.detail = "A+B+C entered default debug gameplay; stress probe remained opt-in; settled gameplay held 60Hz"
    write_report()
end

local ok, err = pcall(main)
if not ok then
    report.status = "ERROR"
    report.detail = tostring(err)
    write_report()
end

client.exit()
