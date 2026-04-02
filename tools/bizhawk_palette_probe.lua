-- bizhawk_palette_probe.lua
-- T19: NES palette writes ($3F00–$3F1F) → Genesis CRAM
--
-- Verifies that _ppu_write_7 correctly routes PPU $3F00–$3F1F to
-- Genesis CRAM via the nes_palette_to_genesis lookup table.
--
-- Checks:
--   T19_NO_EXCEPTION      — no exception handler hit
--   T19_LOOPFOREVER_HIT   — boot completed
--   T19_CRAM_WRITTEN      — at least one non-zero CRAM entry in $00–$7E
--   T19_CRAM_PALETTE0     — Genesis palette 0 ($00–$06) has non-trivial data
--                           (color 0 should be background color, colors 1-3 tile colors)
--   T19_BLACK_NOT_ALL     — not every CRAM entry is $0000 (at least one non-black color)
--   T19_COLOR_VALID       — all non-zero CRAM entries have value < $0800
--                           (valid $0BGR format: no garbage in upper 4 bits)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_palette_probe.txt"

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

-- Genesis CRAM is exposed as the "CRAM" domain in BizHawk GPGX
local function cram_u16(addr) return try_dom("CRAM", addr, 2) end

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
    local FRAMES = 180
    log("=================================================================")
    log("Palette probe  T19  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}

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
        local id = add_exec_hook(lm[1], mark(lm[2]), "t19_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
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
        if frame <= 5 or frame % 30 == 0 then
            log(string.format("  f%03d pc=$%06X  forever=%s  exc=%s",
                frame, pc, tostring(visit_frame["LoopForever"] or "-"),
                tostring(exception_hit)))
        end
        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end
    log("")

    log("  (waiting 30 extra frames for palette writes to complete...)")
    for i = 1, 30 do emu.frameadvance() end
    log("")

    -- Diagnostics
    local tcp_ran_flag = ram_read(0xFF00F5, 1)
    log("─── Post-wait diagnostics ─────────────────────────────────────")
    log(string.format("  ($00F5): %s  ← $5A = TransferCommonPatterns ran",
        tcp_ran_flag ~= nil and string.format("$%02X", tcp_ran_flag) or "??"))
    log("")

    -- Dump all 4 Genesis palettes from CRAM
    log("─── Genesis CRAM dump (4 palettes × 16 colors) ────────────────")
    local nonzero_count = 0
    local bad_format_count = 0
    for pal = 0, 3 do
        local line = string.format("  Pal %d:", pal)
        for col = 0, 15 do
            local cram_addr = pal * 32 + col * 2
            local word = cram_u16(cram_addr)
            word = word or 0
            line = line .. string.format(" $%04X", word)
            if word ~= 0 then
                nonzero_count = nonzero_count + 1
                if word >= 0x0800 then bad_format_count = bad_format_count + 1 end
            end
        end
        log(line)
    end
    log("")
    log(string.format("  nonzero_count     = %d  (of 64 CRAM entries)", nonzero_count))
    log(string.format("  bad_format_count  = %d  (entries ≥$0800, invalid $0BGR format)", bad_format_count))
    log("")

    -- Read Genesis palette 0, colors 0–3 explicitly
    local pal0_col0 = cram_u16(0x00) or 0
    local pal0_col1 = cram_u16(0x02) or 0
    local pal0_col2 = cram_u16(0x04) or 0
    local pal0_col3 = cram_u16(0x06) or 0
    log(string.format("  CRAM[0][0..3] = $%04X $%04X $%04X $%04X",
        pal0_col0, pal0_col1, pal0_col2, pal0_col3))
    log("")

    -- Tests
    log("─── T19: Palette → CRAM ─────────────────────────────────────────")

    if not exception_hit then
        record("T19_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T19_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    if visit_frame["LoopForever"] then
        record("T19_LOOPFOREVER_HIT", PASS, "frame " .. visit_frame["LoopForever"])
    else
        record("T19_LOOPFOREVER_HIT", FAIL, "LoopForever never reached")
    end

    if nonzero_count > 0 then
        record("T19_CRAM_WRITTEN", PASS,
            string.format("%d non-zero CRAM entries (palette data written)", nonzero_count))
    else
        record("T19_CRAM_WRITTEN", FAIL, "all 64 CRAM entries are $0000 — palette writes never fired")
    end

    -- Palette 0 non-trivial: at least one of colors 1-3 is non-zero
    local pal0_has_colors = (pal0_col1 ~= 0 or pal0_col2 ~= 0 or pal0_col3 ~= 0)
    if pal0_has_colors then
        record("T19_CRAM_PALETTE0", PASS,
            string.format("Pal0 colors 1-3: $%04X $%04X $%04X (non-trivial)",
                pal0_col1, pal0_col2, pal0_col3))
    else
        record("T19_CRAM_PALETTE0", FAIL,
            "CRAM palette 0 colors 1-3 all zero — NES palette 0 not written or all-black")
    end

    if nonzero_count > 0 then
        record("T19_BLACK_NOT_ALL", PASS, "at least one non-black color in CRAM")
    else
        record("T19_BLACK_NOT_ALL", FAIL, "all CRAM entries are $0000 (all black)")
    end

    if bad_format_count == 0 then
        record("T19_COLOR_VALID", PASS,
            "all CRAM entries are valid $0BGR format (no bits set above bit 11)")
    else
        record("T19_COLOR_VALID", FAIL,
            string.format("%d entries ≥ $0800 (invalid format — lookup table corruption?)",
                bad_format_count))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("PALETTE PROBE SUMMARY  (T19)")
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
    if fail_cnt == 0 then
        log("T19 PALETTE PROBE: ALL PASS")
    else
        log("T19 PALETTE PROBE: " .. fail_cnt .. " FAILURE(S)")
    end
    log("")

    f:close()
    client.exit()
end

main()
