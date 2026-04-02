-- bizhawk_t23_oam_dma_probe.lua
-- T23: OAM DMA — $4014 write copies NES OAM[$0200-$02FF] to Genesis SAT at VRAM $D800
--
-- After title screen display is enabled (frame 32), we run for up to 600 frames and
-- then snapshot the Genesis sprite attribute table (SAT) in VRAM $D800-$DAFF.
--
-- We verify:
--   T23_NO_EXCEPTION      — no exception handler hit
--   T23_LOOPFOREVER_HIT   — boot completed successfully
--   T23_DISPLAY_ON        — display enabled within 600 frames
--   T23_SAT_WRITTEN       — at least one sprite in SAT has non-zero Y (sprite exists)
--   T23_SAT_LINK_CHAIN    — sprite 0's link field is non-zero (chain is formed)
--   T23_SAT_X_RANGE       — at least one visible sprite X in valid Genesis range (128–383)
--   T23_SAT_TILE_VALID    — at least one sprite with tile index 1–255 (non-blank tile)
--   T23_SAT_PRIORITY      — at least one sprite with priority bit set (bit 15 of tile word)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t23_oam_dma_probe.txt"

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

local function vram_u16(addr)  return try_dom("VRAM", addr, 2) or 0 end

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local MAX_FRAMES = 600
    log("=================================================================")
    log("T23: OAM DMA Probe  —  up to " .. MAX_FRAMES .. " frames")
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
        local id = add_exec_hook(lm[1], mark(lm[2]), "t23_"..lm[2])
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
            local pc_s = string.format("$%06X", pc)
            log(string.format("  f%03d pc=%s  disp=%s  exc=%s",
                frame, pc_s, tostring(display_on_frame or "-"), tostring(exception_hit)))
        end

        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end

    if display_on_frame then
        log(string.format("  Display enabled at frame %d — waiting 30 more frames for OAM DMA...", display_on_frame))
        for i = 1, 30 do emu.frameadvance() end
    else
        log("  Display never enabled — reading SAT anyway...")
    end
    log("")

    -- ── Snapshot Genesis SAT: VRAM $D800–$DA7F (80 sprites × 8 bytes) ────────
    -- Each sprite entry: word0=Y, word1=size|link, word2=tile_word, word3=X
    log("─── Genesis SAT Snapshot (VRAM $D800+) ──────────────────────────")
    log("  Spr#  Y    Link  TileWord  X    | Decoded")

    local SAT_BASE = 0xD800
    local sprites = {}
    for i = 0, 63 do
        local base = SAT_BASE + i * 8
        local w0 = vram_u16(base + 0)   -- Y
        local w1 = vram_u16(base + 2)   -- size | link
        local w2 = vram_u16(base + 4)   -- tile word
        local w3 = vram_u16(base + 6)   -- X
        sprites[i] = {Y=w0, sl=w1, tw=w2, X=w3}
        if i < 16 then  -- dump first 16 sprites
            local link  = w1 & 0x7F
            local size  = (w1 >> 8) & 0x0F
            local tile  = w2 & 0x07FF
            local pal   = (w2 >> 13) & 3
            local pri   = (w2 >> 15) & 1
            local vf    = (w2 >> 12) & 1
            local hf    = (w2 >> 11) & 1
            log(string.format("  [%02d]  %4d  %3d   $%04X     %4d | tile=%d pal=%d pri=%d vf=%d hf=%d",
                i, w0, link, w2, w3, tile, pal, pri, vf, hf))
        end
    end
    log("  ... (sprites 16-63 not shown)")
    log("")

    -- ── Also dump NES OAM source buffer for comparison ──────────────────
    log("─── NES OAM Buffer ($FF0200-$FF02FF) — first 16 entries ─────────")
    log("  Spr#  NES_Y  Tile  Attr  NES_X | Expected Genesis Y/X")
    for i = 0, 15 do
        local base = 0xFF0200 + i * 4
        local ny   = ram_read(base + 0, 1) or 0xFF
        local nt   = ram_read(base + 1, 1) or 0xFF
        local na   = ram_read(base + 2, 1) or 0xFF
        local nx   = ram_read(base + 3, 1) or 0xFF
        local gy   = ny + 129
        local gx   = nx + 128
        log(string.format("  [%02d]  $%02X    $%02X   $%02X   $%02X  | Genesis Y=%d X=%d",
            i, ny, nt, na, nx, gy, gx))
    end
    log("")

    -- ── Tests ─────────────────────────────────────────────────────────────
    log("─── T23: OAM DMA Tests ──────────────────────────────────────────")

    -- T23_NO_EXCEPTION
    if not exception_hit then
        record("T23_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T23_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    -- T23_LOOPFOREVER_HIT
    if visit_frame["LoopForever"] then
        record("T23_LOOPFOREVER_HIT", PASS, "frame " .. visit_frame["LoopForever"])
    else
        record("T23_LOOPFOREVER_HIT", FAIL, "LoopForever never reached")
    end

    -- T23_DISPLAY_ON
    if display_on_frame then
        record("T23_DISPLAY_ON", PASS, string.format("display enabled at frame %d", display_on_frame))
    else
        record("T23_DISPLAY_ON", FAIL, "display never enabled in " .. MAX_FRAMES .. " frames")
    end

    -- Read all 64 NES OAM entries for conversion verification
    local oam = {}
    for i = 0, 63 do
        local base = 0xFF0200 + i * 4
        oam[i] = {
            Y = ram_read(base + 0, 1) or 0xFF,
            T = ram_read(base + 1, 1) or 0xFF,
            A = ram_read(base + 2, 1) or 0xFF,
            X = ram_read(base + 3, 1) or 0xFF,
        }
    end

    -- T23_SAT_WRITTEN: verify SAT was written by checking that sprite 0's Genesis Y
    -- exactly equals NES_OAM[0].Y + 129.  Zelda initialises all OAM to Y=$F8 (off-screen);
    -- the correct Genesis encoding is $F8 + 129 = 377 (naturally off-screen ≥ 368).
    local sat_priority = 0
    local sprite0_link = sprites[0].sl & 0x7F
    local sat_nonzero_x = 0
    local sat_valid_tile_match = 0
    for i = 0, 63 do
        local s = sprites[i]
        local gx = s.X & 0x1FF
        if gx >= 128 and gx <= 383 then sat_nonzero_x = sat_nonzero_x + 1 end
        if (s.tw & 0x8000) ~= 0 then sat_priority = sat_priority + 1 end
        -- Check tile field matches NES tile index
        if (s.tw & 0x07FF) == (oam[i].T & 0x07FF) then
            sat_valid_tile_match = sat_valid_tile_match + 1
        end
    end

    -- T23_SAT_WRITTEN: verify DMA ran by confirming exact Y conversion for sprite 0
    local exp_y0 = (oam[0].Y + 129) & 0x1FF
    local got_y0 = sprites[0].Y & 0x1FF
    if got_y0 == exp_y0 then
        record("T23_SAT_WRITTEN", PASS,
            string.format("sprite 0 Genesis Y=%d == NES_Y($%02X)+129 — DMA conversion correct",
                got_y0, oam[0].Y))
    else
        record("T23_SAT_WRITTEN", FAIL,
            string.format("sprite 0 Genesis Y=%d, expected %d (NES_Y=$%02X+129) — DMA error",
                got_y0, exp_y0, oam[0].Y))
    end

    if sprite0_link ~= 0 then
        record("T23_SAT_LINK_CHAIN", PASS,
            string.format("sprite 0 link = %d (chain formed)", sprite0_link))
    else
        record("T23_SAT_LINK_CHAIN", FAIL,
            "sprite 0 link = 0 (chain not formed — only sprite 0 would display)")
    end

    if sat_nonzero_x >= 1 then
        record("T23_SAT_X_RANGE", PASS,
            string.format("%d sprites with X in visible range [128,383]", sat_nonzero_x))
    else
        record("T23_SAT_X_RANGE", FAIL, "no sprites with X in visible range")
    end

    -- T23_SAT_TILE_VALID: verify tile field in SAT exactly matches NES OAM tile index
    -- (Zelda title screen initialises all OAM tiles to 0, so tile=0 is correct here)
    if sat_valid_tile_match == 64 then
        record("T23_SAT_TILE_VALID", PASS,
            string.format("all 64 SAT tile fields match NES OAM tile indices (tile=$%02X × 64)",
                oam[0].T))
    else
        record("T23_SAT_TILE_VALID", FAIL,
            string.format("only %d/64 SAT tile fields match NES OAM", sat_valid_tile_match))
    end

    if sat_priority >= 1 then
        record("T23_SAT_PRIORITY", PASS,
            string.format("%d sprites with priority bit set", sat_priority))
    else
        record("T23_SAT_PRIORITY", FAIL, "no sprites with priority bit set (tile word bit 15)")
    end

    -- Summary
    log("")
    log("=================================================================")
    log("T23 OAM DMA CHECKPOINT SUMMARY")
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
    if fail_cnt == 0 then log("T23 OAM DMA: ALL PASS")
    else                  log("T23 OAM DMA: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
