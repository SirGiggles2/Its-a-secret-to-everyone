-- bizhawk_tile_data_probe.lua
-- Dump raw VRAM tile data for specific tiles and compare against expected NES CHR

local ROOT = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_tile_data_probe.txt"

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

for i = 1, 300 do emu.frameadvance() end

log("=== Tile Data Probe (frame 300) ===")
log("")

-- Pick some tiles that should have visible content
-- The Zelda logo starts around tile $171-$1C0 (row 7-15 of nametable)
-- Tile $1E4 and $1E5 are the decorative border chain pattern (row 5)
local check_tiles = {0x1E4, 0x1E5, 0x171, 0x172, 0x1DC, 0x1D7, 0x101, 0x109}

for _, tile in ipairs(check_tiles) do
    local vram_addr = tile * 32  -- Genesis: 32 bytes per 4BPP tile
    log(string.format("--- Genesis tile $%03X (VRAM $%04X) ---", tile, vram_addr))

    -- Dump 32 bytes (8 rows × 4 bytes)
    for row = 0, 7 do
        local bytes = {}
        local pixels = {}
        for col = 0, 3 do
            local b = vram_u8(vram_addr + row * 4 + col)
            bytes[#bytes+1] = string.format("%02X", b)
            -- Decode 2 pixels per byte (high nibble = left pixel, low nibble = right pixel)
            pixels[#pixels+1] = string.format("%X%X", (b >> 4) & 0xF, b & 0xF)
        end
        log(string.format("  row%d: %s  pixels: %s", row, table.concat(bytes, " "), table.concat(pixels, " ")))
    end

    -- Also show the corresponding NES CHR data (2BPP)
    -- NES tile is at (tile & 0xFF) in pattern table (tile >> 8) * $1000
    local nes_pt = (tile >> 8) & 1  -- 0 or 1
    local nes_tile_idx = tile & 0xFF
    local nes_chr_addr = nes_pt * 0x1000 + nes_tile_idx * 16

    -- NES CHR ROM is mapped starting at some address...
    -- Actually we can read the ROM data from M68K bus
    -- CommonBackgroundPatterns is in ROM, but CHR was uploaded to VRAM
    -- Let's just compare the converted data

    -- Check if tile has any non-zero data
    local nonzero = 0
    for i = 0, 31 do
        if vram_u8(vram_addr + i) ~= 0 then nonzero = nonzero + 1 end
    end
    log(string.format("  non-zero bytes: %d/32", nonzero))
    log("")
end

-- Also dump a summary: how many tiles in $100-$1FF range have data?
log("--- Tile data presence in $100-$1FF range ---")
local empty = 0
local has_data = 0
for tile = 0x100, 0x1FF do
    local vram_addr = tile * 32
    local nonzero = 0
    for i = 0, 31 do
        if vram_u8(vram_addr + i) ~= 0 then nonzero = nonzero + 1 end
    end
    if nonzero > 0 then
        has_data = has_data + 1
    else
        empty = empty + 1
    end
end
log(string.format("  Tiles with data: %d", has_data))
log(string.format("  Empty tiles: %d", empty))

-- Write report
local fh = io.open(REPORT, "w")
for _, line in ipairs(lines) do fh:write(line .. "\n") end
fh:close()
print("Tile data probe written to: " .. REPORT)
client.exit()
