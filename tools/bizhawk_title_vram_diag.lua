-- bizhawk_title_vram_diag.lua
-- Fixed-frame title screen diagnostic.
-- Captures at frame 200 and reports:
--   1. CRAM palette state
--   2. Plane A rows for the logo box and lower title scene
--   3. SAT decode for the first 32 sprites
--   4. High-risk VRAM tile comparisons against the embedded pattern blocks
--   5. A screenshot for direct visual comparison

local ROOT       = "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/"
local REPORT     = ROOT .. "builds/reports/bizhawk_title_vram_diag.txt"
local SCREENSHOT = ROOT .. "builds/reports/screenshot_frame200.png"
local LISTING    = ROOT .. "builds/whatif.lst"
local CAPTURE_FRAME = 200

local lines = {}
local function log(s)
    lines[#lines + 1] = s
    print(s)
end

local function try_read(domain, addr, width)
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        if width == 2 then
            return memory.read_u16_be(addr)
        end
        return memory.read_u8(addr)
    end)
    return ok and value or nil
end

local function vram_u8(addr)
    return try_read("VRAM", addr, 1) or 0
end

local function vram_u16(addr)
    return try_read("VRAM", addr, 2) or 0
end

local function cram_u16(addr)
    return try_read("CRAM", addr, 2) or 0
end

local function vsram_u16(addr)
    return try_read("VSRAM", addr, 2) or 0
end

local function bus_u8(addr)
    return try_read("M68K BUS", addr, 1) or 0
end

local function read_listing_addrs(path)
    local addrs = {}
    local f = io.open(path, "r")
    if not f then
        return addrs
    end

    for line in f:lines() do
        local hex1, name1 = line:match("^(%x%x%x%x%x%x%x%x) (%w+)$")
        if hex1 and name1 then
            addrs[name1] = tonumber(hex1, 16)
        end
        local name2, hex2 = line:match("^(%w+)%s+A:(%x+)$")
        if name2 and hex2 then
            addrs[name2] = tonumber(hex2, 16)
        end
    end

    f:close()
    return addrs
end

local SYM = read_listing_addrs(LISTING)

local function require_sym(name)
    local value = SYM[name]
    if not value then
        error("title_vram_diag: symbol '" .. name .. "' missing from builds/whatif.lst")
    end
    return value
end

local DEMO_SPRITE_PATTERNS     = require_sym("DemoSpritePatterns")
local DEMO_BACKGROUND_PATTERNS = require_sym("DemoBackgroundPatterns")
local COMMON_BACKGROUND_PATTERNS = require_sym("CommonBackgroundPatterns")
local INITIAL_TITLE_SPRITES    = require_sym("InitialTitleSprites")

