-- bizhawk_vram_timeline_probe.lua
-- Checks VRAM $2000+ at multiple timepoints to diagnose CHR upload

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_vram_timeline_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function vram_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function bus_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

log("=== VRAM Timeline Probe ===")
log("")

-- Check VRAM at multiple addresses and frames
local check_addrs = {
    {0x0000, "tile $000 (CHR $0000 start)"},
    {0x0480, "tile $024 (CHR $0000 bank)"},
    {0x2000, "tile $100 (CHR $1000 start)"},
    {0x2480, "tile $124 (CHR $1000 bank)"},
    {0x2020, "tile $101 (2nd tile of $1000)"},
}

local check_frames = {5, 10, 15, 20, 25, 30, 35, 40, 50, 100, 200, 300}

local frame = 0
for _, target_frame in ipairs(check_frames) do
    while frame < target_frame do
        emu.frameadvance()
        frame = frame + 1
    end

    local f5 = bus_u8(0xFF00F5)
    log(string.format("--- Frame %d (TransferredCommonPatterns=$%02X) ---", frame, f5))

    for _, check in ipairs(check_addrs) do
        local addr = check[1]
        local desc = check[2]
        local bytes = {}
        local nonzero = 0
        for i = 0, 31 do
            local b = vram_u8(addr + i)
            bytes[#bytes+1] = string.format("%02X", b)
            if b ~= 0 then nonzero = nonzero + 1 end
        end
        log(string.format("  VRAM[$%04X] %s: %s [%d nonzero]",
            addr, desc, table.concat(bytes, " "), nonzero))
    end
    log("")
end

-- Full VRAM scan: how many non-zero bytes in each 4K block?
log("--- VRAM non-zero byte counts per 4K block at frame 300 ---")
for block = 0, 15 do
    local base = block * 0x1000
    local nonzero = 0
    for i = 0, 0xFFF do
        if vram_u8(base + i) ~= 0 then
            nonzero = nonzero + 1
        end
    end
    log(string.format("  $%04X-$%04X: %d non-zero bytes", base, base + 0xFFF, nonzero))
end

-- Write report
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("VRAM timeline probe written to: " .. REPORT)
client.exit()
