-- bizhawk_vram_diag_probe.lua
-- Deep diagnostic: dump VRAM tile data, nametable entries, and CHR upload stats
-- Run at frame 300 after title screen should be fully loaded

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_vram_diag_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function vram_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
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

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Run 300 frames
for i = 1, 300 do emu.frameadvance() end

log("=================================================================")
log("VRAM Diagnostic Probe — frame 300")
log("=================================================================")

-- 1. Scan all tile slots in VRAM: tiles 0-511 (first 16KB)
--    Each Genesis tile = 32 bytes (8 rows x 4 bytes)
log("")
log("─── CHR Tile Occupancy (VRAM $0000-$3FFF) ───────────────────")
local occupied_tiles = {}
local total_occupied = 0
for tile = 0, 511 do
    local base = tile * 32
    local nonzero = 0
    for b = 0, 31 do
        if vram_u8(base + b) ~= 0 then nonzero = nonzero + 1 end
    end
    if nonzero > 0 then
        occupied_tiles[#occupied_tiles+1] = tile
        total_occupied = total_occupied + 1
    end
end
log(string.format("  Total occupied tiles: %d / 512", total_occupied))
if total_occupied > 0 then
    -- Show ranges
    local ranges = {}
    local rstart = occupied_tiles[1]
    local rlast = rstart
    for i = 2, #occupied_tiles do
        if occupied_tiles[i] == rlast + 1 then
            rlast = occupied_tiles[i]
        else
            ranges[#ranges+1] = string.format("$%03X-$%03X (%d)", rstart, rlast, rlast-rstart+1)
            rstart = occupied_tiles[i]
            rlast = rstart
        end
    end
    ranges[#ranges+1] = string.format("$%03X-$%03X (%d)", rstart, rlast, rlast-rstart+1)
    log("  Occupied ranges: " .. table.concat(ranges, ", "))
end

-- 2. Dump first few occupied tiles (hex)
log("")
log("─── Sample Tile Data ─────────────────────────────────────────")
local sample_count = 0
for _, tile in ipairs(occupied_tiles) do
    if sample_count >= 8 then break end
    local base = tile * 32
    local hex = {}
    for b = 0, 31 do
        hex[#hex+1] = string.format("%02X", vram_u8(base + b))
    end
    log(string.format("  Tile $%03X (VRAM $%04X): %s", tile, base, table.concat(hex, " ")))
    sample_count = sample_count + 1
end

-- 3. Nametable (Plane A at $C000, 64x32 words, but only 32x28 visible)
log("")
log("─── Plane A Nametable ($C000) ───────────────────────────────")
local NT_BASE = 0xC000
local tile_hist = {}
local pal_hist = {[0]=0,[1]=0,[2]=0,[3]=0}
local total_nonzero = 0
local total_zero = 0

for row = 0, 27 do
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        local tile = word & 0x7FF
        local pal = (word >> 13) & 3
        local hflip = (word >> 11) & 1
        local vflip = (word >> 12) & 1
        if word ~= 0 then
            total_nonzero = total_nonzero + 1
            pal_hist[pal] = pal_hist[pal] + 1
            tile_hist[tile] = (tile_hist[tile] or 0) + 1
        else
            total_zero = total_zero + 1
        end
    end
end

log(string.format("  Non-zero entries: %d  Zero entries: %d", total_nonzero, total_zero))
log(string.format("  Palette usage: pal0=%d pal1=%d pal2=%d pal3=%d",
    pal_hist[0], pal_hist[1], pal_hist[2], pal_hist[3]))

-- Count distinct tiles
local distinct = 0
for _ in pairs(tile_hist) do distinct = distinct + 1 end
log(string.format("  Distinct tile indices: %d", distinct))

-- Top 10 most used tiles
local sorted_tiles = {}
for t, c in pairs(tile_hist) do sorted_tiles[#sorted_tiles+1] = {tile=t, count=c} end
table.sort(sorted_tiles, function(a,b) return a.count > b.count end)
log("  Most used tiles:")
for i = 1, math.min(10, #sorted_tiles) do
    local e = sorted_tiles[i]
    -- Check if tile has data in VRAM
    local base = e.tile * 32
    local has_data = false
    for b = 0, 31 do
        if vram_u8(base + b) ~= 0 then has_data = true; break end
    end
    log(string.format("    tile $%03X: %d entries  VRAM_data=%s", e.tile, e.count, tostring(has_data)))
end

-- 4. Dump nametable rows 0-5 (title area)
log("")
log("─── Nametable rows 0-7 (raw words) ──────────────────────────")
for row = 0, 7 do
    local parts = {}
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        parts[#parts+1] = string.format("%04X", word)
    end
    log(string.format("  row%02d: %s", row, table.concat(parts, " ")))
end

-- Rows 8-15
log("")
log("─── Nametable rows 8-15 ──────────────────────────────────────")
for row = 8, 15 do
    local parts = {}
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        parts[#parts+1] = string.format("%04X", word)
    end
    log(string.format("  row%02d: %s", row, table.concat(parts, " ")))
end

-- Rows 16-23
log("")
log("─── Nametable rows 16-23 ─────────────────────────────────────")
for row = 16, 23 do
    local parts = {}
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        parts[#parts+1] = string.format("%04X", word)
    end
    log(string.format("  row%02d: %s", row, table.concat(parts, " ")))
end

-- Rows 24-27
log("")
log("─── Nametable rows 24-27 ─────────────────────────────────────")
for row = 24, 27 do
    local parts = {}
    for col = 0, 31 do
        local word = vram_u16(NT_BASE + row * 128 + col * 2)
        parts[#parts+1] = string.format("%04X", word)
    end
    log(string.format("  row%02d: %s", row, table.concat(parts, " ")))
end

-- 5. CRAM dump
log("")
log("─── CRAM (all 4 palettes) ────────────────────────────────────")
for pal = 0, 3 do
    local parts = {}
    for col = 0, 15 do
        local word = cram_u16(pal * 32 + col * 2)
        parts[#parts+1] = string.format("%04X", word)
    end
    log(string.format("  pal%d: %s", pal, table.concat(parts, " ")))
end

-- Write report
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("VRAM diag probe written to: " .. REPORT)
client.exit()
