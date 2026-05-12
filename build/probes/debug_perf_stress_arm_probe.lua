local OUT_PATH = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\probes\\debug_perf_stress_arm.json"

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"') end
end

local function domain_exists(name)
    for _, domain in ipairs(memory.getmemorydomainlist()) do
        if domain == name then return true end
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
local NES_BASE = RAM_BASE + 0x8000

local function rd(addr) return memory.read_u8(RAM_BASE + addr, RAM_DOMAIN) end
local function wr(addr, val) memory.write_u8(RAM_BASE + addr, val, RAM_DOMAIN) end
local function rd_a4(off) return memory.read_u8(A4_BASE + off, RAM_DOMAIN) end
local function rd_nes(off) return memory.read_u8(NES_BASE + off, RAM_DOMAIN) end

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
    probe = "debug_perf_stress_arm",
    status = "ERROR",
    detail = "not completed",
    domain = RAM_DOMAIN,
}

local function array_json(values)
    local parts = {}
    for i, v in ipairs(values) do parts[i] = tostring(v) end
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
    f:write('  "control": ' .. array_json(report.control or {}) .. ',\n')
    f:write('  "stress_probe_bytes": ' .. array_json(report.stress_probe_bytes or {}) .. ',\n')
    f:write('  "obj_types_1_to_11": ' .. array_json(report.obj_types or {}) .. ',\n')
    f:write('  "stress_signature": ' .. tostring(report.stress_signature and "true" or "false") .. '\n')
    f:write("}\n")
    f:close()
end

local function fail(detail)
    report.status = "FAIL"
    report.detail = detail
    write_report()
end

local function main()
    for _ = 1, 180 do
        emu.frameadvance()
        if rd_a4(0) == 0xA4 and rd_a4(1) == 0x4A then break end
    end

    wr(0x73F8, 0x52) -- 'R'
    wr(0x73F9, 0x50) -- 'P'
    wr(0x73FA, 0x03) -- heavy mirror + enemy stress

    advance(120, {})
    advance(30, {"A", "B", "C"})
    advance(300, {})

    report.a4_state = rd_a4(13)
    report.a4_scene = rd_a4(14)
    report.room_id = rd_a4(15)
    report.control = { rd(0x73F8), rd(0x73F9), rd(0x73FA) }
    report.stress_probe_bytes = {
        rd(0x7E00), rd(0x7E01), rd(0x7E02), rd(0x7E03),
        rd(0x7E04), rd(0x7E05), rd(0x7E06), rd(0x7E07)
    }

    local expected = {0x07,0x03,0x05,0x2A,0x0B,0x13,0x15,0x1A,0x1B,0x28,0x12}
    local obj_types = {}
    local signature = true
    for slot = 1, 11 do
        local t = rd_nes(0x034F + slot)
        obj_types[slot] = t
        if slot == 1 then
            if t ~= expected[slot] and t ~= 0x60 then signature = false end
        elseif t ~= expected[slot] then
            signature = false
        end
    end
    report.obj_types = obj_types
    report.stress_signature = signature

    if report.a4_state ~= 1 or report.a4_scene ~= 1 or report.room_id ~= 0x73 then
        fail("explicit arm did not enter UW debug room 0x73")
        return
    end
    if report.control[1] ~= 0x52 or report.control[2] ~= 0x50 or report.control[3] ~= 0x03 then
        fail("RP stress control bytes were not preserved")
        return
    end
    if not report.stress_signature then
        fail("enemy stress force-spawn signature did not appear when explicitly armed")
        return
    end
    if report.stress_probe_bytes[1] ~= 0x45 or report.stress_probe_bytes[2] ~= 0x4C then
        fail("enemy_loop_probe_run did not publish EL probe magic")
        return
    end

    report.status = "PASS"
    report.detail = "explicit RP heavy+enemy-stress arm still runs the stress harness"
    write_report()
end

local ok, err = pcall(main)
if not ok then
    report.status = "ERROR"
    report.detail = tostring(err)
    write_report()
end

client.exit()
