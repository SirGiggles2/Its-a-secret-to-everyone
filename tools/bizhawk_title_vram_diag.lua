-- bizhawk_title_vram_diag.lua
-- Comprehensive title screen VRAM diagnostic.
-- Captures at frame 100 (after all init subphases complete):
--   1. VRAM tile data for known tiles (text vs artwork)
--   2. Plane A nametable entries for key rows
--   3. CRAM palette data
--   4. Expected vs actual tile data comparison

local ROOT   = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT = ROOT .. "builds/reports/bizhawk_title_vram_diag.txt"

local lines = {}
local function log(s) lines[#lines+1] = s print(s) end

local function vram_read_byte(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function vram_read_word(addr)
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

local function bus_read(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

-- Dump 32 bytes of VRAM (one Genesis tile)
local function dump_vram_tile(tile_idx)
    local base = tile_idx * 32
    local s = ""
    for i = 0, 31 do
        if i > 0 and i % 4 == 0 then s = s .. " | " end
        s = s .. string.format("%02X", vram_read_byte(base + i))
    end
    return s
end

local function tile_is_blank(tile_idx)
    local base = tile_idx * 32
    for i = 0, 31 do
        if vram_read_byte(base + i) ~= 0 then
            return false
        end
    end
    return true
end

-- Dump Plane A entry (16-bit word) at row, col
-- Plane A at $C000, 64 tiles wide (128 bytes per row)
local function plane_a_word(row, col)
    local addr = 0xC000 + row * 128 + col * 2
    return vram_read_word(addr)
end

-- Decode Plane A word
local function decode_plane_a(w)
    local pri = (w >> 15) & 1
    local pal = (w >> 13) & 3
    local vf  = (w >> 12) & 1
    local hf  = (w >> 11) & 1
    local tile = w & 0x7FF
    return string.format("t$%03X p%d pri%d vf%d hf%d", tile, pal, pri, vf, hf)
end

local function log_decoded_row_entries(label, row, start_col, end_col)
    log(label)
    for col = start_col, end_col do
        local w = plane_a_word(row, col)
        log(string.format("    col%02d: $%04X = %s", col, w, decode_plane_a(w)))
    end
    log("")
end

-- Expected 4BPP conversion of NES 2BPP tile
-- NES tile: 8 bytes plane0, 8 bytes plane1
local expand_lut = {
    [0]= 0x0000, 0x0001, 0x0010, 0x0011, 0x0100, 0x0101, 0x0110, 0x0111,
          0x1000, 0x1001, 0x1010, 0x1011, 0x1100, 0x1101, 0x1110, 0x1111
}

local function nes_2bpp_to_4bpp(tile_bytes)
    -- tile_bytes: array of 16 bytes (plane0[0..7], plane1[0..7])
    local result = {}
    for row = 0, 7 do
        local p0 = tile_bytes[row + 1]
        local p1 = tile_bytes[row + 9]

        -- Upper nibble (pixels 0-3)
        local p0_hi = math.floor(p0 / 16) % 16
        local p1_hi = math.floor(p1 / 16) % 16
        local w_hi = expand_lut[p0_hi] + expand_lut[p1_hi] * 2

        -- Lower nibble (pixels 4-7)
        local p0_lo = p0 % 16
        local p1_lo = p1 % 16
        local w_lo = expand_lut[p0_lo] + expand_lut[p1_lo] * 2

        result[row * 4 + 1] = math.floor(w_hi / 256)
        result[row * 4 + 2] = w_hi % 256
        result[row * 4 + 3] = math.floor(w_lo / 256)
        result[row * 4 + 4] = w_lo % 256
    end
    return result
end

local CAPTURE_FRAME = 100

local function main()
    for _ = 1, CAPTURE_FRAME do
        emu.frameadvance()
    end

    log("=================================================================")
    log("Title Screen VRAM Diagnostic — Frame " .. CAPTURE_FRAME)
    log("=================================================================")
    log("")

    -- 1. PPU state
    local ppu_ctrl = bus_read(0xFF0804 + 4)   -- PPU_CTRL
    local ppu_mask = bus_read(0xFF0804 + 5)   -- PPU_MASK
    local ppu_vaddr_hi = bus_read(0xFF0804 + 0)
    local ppu_vaddr_lo = bus_read(0xFF0804 + 1)
    local tilebuf_sel = bus_read(0xFF0014)
    local game_mode = bus_read(0xFF0012)
    local init_flag = bus_read(0xFF0011)
    local subphase = bus_read(0xFF042D)
    local phase = bus_read(0xFF042C)

    log(string.format("PPU_CTRL=$%02X  PPU_MASK=$%02X  PPU_VADDR=$%02X%02X",
        ppu_ctrl, ppu_mask, ppu_vaddr_hi, ppu_vaddr_lo))
    log(string.format("TileBufSel=$%02X  GameMode=$%02X  InitFlag=$%02X  Phase=$%02X  Subphase=$%02X",
        tilebuf_sel, game_mode, init_flag, phase, subphase))
    log("")

    -- 2. CRAM dump (all 4 palettes)
    log("--- CRAM (all 4 palettes) ---")
    for pal = 0, 3 do
        local s = string.format("  pal%d:", pal)
        for c = 0, 15 do
            s = s .. string.format(" %04X", cram_u16((pal * 16 + c) * 2))
        end
        log(s)
    end
    log("")

    -- 3. Plane A entries for key rows
    log("--- Plane A Row 0 (should be blank $24 tiles) ---")
    local s = "  "
    for col = 0, 31 do
        local w = plane_a_word(0, col)
        s = s .. string.format("%04X ", w)
        if col == 15 then log(s); s = "  " end
    end
    log(s)
    log("")
    log_decoded_row_entries("--- Plane A Row 0 decoded blank entries ---", 0, 0, 7)

    log("--- Plane A Row 7 (first artwork row: $71-$7B in cols 8-20) ---")
    s = "  "
    for col = 0, 31 do
        local w = plane_a_word(7, col)
        s = s .. string.format("%04X ", w)
        if col == 15 then log(s); s = "  " end
    end
    log(s)
    log_decoded_row_entries("  Decoded key entries:", 7, 6, 22)

    log("--- Plane A Row 17 (PUSH START BUTTON text area) ---")
    s = "  "
    for col = 0, 31 do
        local w = plane_a_word(17, col)
        s = s .. string.format("%04X ", w)
        if col == 15 then log(s); s = "  " end
    end
    log(s)
    log("")

    -- 4. VRAM tile data comparison
    -- First artwork tile: NES tile $70, Genesis tile $170
    -- DemoBackgroundPatterns first 16 bytes: $00,$00,$00,$FC,$C7,$E7,$F7,$FF,$FF,$FF,$FF,$FF,$38,$38,$38,$78
    local nes_tile_70 = {0x00,0x00,0x00,0xFC,0xC7,0xE7,0xF7,0xFF,
                         0xFF,0xFF,0xFF,0xFF,0x38,0x38,0x38,0x78}
    local expected_4bpp = nes_2bpp_to_4bpp(nes_tile_70)

    log("--- VRAM Tile $170 (first artwork tile = NES BG $70) ---")
    log("  Actual VRAM:   " .. dump_vram_tile(0x170))
    s = ""
    for i = 1, 32 do
        if i > 1 and (i-1) % 4 == 0 then s = s .. " | " end
        s = s .. string.format("%02X", expected_4bpp[i])
    end
    log("  Expected 4BPP: " .. s)

    local match = true
    for i = 1, 32 do
        if vram_read_byte(0x170 * 32 + i - 1) ~= expected_4bpp[i] then
            match = false
            break
        end
    end
    log("  Match: " .. (match and "YES" or "NO *** MISMATCH ***"))
    log("")

    -- Blank filler tile in sprite half: Genesis tile $024
    log("--- VRAM Tile $024 (sprite-half slot used if BG offset is missing) ---")
    log("  Actual:  " .. dump_vram_tile(0x024))
    log("")

    -- Text tile: NES tile $24 (blank), Genesis tile $124
    log("--- VRAM Tile $124 (blank tile $24) ---")
    log("  Actual:  " .. dump_vram_tile(0x124))
    log("  Blank:   " .. (tile_is_blank(0x124) and "YES" or "NO *** SHOULD BE ALL ZEROS ***"))
    log("")

    -- Common BG tile 0: Genesis tile $100
    log("--- VRAM Tile $100 (first common BG tile) ---")
    log("  Actual:  " .. dump_vram_tile(0x100))
    log("")

    -- A text tile: NES tile $19 = 'P', Genesis tile $119
    log("--- VRAM Tile $119 (letter 'P') ---")
    log("  Actual:  " .. dump_vram_tile(0x119))
    log("")

    -- Second artwork tile: tile $171
    log("--- VRAM Tile $171 (second artwork tile) ---")
    log("  Actual:  " .. dump_vram_tile(0x171))
    log("")

    -- 5. Check if Genesis tile $70 (without +$100) has any data
    -- This would be in sprite area
    log("--- VRAM Tile $070 (sprite area, should NOT be artwork) ---")
    log("  Actual:  " .. dump_vram_tile(0x070))
    log("")

    -- 6. Check DynTileBuf state
    log("--- DynTileBuf ($FF0302) first 4 bytes ---")
    s = "  "
    for i = 0, 3 do
        s = s .. string.format("%02X ", bus_read(0xFF0302 + i))
    end
    log(s)
    log("")

    -- 7. Plane A entries for rows 20-25 (waterfall area)
    log("--- Plane A Row 22 (waterfall/bottom area) ---")
    s = "  "
    for col = 0, 31 do
        local w = plane_a_word(22, col)
        s = s .. string.format("%04X ", w)
        if col == 15 then log(s); s = "  " end
    end
    log(s)
    log("")

    -- 8. Check a few more artwork tiles
    for _, tidx in ipairs({0x180, 0x190, 0x1A0, 0x1B0}) do
        log(string.format("--- VRAM Tile $%03X ---", tidx))
        log("  Actual:  " .. dump_vram_tile(tidx))
    end
    log("")

    log("=================================================================")
    log("DIAGNOSTIC COMPLETE")
    log("=================================================================")

    local f = io.open(REPORT, "w")
    if f then
        f:write(table.concat(lines, "\n") .. "\n")
        f:close()
        print("Report written to: " .. REPORT)
    end
    client.exit()
end

main()
