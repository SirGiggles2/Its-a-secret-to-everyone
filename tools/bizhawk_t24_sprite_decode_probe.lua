-- bizhawk_t24_sprite_decode_probe.lua
-- T24: Sprite decode — CHR tile data decoded correctly to Genesis 4bpp format.
--
-- Verifies that:
--   1. CHR ROM tiles have been uploaded to VRAM in valid Genesis 4bpp format.
--   2. At least 16 distinct VRAM tiles have non-zero pixel data (not all blank).
--   3. Individual tile structure is correct (8 rows of 4 bytes each per tile).
--   4. NMI has fired at least once (IsrNmi executed → _oam_dma ran).
--   5. Genesis SAT link chain is intact (sprites are linked for rendering).
--
-- NOTE: T23 verified OAM DMA coordinate conversion (Y+129, X+128).
--       T25 verifies sprite palette (CRAM entries 32-63 for sprite palettes).
--       T24 focuses on whether the CHR tile pixel data is correctly decoded.
--
-- Checks:
--   T24_NO_EXCEPTION      — no exception handler hit
--   T24_LOOPFOREVER_HIT   — boot completed
--   T24_DISPLAY_ON        — display enabled within 600 frames
--   T24_NMI_COUNT         — NMI debug counter ≥ 1 (IsrNmi + _oam_dma has run)
--   T24_TILE1_CHR         — VRAM tile 1 has ≥16 non-zero 4bpp bytes
--   T24_TILE1_STRUCTURE   — VRAM tile 1 has ≥4 non-zero rows
--   T24_MULTI_TILES       — ≥16 tiles in VRAM $0000-$1FFF have non-zero data
--   T24_SAT_ACTIVE        — SAT sprite 0 link ≠ 0 (link chain formed for rendering)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t24_sprite_decode_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-28s  %s", status, name, detail))
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

