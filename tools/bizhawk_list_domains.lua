local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_domains.txt"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

for _, domain in ipairs(memory.getmemorydomainlist()) do
    log(domain)
end

for _, domain in ipairs({ "PPU Bus", "VRAM", "OAM", "M68K BUS", "System Bus" }) do
    local ok = pcall(function()
        memory.usememorydomain(domain)
        log(string.format("[%s] %02X %02X %02X %02X",
            domain,
            memory.read_u8(0x0000),
            memory.read_u8(0x0001),
            memory.read_u8(0x0002),
            memory.read_u8(0x0003)))
    end)
    if not ok then
        log("unavailable: " .. domain)
    end
end

log_file:close()
client.exit()
