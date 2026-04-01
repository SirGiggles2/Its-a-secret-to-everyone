local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_vdp_probe.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function try_domain(name)
    local ok = pcall(function() memory.usememorydomain(name) end)
    return ok
end

local function dump_words(domain, base, count)
    if not try_domain(domain) then
        log("domain unavailable: " .. domain)
        return
    end
    log(string.format("[%s]", domain))
    for i = 0, count - 1 do
        local addr = base + i * 2
        local value = memory.read_u16_be(addr)
        log(string.format("%04X=%04X", addr, value))
    end
end

local function main()
    for _ = 1, 20 do
        emu.frameadvance()
    end

    local domains = memory.getmemorydomainlist()
    log("domains=" .. table.concat(domains, ", "))

    dump_words("CRAM", 0x0000, 16)
    dump_words("VRAM", 0x8200, 8)
    dump_words("VRAM", 0x0020, 8)
    dump_words("VRAM", 0x1B20, 8)
    dump_words("VRAM", 0x1B60, 8)
end

local ok, err = pcall(main)
if not ok then
    log("FAIL: " .. tostring(err))
end

log_file:close()
client.exit()
