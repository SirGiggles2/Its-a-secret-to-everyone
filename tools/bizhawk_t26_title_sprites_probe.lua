-- bizhawk_t26_title_sprites_probe.lua
-- T26: Title screen sprites visible (sword, Link).
--
-- After NMI stabilises (≥7 NMI fires), the demo-mode init runs and
-- places title-screen sprites in SAT.  We check:
--   1. At least 4 SAT entries are in the visible Y range (Genesis 129–352)
--   2. Those entries carry non-zero tile words (actual graphics, not blanked)
--   3. Sprites span at least 2 distinct Y bands (multi-row title layout)
--   4. Display is enabled (PPU_MASK has bg/spr bits set)
--   5. No exception was hit

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t26_title_sprites_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-30s  %s", status, name, detail))
    results[#results+1] = {name=name, status=status}
end

local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if     width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else                    return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS", bus_addr}, {"68K RAM", ofs},
        {"System Bus", bus_addr}, {"Main RAM", ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v end
    end
    return nil
end

local function vram_u16(addr) return try_dom("VRAM", addr, 2) or 0 end

local function main()
    local MAX_FRAMES = 600
    log("=================================================================")
    log("T26: Title Sprites Probe  —  up to " .. MAX_FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local exception_hit  = false
    local exception_name = nil
    local display_on_frame = nil

    for frame = 1, MAX_FRAMES do
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0

        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit  = true
                exception_name = (pc==EXC_BUS  and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
            end
        end

        if not display_on_frame then
            local pm = ram_read(0xFF0805, 1) or 0
            if (pm & 0x08) ~= 0 or (pm & 0x10) ~= 0 then
                display_on_frame = frame
            end
        end
    end

    -- Read full SAT (up to 80 sprites; we check first 32)
    local SAT_BASE   = 0xD800
    local SAT_SPRITES = 32

    log(string.format("─── SAT Snapshot (first %d sprites) ─────────────────────────────", SAT_SPRITES))
    log("  #   Y    link  tile   pri pal vf hf  X")

    local visible_sprites = 0
    local distinct_y_bands = {}
    local tile_nonzero_count = 0

    for i = 0, SAT_SPRITES - 1 do
        local base = SAT_BASE + i * 8
        local sy   = vram_u16(base)     & 0x1FF   -- 9-bit Y
        local sl   = vram_u16(base + 2) & 0x7F    -- link field
        local tw   = vram_u16(base + 4)            -- tile word
        local sx   = vram_u16(base + 6) & 0x1FF   -- 9-bit X

        local tile = tw & 0x07FF
        local pal  = (tw >> 13) & 3
        local pri  = (tw >> 15) & 1
        local vf   = (tw >> 12) & 1
        local hf   = (tw >> 11) & 1

        -- Genesis visible Y: 129–352 (NES Y 0–223 mapped via NES_Y + 129)
        local vis = (sy >= 129 and sy <= 352 and tile ~= 0)
        if vis then
            visible_sprites = visible_sprites + 1
            tile_nonzero_count = tile_nonzero_count + 1
            -- Y band: group by 16-pixel buckets
            local band = math.floor(sy / 16)
            distinct_y_bands[band] = true
        end

        if sy ~= 0 or tw ~= 0 then
            log(string.format("  %-3d %-4d %-5d %-6d %-3d %-3d %-2d %-2d  %-4d%s",
                i, sy, sl, tile, pri, pal, vf, hf, sx,
                vis and " ← visible" or ""))
        end
    end

    local band_count = 0
    for _ in pairs(distinct_y_bands) do band_count = band_count + 1 end

    log("")
    log(string.format("  Visible sprites (Y 129–352, non-zero tile): %d", visible_sprites))
    log(string.format("  Distinct Y-bands (16px buckets): %d", band_count))
    log(string.format("  Non-zero tile words among visible: %d", tile_nonzero_count))
    log("")

    -- ── Tests ─────────────────────────────────────────────────────────────
    log("─── T26: Title Sprites Tests ────────────────────────────────────")

    if not exception_hit then
        record("T26_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T26_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    if display_on_frame then
        record("T26_DISPLAY_ON", PASS,
            string.format("display enabled at frame %d", display_on_frame))
    else
        record("T26_DISPLAY_ON", FAIL, "display never enabled (PPU_MASK bg/spr bits never set)")
    end

    -- T26_SPRITES_VISIBLE: ≥ 4 sprites in visible Y range with non-zero tiles
    if visible_sprites >= 4 then
        record("T26_SPRITES_VISIBLE", PASS,
            string.format("%d sprites in visible Y range (129–352) with non-zero tiles", visible_sprites))
    else
        record("T26_SPRITES_VISIBLE", FAIL,
            string.format("only %d sprites in visible Y range (need ≥ 4)", visible_sprites))
    end

    -- T26_MULTI_ROW: sprites span ≥ 2 distinct Y bands → title layout has multiple rows
    if band_count >= 2 then
        record("T26_MULTI_ROW", PASS,
            string.format("%d distinct Y-bands — sprites span multiple screen rows", band_count))
    else
        record("T26_MULTI_ROW", FAIL,
            string.format("only %d Y-band(s) — sprites all on same row or none visible", band_count))
    end

    -- T26_TILE_CONTENT: ≥ 4 visible sprites have non-trivial tile index (> 0, < 0x400)
    local content_tiles = 0
    for i = 0, SAT_SPRITES - 1 do
        local base = SAT_BASE + i * 8
        local sy   = vram_u16(base)     & 0x1FF
        local tw   = vram_u16(base + 4)
        local tile = tw & 0x07FF
        if sy >= 129 and sy <= 352 and tile > 0 and tile < 0x400 then
            content_tiles = content_tiles + 1
        end
    end
    if content_tiles >= 4 then
        record("T26_TILE_CONTENT", PASS,
            string.format("%d visible sprites have plausible tile indices (0 < tile < 0x400)", content_tiles))
    else
        record("T26_TILE_CONTENT", FAIL,
            string.format("only %d visible sprites have plausible tile indices", content_tiles))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("T26 TITLE SPRITES SUMMARY")
    log("=================================================================")
    local pass_cnt, fail_cnt = 0, 0
    for _, res in ipairs(results) do
        log(string.format("  [%s] %s", res.status, res.name))
        if res.status == PASS then pass_cnt = pass_cnt + 1
        else                       fail_cnt = fail_cnt + 1 end
    end
    log("")
    log(string.format("  %d PASS  /  %d FAIL  /  %d total", pass_cnt, fail_cnt, #results))
    log("")
    if fail_cnt == 0 then log("T26 TITLE SPRITES: ALL PASS")
    else                  log("T26 TITLE SPRITES: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
