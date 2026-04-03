-- bizhawk_nt_diag_probe.lua
-- Diagnose nametable tile index offset issue
-- Checks PPU_CTRL value and dumps full Plane A tile indices

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_nt_diag_probe.txt"

local lines = {}
local function log(s) lines[#lines+1] = s end

local function bus_u8(addr)
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

log("=== NT Diagnostic Probe ===")

-- Track PPU_CTRL ($FF0804) over time
local ppu_ctrl_log = {}
local prev_ctrl = -1
for frame = 1, 300 do
    emu.frameadvance()
    local ctrl = bus_u8(0xFF0804)
    if ctrl ~= prev_ctrl then
        log(string.format("  f%03d: PPU_CTRL = $%02X (bit4=%d)", frame, ctrl, (ctrl >> 4) & 1))
        prev_ctrl = ctrl
    end
end

log("")
log("--- PPU_CTRL at frame 300 ---")
local ctrl = bus_u8(0xFF0804)
log(string.format("  PPU_CTRL ($FF0804) = $%02X", ctrl))
local ctrl_ff = bus_u8(0xFF00FF)
log(string.format("  CurPpuControl ($FF00FF) = $%02X", ctrl_ff))

-- Dump full Plane A nametable (32 cols x 30 rows)
log("")
log("--- Plane A tile indices (32x30) ---")
local tile_counts = {}
local offset_count = 0
local no_offset_count = 0

for row = 0, 29 do
    local row_str = string.format("  r%02d:", row)
    for col = 0, 31 do
        local addr = 0xC000 + row * 0x80 + col * 2
        local word = vram_u16(addr)
        local tile = word & 0x07FF
        local pal = (word >> 13) & 3
        row_str = row_str .. string.format(" %03X", tile)

        tile_counts[tile] = (tile_counts[tile] or 0) + 1
        if tile >= 0x100 then
            offset_count = offset_count + 1
        else
            no_offset_count = no_offset_count + 1
        end
    end
    log(row_str)
end

log("")
log(string.format("  Tiles with index >= $100 (offset applied): %d", offset_count))
log(string.format("  Tiles with index < $100 (no offset): %d", no_offset_count))

-- Show most common tile indices
log("")
log("--- Most common tile indices ---")
local sorted = {}
for tile, count in pairs(tile_counts) do
    sorted[#sorted+1] = {tile=tile, count=count}
end
table.sort(sorted, function(a,b) return a.count > b.count end)
for i = 1, math.min(20, #sorted) do
    local e = sorted[i]
    log(string.format("  tile $%03X: %d entries", e.tile, e.count))
end

-- Check VRAM at tile $024 vs $124 to see which has actual data
log("")
log("--- VRAM tile data comparison ---")
log("  Tile $024 (VRAM $0480):")
local s = "   "
for i = 0, 31 do
    s = s .. string.format(" %02X", vram_u16(0x0480 + i) & 0xFF)
    -- actually read bytes
end
-- Read tile data as bytes
memory.usememorydomain("VRAM")
s = "   "
for i = 0, 31 do
    local ok, v = pcall(function() return memory.read_u8(0x0480 + i) end)
    s = s .. string.format(" %02X", ok and v or 0)
end
log(s)

log("  Tile $124 (VRAM $2480):")
s = "   "
for i = 0, 31 do
    local ok, v = pcall(function() return memory.read_u8(0x2480 + i) end)
    s = s .. string.format(" %02X", ok and v or 0)
end
log(s)

-- Write report
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("NT diagnostic probe written to: " .. REPORT)
client.exit()
