local DEFAULT_OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\reports\\debug\\debug_entry.json"
local OUT_PATH = os.getenv("DEBUG_ENTRY_REPORT") or DEFAULT_OUT

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

local DOMAIN = "M68K BUS"
local BASE = 0x00FF7000
local RAM_BASE = 0x00FF8000
if domain_exists("68K RAM") then
    DOMAIN = "68K RAM"
    BASE = 0x7000
    RAM_BASE = 0x8000
elseif domain_exists("M68K RAM") then
    DOMAIN = "M68K RAM"
    BASE = 0x7000
    RAM_BASE = 0x8000
end

local function read_domain_u8(addr)
    memory.usememorydomain(DOMAIN)
    return memory.read_u8(addr)
end

local function read_u8(offset)
    return read_domain_u8(BASE + offset)
end

local function read_ram_u8(offset)
    return read_domain_u8(RAM_BASE + offset)
end

local function read_u16(offset)
    return (read_u8(offset) * 0x100) + read_u8(offset + 1)
end

local function read_u32(offset)
    return (read_u8(offset) * 0x1000000)
        + (read_u8(offset + 1) * 0x10000)
        + (read_u8(offset + 2) * 0x100)
        + read_u8(offset + 3)
end

local function write_report(status, detail)
    mkdir_for(OUT_PATH)
    local f = assert(io.open(OUT_PATH, "w"))
    f:write("{\n")
    f:write('  "probe": "debug_entry",\n')
    f:write('  "status": "' .. status .. '",\n')
    f:write('  "detail": "' .. tostring(detail or ""):gsub("\\", "\\\\"):gsub('"', '\\"') .. '",\n')
    f:write('  "domain": "' .. DOMAIN .. '",\n')
    f:write('  "frame": ' .. tostring(read_u16(2)) .. ",\n")
    f:write('  "fail_stage": ' .. tostring(read_u16(4)) .. ",\n")
    f:write('  "last_a4": "' .. string.format("0x%08X", read_u32(6)) .. '",\n')
    f:write('  "state": ' .. tostring(read_u8(13)) .. ",\n")
    f:write('  "title_phase": ' .. tostring(read_ram_u8(0x07F0)) .. ",\n")
    f:write('  "roomrom_scene": ' .. tostring(read_u8(14)) .. ",\n")
    f:write('  "room_id": ' .. tostring(read_u8(15)) .. ",\n")
    f:write('  "link_x": ' .. tostring(read_u16(16)) .. ",\n")
    f:write('  "link_y": ' .. tostring(read_u16(18)) .. "\n")
    f:write("}\n")
    f:close()
end

local function wait_for_magic()
    for _ = 1, 120 do
        emu.frameadvance()
        if read_u8(0) == 0xA4 and read_u8(1) == 0x4A then
            return true
        end
    end
    return false
end

local function main()
    if not wait_for_magic() then
        write_report("FAIL", "probe magic never appeared")
        return
    end

    -- Wait for the real native title path to reach PHASE_TITLE_DISPLAY.
    for _ = 1, 60 do
        emu.frameadvance()
        if read_ram_u8(0x07F0) == 1 then -- PHASE_TITLE_DISPLAY
            break
        end
    end

    if read_ram_u8(0x07F0) ~= 1 then
        write_report("FAIL", "PHASE_TITLE_DISPLAY was not reached before chord")
        return
    end

    for _ = 1, 8 do
        joypad.set({ ["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true })
        emu.frameadvance()
    end
    joypad.set({})

    local entered = false
    for _ = 1, 180 do
        emu.frameadvance()
        if read_u16(4) ~= 0 then
            write_report("FAIL", "A4 probe failed after chord")
            return
        end
        if read_u8(13) == 1 then
            entered = true
            break
        end
    end

    if not entered then
        write_report("FAIL", "A+B+C did not enter RoomRom runtime")
        return
    end

    for _ = 1, 240 do
        emu.frameadvance()
        if read_u16(4) ~= 0 then
            write_report("FAIL", "A4 probe failed inside RoomRom runtime")
            return
        end
        if read_u8(13) ~= 1 then
            write_report("FAIL", "left RoomRom runtime after entry")
            return
        end
    end

    if read_u8(14) ~= 1 then
        write_report("FAIL", "RoomRom did not enter UW scene")
        return
    end
    if read_u8(15) ~= 0x73 then
        write_report("FAIL", "RoomRom did not enter UW debug room 0x73")
        return
    end

    write_report("PASS", "entered RoomRom runtime and survived CHR upload")
end

local ok, err = pcall(main)
if not ok then
    write_report("ERROR", tostring(err))
end

client.exit()
