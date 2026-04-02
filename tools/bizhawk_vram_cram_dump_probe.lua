-- bizhawk_vram_cram_dump_probe.lua
-- Dumps Genesis CRAM (palette) and key VRAM tile bytes for pixel-level diagnosis.
-- Captures at frame 50 (after TransferCommonPatterns has run).
--
-- Output: builds/reports/bizhawk_vram_cram_dump.txt

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_vram_cram_dump.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

-- ── Domain helpers ──────────────────────────────────────────────────────────
local function try_dom(dom, addr, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if     width == 1 then return memory.read_u8(addr)
        elseif width == 2 then return memory.read_u16_be(addr)
        else                    return memory.read_u32_be(addr) end
    end)
    return ok and v or nil
end

local function vram_u8(addr)
    for _, d in ipairs({"VRAM", "VDP VRAM"}) do
        local v = try_dom(d, addr, 1)
        if v ~= nil then return v end
    end
    return 0
end

local function cram_u16(addr)
    -- CRAM in BizHawk GPGX: 128 bytes (64 entries × 2 bytes), big-endian
    for _, d in ipairs({"CRAM", "VDP CRAM", "Color RAM"}) do
        local v = try_dom(d, addr, 2)
        if v ~= nil then return v end
    end
    return 0
end

-- ── Dump helpers ─────────────────────────────────────────────────────────────
local function dump_bytes(domain_fn, base, count, label)
    log(string.format("  %s (base=$%04X, %d bytes):", label, base, count))
    local line = ""
    for i = 0, count-1 do
        local b = domain_fn(base + i)
        line = line .. string.format("%02X ", b)
        if (i+1) % 16 == 0 then
            log("    " .. string.format("[+%03X] ", i-15) .. line)
            line = ""
        end
    end
    if #line > 0 then log("    " .. line) end
end

local function dump_cram()
    log("  CRAM (64 entries, Genesis 9-bit colors):")
    for i = 0, 63 do
        local word = cram_u16(i * 2)
        -- Genesis 9-bit color: BBB0GGG0RRR0 packed as 16-bit, only low 9 bits matter
        -- Bit layout: ----bbb-ggg-rrr- (some sources) or ----BBBbGGGgRRRr
        -- GPGX stores as: 0000 BBB0 GGG0 RRR0 (bits 11:9=B, 7:5=G, 3:1=R, each *2)
        local r = (word >> 1) & 7
        local g = (word >> 5) & 7
        local b = (word >> 9) & 7
        local pal = i >> 4
        local idx = i & 15
        log(string.format("    CRAM[%02d][%02d] = $%04X  R=%d G=%d B=%d", pal, idx, word, r, g, b))
    end
end

-- ── Main ─────────────────────────────────────────────────────────────────────
local function main()
    local CAPTURE_FRAME = 200

    log("=================================================================")
    log("VRAM + CRAM Dump Probe  —  capturing at frame " .. CAPTURE_FRAME)
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local exception_hit = false
    for frame = 1, CAPTURE_FRAME + 2 do
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            exception_hit = true
        end
    end

    log("Exception hit: " .. tostring(exception_hit))
    log("")

    -- ── CRAM dump ────────────────────────────────────────────────────────────
    log("─── CRAM (Genesis Palette) ─────────────────────────────────────────")
    dump_cram()
    log("")

    -- ── VRAM tile $24 (BG crosshatch tile, index 36) ─────────────────────────
    -- Genesis VRAM address = tile_index * 32
    local tile24_base = 0x24 * 32   -- = 0x480
    log("─── VRAM Tile $24 (BG tile, VRAM offset=$" .. string.format("%04X", tile24_base) .. ") ─────")
    dump_bytes(vram_u8, tile24_base, 32, "tile24")
    log("")

    -- ── VRAM sprite tile 160 ─────────────────────────────────────────────────
    local tile160_base = 160 * 32  -- = 0x1400
    log("─── VRAM Tile 160 (sprite tile, VRAM offset=$" .. string.format("%04X", tile160_base) .. ") ─")
    dump_bytes(vram_u8, tile160_base, 32, "tile160")
    log("")

    -- ── VRAM tile 0 (first tile — should have data if CHR running) ────────────
    log("─── VRAM Tile 0 (VRAM offset=$0000) ───────────────────────────────")
    dump_bytes(vram_u8, 0, 32, "tile0")
    log("")

    -- ── Also dump tiles 1–5 row 0 (quick sanity) ─────────────────────────────
    log("─── VRAM Tiles 1-5 row0 bytes ──────────────────────────────────────")
    for t = 1, 5 do
        local base = t * 32
        local row = ""
        for b = 0, 3 do row = row .. string.format("%02X ", vram_u8(base+b)) end
        log(string.format("  tile%d row0: %s", t, row))
    end
    log("")

    -- ── Plane A VRAM peek (first 8 entries of nametable @ $C000) ─────────────
    log("─── Plane A nametable first 16 entries (VRAM $C000) ────────────────")
    for i = 0, 15 do
        local w = cram_u16 and 0 or 0  -- use vram for nametable
        -- nametable entries are words in VRAM at $C000+
        local hi = vram_u8(0xC000 + i*2)
        local lo = vram_u8(0xC000 + i*2 + 1)
        local word = (hi << 8) | lo
        log(string.format("  NT[%02d] = $%04X (tile=$%03X pal=%d)", i, word, word & 0x7FF, (word >> 13) & 3))
    end
    log("")

    -- ── Screenshot ───────────────────────────────────────────────────────────
    local ss_path = OUT_DIR .. "screenshot_frame" .. CAPTURE_FRAME .. ".png"
    client.screenshot(ss_path)
    log("Screenshot saved: " .. ss_path)

    log("=================================================================")
    log("VRAM + CRAM DUMP COMPLETE")
    log("=================================================================")
    f:close()
    client.exit()
end

main()
