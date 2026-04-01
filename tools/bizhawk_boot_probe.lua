local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_boot_probe.txt"

local ram_domains = { "M68K BUS", "68K RAM", "System Bus" }

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function try_read(domain, addr, kind)
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        if kind == "u16" then
            return memory.read_u16_be(addr)
        end
        if kind == "u32" then
            return memory.read_u32_be(addr)
        end
        error("unsupported kind " .. tostring(kind))
    end)
    if ok then
        return value
    end
    return nil
end

local function read_candidates(kind, addresses)
    for _, domain in ipairs(ram_domains) do
        for _, addr in ipairs(addresses) do
            local value = try_read(domain, addr, kind)
            if value ~= nil then
                return value, domain, addr
            end
        end
    end
    error("unable to read " .. kind)
end

local function main()
    local stage_addrs = { 0xFF0040, 0x0040 }
    local detail_addrs = { 0xFF0042, 0x0042 }
    local col_addrs = { 0xFF0044, 0x0044 }
    local row_addrs = { 0xFF0046, 0x0046 }
    local queue_count_addrs = { 0xFF000E, 0x000E }
    local overflow_addrs = { 0xFF0010, 0x0010 }
    local processed_addrs = { 0xFF001C, 0x001C }
    local frame_addrs = { 0xFF0000, 0x0000 }

    for i = 1, 180 do
        emu.frameadvance()
        if i == 1 or i == 2 or i == 5 or i == 10 or i == 30 or i == 60 or i == 120 or i == 180 then
            local stage, stage_domain, stage_addr = read_candidates("u16", stage_addrs)
            local detail = read_candidates("u16", detail_addrs)
            local col = read_candidates("u16", col_addrs)
            local row = read_candidates("u16", row_addrs)
            local queue_count = read_candidates("u16", queue_count_addrs)
            local overflow = read_candidates("u16", overflow_addrs)
            local processed = read_candidates("u32", processed_addrs)
            local frame = read_candidates("u32", frame_addrs)
            local pc = emu.getregister("M68K PC") or 0
            local sr = emu.getregister("M68K SR") or 0
            log(string.format(
                "sample=%03d domain=%s stage_addr=%06X frame=%d stage=%04X detail=%04X col=%d row=%d queue=%d overflow=%d processed=%d pc=%06X sr=%04X",
                i, tostring(stage_domain), stage_addr, frame, stage, detail, col, row, queue_count, overflow, processed, pc, sr
            ))
        end
    end
end

local ok, err = pcall(main)
if not ok then
    log("FAIL: " .. tostring(err))
else
    log("DONE")
end

log_file:close()
client.exit()
