-- bizhawk_attr_diag_probe.lua
-- Checks NT_CACHE and attribute path state at frame 300

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_attr_diag_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function bus_read(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Run 300 frames
for i = 1, 300 do emu.frameadvance() end

log("=================================================================")
log("Attribute Diagnostic Probe — frame 300")
log("=================================================================")

-- Check NT_CACHE at $FF0840 (960 bytes = 32 cols x 30 rows)
local NT_CACHE = 0xFF0840
log("")
log("─── NT_CACHE ($FF0840) rows 0-10 ────────────────────────────")
for row = 0, 10 do
    local parts = {}
    for col = 0, 31 do
        local v = bus_read(NT_CACHE + row * 32 + col)
        parts[#parts+1] = string.format("%02X", v)
    end
    log(string.format("  row%02d: %s", row, table.concat(parts, " ")))
end

-- Compare NT_CACHE vs actual Plane A
log("")
log("─── Plane A vs NT_CACHE comparison (rows 0-5) ───────────────")
local NT_BASE = 0xC000
for row = 0, 5 do
    local mismatches = 0
    local details = {}
    for col = 0, 31 do
        local vdp_word = vram_u16(NT_BASE + row * 128 + col * 2)
        local vdp_tile = vdp_word & 0x7FF
        local vdp_pal = (vdp_word >> 13) & 3
        local cache_tile = bus_read(NT_CACHE + row * 32 + col)
        if vdp_tile ~= cache_tile then
            mismatches = mismatches + 1
            if #details < 5 then
                details[#details+1] = string.format("col%d:cache=%02X/vdp=%03X", col, cache_tile, vdp_tile)
            end
        end
    end
    local detail_str = mismatches > 0 and (" " .. table.concat(details, " ")) or ""
    log(string.format("  row%02d: %d mismatches%s", row, mismatches, detail_str))
end

-- Check CurTileBufIdx
local CUR_IDX = bus_read(0xFF0300)
log(string.format("\n  CurTileBufIdx ($FF0300) = $%02X", CUR_IDX))

-- Check what buffer idx was last used
log(string.format("  DynTileBuf sentinel ($FF0302) = $%02X", bus_read(0xFF0302)))
log(string.format("  DynTileBufLen ($FF0301) = $%02X", bus_read(0xFF0301)))

-- Check if any Plane A tiles have non-zero palette
local pal_counts = {[0]=0,[1]=0,[2]=0,[3]=0}
for row = 0, 29 do
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        local pal = (word >> 13) & 3
        pal_counts[pal] = pal_counts[pal] + 1
    end
end
log(string.format("\n  Palette distribution: pal0=%d pal1=%d pal2=%d pal3=%d",
    pal_counts[0], pal_counts[1], pal_counts[2], pal_counts[3]))

-- Write
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("Attr diag written to: " .. REPORT)
client.exit()