local function dump_vram_tile(tile_idx)
    local base = tile_idx * 32
    local parts = {}
    for i = 0, 31 do
        parts[#parts + 1] = string.format("%02X", vram_u8(base + i))
    end
    return table.concat(parts, "")
end

local function dump_vram_tile_grouped(tile_idx)
    local base = tile_idx * 32
    local parts = {}
    for i = 0, 31 do
        if i > 0 and i % 4 == 0 then
            parts[#parts + 1] = "|"
        end
        parts[#parts + 1] = string.format("%02X", vram_u8(base + i))
    end
    return table.concat(parts, " ")
end

local function tile_is_blank(tile_idx)
    local base = tile_idx * 32
    for i = 0, 31 do
        if vram_u8(base + i) ~= 0 then
            return false
        end
    end
    return true
end

local function plane_a_word(row, col)
    return vram_u16(0xC000 + row * 128 + col * 2)
end

local function decode_plane_a(word)
    local pri = (word >> 15) & 1
    local pal = (word >> 13) & 3
    local vf  = (word >> 12) & 1
    local hf  = (word >> 11) & 1
    local tile = word & 0x7FF
    return string.format("t$%03X p%d pri%d vf%d hf%d", tile, pal, pri, vf, hf)
end

local expand_lut = {
    [0] = 0x0000, 0x0001, 0x0010, 0x0011, 0x0100, 0x0101, 0x0110, 0x0111,
            0x1000, 0x1001, 0x1010, 0x1011, 0x1100, 0x1101, 0x1110, 0x1111
}

local function nes_2bpp_to_4bpp(tile_bytes)
    local result = {}
    for row = 0, 7 do
        local p0 = tile_bytes[row + 1]
        local p1 = tile_bytes[row + 9]

        local p0_hi = math.floor(p0 / 16) % 16
        local p1_hi = math.floor(p1 / 16) % 16
        local w_hi = expand_lut[p0_hi] + expand_lut[p1_hi] * 2

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

local function expected_tile_bytes(source_base, tile_offset)
    local nes_tile = {}
    for i = 0, 15 do
        nes_tile[#nes_tile + 1] = bus_u8(source_base + tile_offset * 16 + i)
    end
    return nes_2bpp_to_4bpp(nes_tile), nes_tile
end

local function actual_tile_bytes(tile_idx)
    local out = {}
    local base = tile_idx * 32
    for i = 0, 31 do
        out[#out + 1] = vram_u8(base + i)
    end
    return out
end

local function bytes_to_string(bytes)
    local parts = {}
    for i = 1, #bytes do
        if i > 1 and (i - 1) % 4 == 0 then
            parts[#parts + 1] = "|"
        end
        parts[#parts + 1] = string.format("%02X", bytes[i])
    end
    return table.concat(parts, " ")
end

local function compare_tile(tile_idx, source_label, source_base, source_tile, note)
    local expected, raw_nes = expected_tile_bytes(source_base, source_tile)
    local actual = actual_tile_bytes(tile_idx)
    local match = true
    for i = 1, 32 do
        if actual[i] ~= expected[i] then
            match = false
            break
        end
    end

    log(string.format("--- Tile $%03X  <=  %s[$%02X]  %s ---",
        tile_idx, source_label, source_tile, note or ""))
    log("  Actual  : " .. bytes_to_string(actual))
    log("  Expected: " .. bytes_to_string(expected))
    log("  NES 2BPP: " .. bytes_to_string(raw_nes))
    log("  Match   : " .. (match and "YES" or "NO *** MISMATCH ***"))
    log("")
    return match
end

local function log_plane_rows(title, row_start, row_end)
    log(title)
    for row = row_start, row_end do
        local parts = {}
        for col = 0, 31 do
            local word = plane_a_word(row, col)
            local tile = word & 0x7FF
            local pal = (word >> 13) & 3
            parts[#parts + 1] = string.format("%d:%03X", pal, tile)
        end
        log(string.format("  r%02d: %s", row, table.concat(parts, " ")))
    end
    log("")
end

local function sat_entry(idx)
    local base = 0xD800 + idx * 8
    local word0 = vram_u16(base + 0)
    local word1 = vram_u16(base + 2)
    local word2 = vram_u16(base + 4)
    local word3 = vram_u16(base + 6)
    return {
        y = word0 & 0x1FF,
        link = word1 & 0x7F,
        szv = (word1 >> 8) & 0x3,
        szh = (word1 >> 10) & 0x3,
        pri = (word2 >> 15) & 0x1,
        pal = (word2 >> 13) & 0x3,
        vf = (word2 >> 12) & 0x1,
        hf = (word2 >> 11) & 0x1,
        tile = word2 & 0x7FF,
        x = word3 & 0x1FF,
    }
end

local function expected_sat_from_oam(sprite_index, ppu_ctrl, game_mode)
    local base = INITIAL_TITLE_SPRITES + sprite_index * 4
    local nes_y = bus_u8(base + 0)
    local nes_tile = bus_u8(base + 1)
    local attr = bus_u8(base + 2)
    local nes_x = bus_u8(base + 3)

    local tile = nes_tile
    if ((ppu_ctrl >> 5) & 1) ~= 0 then
        tile = ((nes_tile & 1) << 8) | (nes_tile & 0xFE)
    elseif ((ppu_ctrl >> 3) & 1) ~= 0 then
        tile = 0x100 | nes_tile
    end

    local title_y_bias = 0
    if game_mode == 0x00 then
        title_y_bias = -8
    end

    return {
        y = nes_y + 129 + title_y_bias,
        x = nes_x + 128,
        tile = tile,
        pal = attr & 0x03,
        vf = (attr >> 7) & 1,
        hf = (attr >> 6) & 1,
        pri = 1,
        link = (sprite_index == 63) and 0 or (sprite_index + 1),
    }
end

local function log_sat_range(header, start_idx, end_idx, ppu_ctrl, game_mode)
    log(header)
    log("  #   Y    X    Tile Pal Pri VF HF Link  Notes")
    for idx = start_idx, end_idx do
        local actual = sat_entry(idx)
        local note = ""
        if idx < 28 then
            local expected = expected_sat_from_oam(idx, ppu_ctrl, game_mode)
            local ok = actual.y == expected.y
                and actual.x == expected.x
                and actual.tile == expected.tile
                and actual.pal == expected.pal
                and actual.pri == expected.pri
                and actual.vf == expected.vf
                and actual.hf == expected.hf
                and actual.link == expected.link
            note = ok and "template match" or string.format(
                "expected Y=%d X=%d T=%03X P=%d VF=%d HF=%d L=%d",
                expected.y, expected.x, expected.tile, expected.pal,
                expected.vf, expected.hf, expected.link
            )
        elseif idx <= 39 then
            note = "waterfall body / animated title sprites"
        elseif idx >= 60 and idx <= 63 then
            note = "waterfall crest / animated title sprites"
        else
            note = "animated title sprites"
        end

        log(string.format("  %02d  %03d  %03d  %03X   %d   %d   %d  %d   %02d   %s",
            idx, actual.y, actual.x, actual.tile, actual.pal,
            actual.pri, actual.vf, actual.hf, actual.link, note))
    end
    log("")
end

local function main()
    for _ = 1, CAPTURE_FRAME do
        emu.frameadvance()
    end

    local ppu_ctrl = bus_u8(0xFF00FF)
    local ppu_mask = bus_u8(0xFF0100)
    local game_mode = bus_u8(0xFF0012)
    local init_flag = bus_u8(0xFF0011)
    local phase = bus_u8(0xFF042C)
    local subphase = bus_u8(0xFF042D)

    log("=================================================================")
    log("Title Screen VRAM Diagnostic - Frame " .. CAPTURE_FRAME)
    log("=================================================================")
    log("")
    log(string.format("PPU_CTRL=$%02X  PPU_MASK=$%02X  GameMode=$%02X  InitFlag=$%02X  Phase=$%02X  Subphase=$%02X",
        ppu_ctrl, ppu_mask, game_mode, init_flag, phase, subphase))
    log(string.format("Symbols: DemoSP=$%06X DemoBG=$%06X CommonBG=$%06X TitleSprites=$%06X",
        DEMO_SPRITE_PATTERNS, DEMO_BACKGROUND_PATTERNS,
        COMMON_BACKGROUND_PATTERNS, INITIAL_TITLE_SPRITES))
    log("")
    log(string.format("VSRAM A=$%04X  VSRAM B=$%04X", vsram_u16(0), vsram_u16(2)))
    log(string.format("Waterfall state: %02X %02X %02X %02X %02X %02X %02X",
        bus_u8(0xFF041F), bus_u8(0xFF0420), bus_u8(0xFF0421), bus_u8(0xFF0422),
        bus_u8(0xFF0423), bus_u8(0xFF0424), bus_u8(0xFF0425)))
    log("")

    log("--- CRAM (all 4 palettes) ---")
    for pal = 0, 3 do
        local parts = {}
        for col = 0, 15 do
            parts[#parts + 1] = string.format("%04X", cram_u16((pal * 16 + col) * 2))
        end
        log(string.format("  pal%d: %s", pal, table.concat(parts, " ")))
    end
    log("")

    log("--- Title sanity tiles ---")
    log("  Tile $024: " .. dump_vram_tile_grouped(0x024))
    log("  Tile $124: " .. dump_vram_tile_grouped(0x124))
    log("  Tile $170: " .. dump_vram_tile_grouped(0x170))
    log("  Tile $171: " .. dump_vram_tile_grouped(0x171))
    log("  Tile $124 blank: " .. (tile_is_blank(0x124) and "YES" or "NO"))
    log("")

    log_plane_rows("--- Plane A rows 7-15 (logo box) ---", 7, 15)
    log_plane_rows("--- Plane A rows 22-29 (lower title scene) ---", 22, 29)

    log_sat_range("--- SAT sprites 0-39 (title template + waterfall body) ---", 0, 39, ppu_ctrl, game_mode)
    log_sat_range("--- SAT sprites 60-63 (waterfall crest) ---", 60, 63, ppu_ctrl, game_mode)

    log("--- Genesis OAM buffer sprites 60-63 (pre-DMA, NES_RAM+$0200) ---")
    log("  #   y     tile  attr  x")
    for idx = 60, 63 do
        local base = 0xFF0200 + idx * 4
        local y    = bus_u8(base + 0)
        local tile = bus_u8(base + 1)
        local attr = bus_u8(base + 2)
        local x    = bus_u8(base + 3)
        log(string.format("  %02d  $%02X   $%02X   $%02X   $%02X", idx, y, tile, attr, x))
    end
    log("")

    log("--- High-risk tile comparisons ---")
    local mismatches = 0
    local function check(match)
        if not match then
            mismatches = mismatches + 1
        end
    end

    for _, tile in ipairs({0x0A0, 0x0CA, 0x0CC, 0x0CE, 0x0D0, 0x0D2, 0x0D4, 0x0D6}) do
        check(compare_tile(tile, "DemoSpritePatterns", DEMO_SPRITE_PATTERNS, tile - 0x070, "title sprite tile"))
    end

    check(compare_tile(0x126, "CommonBackgroundPatterns", COMMON_BACKGROUND_PATTERNS, 0x26, "lower scene blank/fill tile"))

    for tile = 0x1C6, 0x1D2 do
        check(compare_tile(tile, "DemoBackgroundPatterns", DEMO_BACKGROUND_PATTERNS, tile - 0x170, "sword/triforce title BG"))
    end

    for tile = 0x1D4, 0x1F0 do
        check(compare_tile(tile, "DemoBackgroundPatterns", DEMO_BACKGROUND_PATTERNS, tile - 0x170, "wall/waterfall/lower title BG"))
    end

    log(string.format("Total tile mismatches in checked title set: %d", mismatches))
    log("")

    client.screenshot(SCREENSHOT)
    log("Screenshot written to: " .. SCREENSHOT)
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
