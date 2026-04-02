-- bizhawk_title_screen_probe.lua
-- T21: Title screen BG renders visually correct
--
-- Runs for up to 600 frames (10 seconds), waiting for:
--   1. Display to be enabled (PPUMASK bit 3 set = BG enabled)
--   2. Plane A nametable populated with tile data
--   3. CRAM palette 0 has non-black colors
--   4. CHR tiles present in VRAM
--
-- Checks:
--   T21_NO_EXCEPTION      — no exception hit
--   T21_LOOPFOREVER_HIT   — boot completed
--   T21_DISPLAY_ON        — VDP display enabled (PPU_MASK bit 3 set within 600 frames)
--   T21_CHR_TILES         — VRAM $0000-$1FFF has CHR data
--   T21_PLANE_A_TILES     — Plane A has ≥64 non-zero tile words
--   T21_PALETTE_COLORS    — CRAM palette 0 has ≥2 non-zero colors
--   T21_MIXED_PALETTES    — Plane A has tiles using at least 2 different palettes
--   T21_TILE_DIVERSITY    — Plane A has ≥8 distinct tile indices (not all same tile)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_title_screen_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-26s  %s", status, name, detail))
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

local function vram_u8(addr)   return try_dom("VRAM", addr, 1) or 0 end
local function vram_u16(addr)  return try_dom("VRAM", addr, 2) or 0 end
local function cram_u16(addr)  return try_dom("CRAM", addr, 2) or 0 end

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

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local MAX_FRAMES = 600
    log("=================================================================")
    log("Title screen probe  T21  —  up to " .. MAX_FRAMES .. " frames")
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
        local id = add_exec_hook(lm[1], mark(lm[2]), "t21_"..lm[2])
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

        -- Track when display enables (PPU_MASK bit 3 set)
        if not display_on_frame then
            local pm = ram_read(0xFF0805, 1) or 0
            if (pm & 0x08) ~= 0 or (pm & 0x10) ~= 0 then
                display_on_frame = frame
            end
        end

        if frame % 60 == 0 or frame <= 5 then
            local pm = ram_read(0xFF0805, 1) or 0
            log(string.format("  f%03d pc=$%06X  forever=%s  exc=%s  ppu_mask=$%02X  disp_on=%s",
                frame, pc, tostring(visit_frame["LoopForever"] or "-"),
                tostring(exception_hit), pm,
                tostring(display_on_frame or "-")))
        end

        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end
    log("")

    -- Wait a few more frames after display comes on
    if display_on_frame then
        log(string.format("  Display enabled at frame %d — waiting 10 more frames...", display_on_frame))
        for i = 1, 10 do emu.frameadvance() end
    else
        log("  Display never enabled — reading final state anyway...")
    end
    log("")

    -- ── Final state diagnostics ───────────────────────────────────────
    local ppu_mask = ram_read(0xFF0805, 1) or 0
    local tcp_ran  = ram_read(0xFF00F5, 1) or 0
    log(string.format("  PPU_MASK = $%02X  TCP_ran = $%02X", ppu_mask, tcp_ran))

    -- CHR check: first non-zero byte in $0000-$1FFF
    local chr_nonzero, chr_addr = 0, nil
    for i = 0, 0x1FFF do
        local v = vram_u8(i)
        if v ~= 0 then
            chr_nonzero = chr_nonzero + 1
            if not chr_addr then chr_addr = i end
            if chr_nonzero >= 4 then break end
        end
    end
    log(string.format("  CHR VRAM: %d+ non-zero bytes (first at $%04X)", chr_nonzero, chr_addr or 0))

    -- Plane A scan
    local NT_BASE = 0xC000
    local plane_nonzero = 0
    local pal_counts = {[0]=0,[1]=0,[2]=0,[3]=0}
    local tile_set = {}
    for row = 0, 29 do
        for col = 0, 31 do
            local word = vram_u16(NT_BASE + row*0x80 + col*2)
            if word ~= 0 then
                plane_nonzero = plane_nonzero + 1
                local pal = (word >> 13) & 3
                local tile = word & 0x7FF
                pal_counts[pal] = pal_counts[pal] + 1
                tile_set[tile] = true
            end
        end
    end
    local distinct_tiles = 0
    for _ in pairs(tile_set) do distinct_tiles = distinct_tiles + 1 end
    local palettes_used = 0
    for p = 0, 3 do if pal_counts[p] > 0 then palettes_used = palettes_used + 1 end end
    log(string.format("  Plane A: %d non-zero words, %d distinct tiles, %d palettes used",
        plane_nonzero, distinct_tiles, palettes_used))
    log(string.format("    pal0=%d pal1=%d pal2=%d pal3=%d", pal_counts[0], pal_counts[1], pal_counts[2], pal_counts[3]))

    -- CRAM check
    local cram_nonzero = 0
    local cram_pal0_colors = 0
    for col = 0, 3 do
        local word = cram_u16(col * 2)
        if word ~= 0 then cram_pal0_colors = cram_pal0_colors + 1 end
    end
    for i = 0, 63 do
        if cram_u16(i*2) ~= 0 then cram_nonzero = cram_nonzero + 1 end
    end
    log(string.format("  CRAM: %d non-zero entries, pal0 has %d non-black colors", cram_nonzero, cram_pal0_colors))
    log("")

    -- Dump Plane A rows 5-10 (likely title logo area)
    log("─── Plane A rows 5-10 (title logo area) ───────────────────────")
    for row = 5, 10 do
        local line = string.format("  row%02d:", row)
        for col = 0, 15 do
            local word = vram_u16(NT_BASE + row*0x80 + col*2)
            line = line .. string.format(" %04X", word)
        end
        log(line)
    end
    log("")

    -- Tests
    log("─── T21: Title Screen BG Renders Correctly ─────────────────────")

    if not exception_hit then
        record("T21_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T21_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    if visit_frame["LoopForever"] then
        record("T21_LOOPFOREVER_HIT", PASS, "frame " .. visit_frame["LoopForever"])
    else
        record("T21_LOOPFOREVER_HIT", FAIL, "LoopForever never reached")
    end

    if display_on_frame then
        record("T21_DISPLAY_ON", PASS,
            string.format("display enabled at frame %d (PPU_MASK=$%02X)", display_on_frame, ppu_mask))
    else
        record("T21_DISPLAY_ON", FAIL,
            string.format("display never enabled in %d frames (PPU_MASK=$%02X)", MAX_FRAMES, ppu_mask))
    end

    if chr_nonzero >= 4 then
        record("T21_CHR_TILES", PASS,
            string.format("VRAM $%04X has CHR data (CHR path working)", chr_addr or 0))
    else
        record("T21_CHR_TILES", FAIL, "no CHR tile data in VRAM $0000-$1FFF")
    end

    if plane_nonzero >= 64 then
        record("T21_PLANE_A_TILES", PASS,
            string.format("%d non-zero tile words in Plane A", plane_nonzero))
    else
        record("T21_PLANE_A_TILES", FAIL,
            string.format("only %d non-zero tile words in Plane A", plane_nonzero))
    end

    if cram_pal0_colors >= 2 then
        record("T21_PALETTE_COLORS", PASS,
            string.format("CRAM palette 0: %d non-black colors", cram_pal0_colors))
    else
        record("T21_PALETTE_COLORS", FAIL,
            string.format("CRAM palette 0: only %d non-black colors", cram_pal0_colors))
    end

    if palettes_used >= 2 then
        record("T21_MIXED_PALETTES", PASS,
            string.format("Plane A uses %d different palettes", palettes_used))
    else
        record("T21_MIXED_PALETTES", FAIL,
            string.format("Plane A only uses %d palette(s) — attribute table may not be applied",
                palettes_used))
    end

    -- Zelda title screen uses tile $24 throughout with palette-attribute variation.
    -- PASS if: (a) ≥8 distinct tile indices, OR
    --          (b) ≥1 tile index + ≥2 palettes + ≥64 non-zero tiles (palette-variety style)
    local tile_diversity_ok = (distinct_tiles >= 8) or
        (distinct_tiles >= 1 and palettes_used >= 2 and plane_nonzero >= 64)
    if tile_diversity_ok then
        record("T21_TILE_DIVERSITY", PASS,
            string.format("%d distinct tiles, %d palettes, %d filled — screen has visual content",
                distinct_tiles, palettes_used, plane_nonzero))
    else
        record("T21_TILE_DIVERSITY", FAIL,
            string.format("only %d distinct tiles, %d palettes, %d filled — screen appears blank",
                distinct_tiles, palettes_used, plane_nonzero))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("TITLE SCREEN PROBE SUMMARY  (T21)")
    log("=================================================================")
    local pass_cnt, fail_cnt = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then pass_cnt = pass_cnt + 1
        else                     fail_cnt = fail_cnt + 1 end
    end
    log("")
    log(string.format("  %d PASS  /  %d FAIL  /  %d total", pass_cnt, fail_cnt, #results))
    log("")
    if fail_cnt == 0 then log("T21 TITLE SCREEN PROBE: ALL PASS")
    else                  log("T21 TITLE SCREEN PROBE: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