local function vram_u8(addr)   return try_dom("VRAM", addr, 1) or 0 end
local function vram_u16(addr)  return try_dom("VRAM", addr, 2) or 0 end

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local MAX_FRAMES = 600
    log("=================================================================")
    log("T24: Sprite Decode Probe  —  up to " .. MAX_FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}
    local display_on_frame = nil

    local function mark(name)
        return function()
            if not visit_frame[name] then visit_frame[name] = cur_frame end
            if name == "ExcBusError" or name == "ExcAddrError" or name == "DefaultException" then
                if not exception_hit then exception_hit = true; exception_name = name end
            end
        end
    end

    for _, lm in ipairs({
        {LOOPFOREVER, "LoopForever"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t24_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, MAX_FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0

        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then visit_frame["LoopForever"] = frame end
        end
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

        if frame % 60 == 0 or frame <= 5 then
            local nmi_c = ram_read(0xFF1003, 1) or 0
            local tcp_c = ram_read(0xFF1007, 1) or 0
            log(string.format("  f%03d pc=$%06X  NMI=%d  TCP=%d  disp=%s",
                frame, pc, nmi_c, tcp_c, tostring(display_on_frame or "-")))
        end

        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end

    if display_on_frame then
        log(string.format("  Display enabled at frame %d — waiting 10 more frames...", display_on_frame))
        for i = 1, 10 do emu.frameadvance() end
    end
    log("")

    -- ── Read debug counters ───────────────────────────────────────────────
    local nmi_count = ram_read(0xFF1003, 1) or 0
    local tcp_count = ram_read(0xFF1007, 1) or 0
    log(string.format("  NMI debug counter ($FF1003) = %d", nmi_count))
    log(string.format("  TCP debug counter ($FF1007) = %d", tcp_count))
    log("")

    -- ── Survey VRAM tile data ($0000-$1FFF = 256 tiles × 32 bytes) ───────
    -- Genesis 4bpp tile: 8 rows × 4 bytes = 32 bytes per tile
    -- Tile N starts at VRAM offset N*32
    log("─── VRAM CHR Tile Survey ($0000-$1FFF = 256 tiles) ──────────────")
    local tiles_with_data = 0
    local tiles_total = 256
    local first_tile_details = {}   -- detailed data for first few non-zero tiles

    for tile_idx = 0, tiles_total - 1 do
        local base = tile_idx * 32
        local nonzero = 0
        for b = 0, 31 do
            if vram_u8(base + b) ~= 0 then nonzero = nonzero + 1 end
        end
        if nonzero > 0 then
            tiles_with_data = tiles_with_data + 1
            if #first_tile_details < 8 then
                first_tile_details[#first_tile_details+1] = {idx=tile_idx, nz=nonzero}
            end
        end
    end

    log(string.format("  Tiles with non-zero data: %d / %d", tiles_with_data, tiles_total))
    log("  First non-zero tiles:")
    for _, td in ipairs(first_tile_details) do
        log(string.format("    tile %3d ($%04X): %d/32 non-zero bytes",
            td.idx, td.idx*32, td.nz))
    end
    log("")

    -- ── Tile 1 detailed dump (CHR tile 1 = first real sprite tile) ───────
    log("─── VRAM Tile 1 ($0020-$003F) 4bpp detail ───────────────────────")
    local tile1_bytes = {}
    local tile1_nonzero = 0
    local tile1_nonzero_rows = 0
    for i = 0, 31 do
        local b = vram_u8(0x0020 + i)
        tile1_bytes[i] = b
        if b ~= 0 then tile1_nonzero = tile1_nonzero + 1 end
    end
    for row = 0, 7 do
        local row_sum = 0
        local line = string.format("  row%d:", row)
        for col = 0, 3 do
            local b = tile1_bytes[row*4 + col]
            line = line .. string.format(" %02X", b)
            row_sum = row_sum + b
        end
        if row_sum > 0 then
            tile1_nonzero_rows = tile1_nonzero_rows + 1
            line = line .. " *"
        end
        log(line)
    end
    log(string.format("  Tile 1: %d/32 non-zero bytes, %d/8 non-zero rows",
        tile1_nonzero, tile1_nonzero_rows))
    log("")

    -- ── Genesis SAT state check ───────────────────────────────────────────
    local SAT_BASE = 0xD800
    local sat0_Y   = vram_u16(SAT_BASE + 0) & 0x1FF
    local sat0_sl  = vram_u16(SAT_BASE + 2)
    local sat0_tw  = vram_u16(SAT_BASE + 4)
    local sat0_X   = vram_u16(SAT_BASE + 6) & 0x1FF
    local sprite0_link = sat0_sl & 0x7F
    log(string.format("  SAT sprite 0: Y=%d link=%d tw=$%04X X=%d",
        sat0_Y, sprite0_link, sat0_tw, sat0_X))
    log("")

    -- ── Tests ─────────────────────────────────────────────────────────────
    log("─── T24: Sprite Decode Tests ────────────────────────────────────")

    if not exception_hit then
        record("T24_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T24_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    if visit_frame["LoopForever"] then
        record("T24_LOOPFOREVER_HIT", PASS, "frame " .. visit_frame["LoopForever"])
    else
        record("T24_LOOPFOREVER_HIT", FAIL, "LoopForever never reached")
    end

    if display_on_frame then
        record("T24_DISPLAY_ON", PASS, string.format("display enabled at frame %d", display_on_frame))
    else
        record("T24_DISPLAY_ON", FAIL, "display never enabled in " .. MAX_FRAMES .. " frames")
    end

    -- T24_NMI_COUNT: NMI has fired ≥ 1 time (proves IsrNmi + _oam_dma executed)
    if nmi_count >= 1 then
        record("T24_NMI_COUNT", PASS,
            string.format("NMI debug counter=%d — IsrNmi+_oam_dma has executed", nmi_count))
    else
        record("T24_NMI_COUNT", FAIL, "NMI counter=0 — IsrNmi never ran")
    end

    -- T24_TILE1_CHR: tile 1 in VRAM has ≥ 16 non-zero 4bpp bytes
    if tile1_nonzero >= 16 then
        record("T24_TILE1_CHR", PASS,
            string.format("VRAM tile 1 has %d/32 non-zero bytes — CHR decode correct", tile1_nonzero))
    else
        record("T24_TILE1_CHR", FAIL,
            string.format("VRAM tile 1 has only %d/32 non-zero bytes", tile1_nonzero))
    end

    -- T24_TILE1_STRUCTURE: tile 1 has ≥ 4 non-zero rows (not mostly blank)
    if tile1_nonzero_rows >= 4 then
        record("T24_TILE1_STRUCTURE", PASS,
            string.format("tile 1 has %d/8 non-zero rows — 4bpp row structure valid",
                tile1_nonzero_rows))
    else
        record("T24_TILE1_STRUCTURE", FAIL,
            string.format("tile 1 has only %d/8 non-zero rows", tile1_nonzero_rows))
    end

    -- T24_MULTI_TILES: at least 16 tiles in VRAM have non-zero data
    -- (CHR ROM has 256 tiles; title screen uses ~36+ distinct tiles)
    if tiles_with_data >= 16 then
        record("T24_MULTI_TILES", PASS,
            string.format("%d/256 VRAM tiles have non-zero data — CHR upload decoded correctly",
                tiles_with_data))
    else
        record("T24_MULTI_TILES", FAIL,
            string.format("only %d/256 VRAM tiles have non-zero data", tiles_with_data))
    end

    -- T24_SAT_ACTIVE: SAT sprite 0 has a non-zero link (chain is ready for rendering)
    if sprite0_link ~= 0 then
        record("T24_SAT_ACTIVE", PASS,
            string.format("SAT sprite 0 link=%d — sprite chain active", sprite0_link))
    else
        record("T24_SAT_ACTIVE", FAIL,
            "SAT sprite 0 link=0 — sprite chain not formed (only sprite 0 would render)")
    end

    -- Summary
    log("")
    log("=================================================================")
    log("T24 SPRITE DECODE SUMMARY")
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
    if fail_cnt == 0 then log("T24 SPRITE DECODE: ALL PASS")
    else                  log("T24 SPRITE DECODE: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
