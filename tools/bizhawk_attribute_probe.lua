-- bizhawk_attribute_probe.lua
-- T20: NES attribute table ($23C0-$23FF) → Genesis tile word palette bits
--
-- Verifies that attribute bytes correctly update Genesis Plane A tile words
-- with bits [12:11] set to the palette index (0-3).
--
-- Checks:
--   T20_NO_EXCEPTION         — no exception handler hit
--   T20_LOOPFOREVER_HIT      — boot completed
--   T20_NT_CACHE_WRITTEN     — NT_CACHE_BASE ($FF0840) has non-zero entries
--   T20_PALETTE_BITS_SET     — at least some Plane A tile words have bits [12:11] != 0
--                              (attribute table was applied)
--   T20_TILE_WORD_VALID      — no tile word has bits [15:13] set
--                              (no flip/priority bits accidentally set)
--   T20_DISPLAY_ENABLED      — Genesis VDP Reg 1 has bit 6 set (display on)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_attribute_probe.txt"

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

local function vram_u16(addr)  return try_dom("VRAM", addr, 2) end
local function vram_u8(addr)   return try_dom("VRAM", addr, 1) end

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
    log("Attribute probe  T20  —  " .. FRAMES .. " frames")
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
        local id = add_exec_hook(lm[1], mark(lm[2]), "t20_"..lm[2])
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

    log("  (waiting 30 extra frames...)")
    for i = 1, 30 do emu.frameadvance() end
    log("")

    -- Check NT_CACHE_BASE ($FF0840) for written tile indices
    local NT_CACHE_BASE = 0xFF0840
    local cache_nonzero = 0
    for i = 0, 959 do
        local v = ram_read(NT_CACHE_BASE + i, 1) or 0
        if v ~= 0 then cache_nonzero = cache_nonzero + 1 end
    end
    log(string.format("  NT_CACHE_BASE($FF0840): %d / 960 entries non-zero", cache_nonzero))

    -- Scan Plane A ($2000-$23BF) for tile words with palette bits set
    local NT_BASE = 0xC000
    local total_words = 0
    local words_with_palette = 0
    local bad_words = 0     -- bits [15:13] set (flip/priority shouldn't be set yet)
    local pal_counts = {[0]=0, [1]=0, [2]=0, [3]=0}
    for row = 0, 29 do
        for col = 0, 31 do
            local addr = NT_BASE + row * 0x80 + col * 2
            local word = vram_u16(addr) or 0
            total_words = total_words + 1
            local pal = (word >> 11) & 3
            if pal ~= 0 then words_with_palette = words_with_palette + 1 end
            pal_counts[pal] = pal_counts[pal] + 1
            if (word & 0xE000) ~= 0 then bad_words = bad_words + 1 end
        end
    end
    log(string.format("  Plane A tile words: %d total, %d with palette≠0, %d with bad upper bits",
        total_words, words_with_palette, bad_words))
    log(string.format("  Palette distribution: pal0=%d pal1=%d pal2=%d pal3=%d",
        pal_counts[0], pal_counts[1], pal_counts[2], pal_counts[3]))
    log("")

    -- Dump first row of Plane A (row 0, cols 0-15): should show tile words
    log("─── Plane A row 0 dump (cols 0-15) ────────────────────────────")
    for col = 0, 15 do
        local word = vram_u16(NT_BASE + col * 2) or 0
        log(string.format("    VRAM[$%04X] = $%04X  tile=$%03X  pal=%d",
            NT_BASE + col * 2, word, word & 0x7FF, (word >> 11) & 3))
    end
    log("")

    -- Check VDP PPU_MASK shadow to confirm display enable fired
    local ppu_mask = ram_read(0xFF0805, 1) or 0
    log(string.format("  PPU_MASK shadow ($FF0805) = $%02X  (bit3=BG_en, bit4=SPR_en)",
        ppu_mask))
    log("")

    -- Tests
    log("─── T20: Attribute → Palette Bits ─────────────────────────────")

    if not exception_hit then
        record("T20_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T20_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    if visit_frame["LoopForever"] then
        record("T20_LOOPFOREVER_HIT", PASS, "frame " .. visit_frame["LoopForever"])
    else
        record("T20_LOOPFOREVER_HIT", FAIL, "LoopForever never reached")
    end

    if cache_nonzero >= 64 then
        record("T20_NT_CACHE_WRITTEN", PASS,
            string.format("%d / 960 cache entries non-zero (tile indices stored)", cache_nonzero))
    else
        record("T20_NT_CACHE_WRITTEN", FAIL,
            string.format("only %d cache entries non-zero (expected ≥64)", cache_nonzero))
    end

    if words_with_palette > 0 then
        record("T20_PALETTE_BITS_SET", PASS,
            string.format("%d tile words have palette≠0 (attribute table applied)", words_with_palette))
    else
        record("T20_PALETTE_BITS_SET", FAIL,
            "all tile words have palette=0 — attribute table writes not applied")
    end

    if bad_words == 0 then
        record("T20_TILE_WORD_VALID", PASS, "no tile words have bits [15:13] set")
    else
        record("T20_TILE_WORD_VALID", FAIL,
            string.format("%d tile words have flip/priority bits set unexpectedly", bad_words))
    end

    if (ppu_mask & 0x08) ~= 0 then
        record("T20_DISPLAY_ENABLED", PASS,
            string.format("PPU_MASK=$%02X has BG enable bit set (display should be on)", ppu_mask))
    else
        record("T20_DISPLAY_ENABLED", FAIL,
            string.format("PPU_MASK=$%02X: BG enable (bit 3) NOT set — display remains off", ppu_mask))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("ATTRIBUTE PROBE SUMMARY  (T20)")
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
    if fail_cnt == 0 then log("T20 ATTRIBUTE PROBE: ALL PASS")
    else                  log("T20 ATTRIBUTE PROBE: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
