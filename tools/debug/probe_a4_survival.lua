local DEFAULT_OUT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\build\\reports\\debug\\a4_survival.json"
local OUT_PATH = os.getenv("DEBUG_A4_REPORT") or DEFAULT_OUT

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
if domain_exists("68K RAM") then
    DOMAIN = "68K RAM"
    BASE = 0x7000
elseif domain_exists("M68K RAM") then
    DOMAIN = "M68K RAM"
    BASE = 0x7000
end

local function read_u8(offset)
    memory.usememorydomain(DOMAIN)
    return memory.read_u8(BASE + offset)
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

local function json_escape(value)
    return tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function write_report(result)
    mkdir_for(OUT_PATH)
    local f = assert(io.open(OUT_PATH, "w"))
    f:write("{\n")
    f:write('  "probe": "a4_survival",\n')
    f:write('  "status": "' .. json_escape(result.status) .. '",\n')
    f:write('  "domain": "' .. json_escape(DOMAIN) .. '",\n')
    f:write('  "frame": ' .. tostring(result.frame or 0) .. ",\n")
    f:write('  "fail_stage": ' .. tostring(result.fail_stage or 0) .. ",\n")
    f:write('  "last_a4": "' .. string.format("0x%08X", result.last_a4 or 0) .. '",\n')
    f:write('  "ram_0012": ' .. tostring(result.ram_0012 or 0) .. ",\n")
    f:write('  "ram_0013": ' .. tostring(result.ram_0013 or 0) .. "\n")
    f:write("}\n")
    f:close()
end

local function snapshot(status)
    return {
        status = status,
        frame = read_u16(2),
        fail_stage = read_u16(4),
        last_a4 = read_u32(6),
        ram_0012 = read_u8(10),
        ram_0013 = read_u8(11),
    }
end

local function main()
    for _ = 1, 300 do
        emu.frameadvance()

        local magic0 = read_u8(0)
        local magic1 = read_u8(1)
        if magic0 == 0xA4 and magic1 == 0x4A then
            local fail_stage = read_u16(4)
            local done = read_u8(12)
            if fail_stage ~= 0 or done == 0xEE then
                write_report(snapshot("FAIL"))
                return
            end
            if done == 1 then
                write_report(snapshot("PASS"))
                return
            end
        end
    end

    write_report(snapshot("TIMEOUT"))
end

local ok, err = pcall(main)
if not ok then
    write_report({ status = "ERROR: " .. tostring(err) })
end

client.exit()
