-- bizhawk_nametable_probe.lua
-- T18: Nametable → Genesis Plane A
--
-- Verifies that _ppu_write_7 correctly routes PPU $2000-$23BF to
-- Genesis Plane A at VDP VRAM $2000, with proper col/row stride conversion.
--
-- Each NES nametable byte (tile index) should become a 16-bit Genesis
-- tile word at VDP VRAM $2000 + row*$80 + col*2, where:
--   row = (PPU_VADDR - $2000) >> 5    (0..29)
--   col = (PPU_VADDR - $2000) & 31   (0..31)
-- (64H × 32V plane; row stride = 64 tiles × 2 bytes = $80)
--
-- Probe checks (T18):
--   T18_NO_EXCEPTION         — no exception handler hit during boot
--   T18_LOOPFOREVER_HIT      — boot completed (LoopForever reached)
--   T18_NT_DATA_PRESENT      — Plane A ($C000+) has at least one non-zero word
--                              (nametable write path fired)
--   T18_NT_COVERAGE          — ≥ 64 distinct non-zero entries in Plane A
--                              (substantial nametable coverage, not a stray byte)
--   T18_PALETTE_BITS_PRESENT — ≥ 1 non-zero entry has palette bits (bits 14-13)
--                              set. Proves the T20 attribute-mapping path
--                              writes palette bits into the tile word. A pure
--                              T18 nametable-only build would leave palette=0.
--
-- History: the original T18_TILE_WORD_FORMAT check required high-byte=$00
-- on every entry. That was valid only before T20 landed; post-T20 the high
-- byte legitimately carries palette bits 14-13 (and 10-8 of the 11-bit tile
-- index). Retired 2026-04-16 after scanner fix revealed the probe was
-- flagging T20's CORRECT output as a regression.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_nametable_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF

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

local function vram_u8(addr)  return try_dom("VRAM", addr, 1) end
local function vram_u16(addr) return try_dom("VRAM", addr, 2) end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS", bus_addr}, {"68K RAM", ofs},
        {"System Bus", bus_addr}, {"Main RAM", ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v, spec[1] end
    end
    return nil, nil
end
local function ram_u8(a) local v = ram_read(a,1) return v end

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local FRAMES = 180
    log("=================================================================")
    log("Nametable probe  T18  —  " .. FRAMES .. " frames")
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
                if not exception_hit then
                    exception_hit = true
                    exception_name = name
                end
            end
        end
    end

    for _, lm in ipairs({
        {LOOPFOREVER, "LoopForever"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t18_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
            end
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

    -- Allow extra frames for nametable writes to complete
    log("  (waiting 30 extra frames for nametable writes to complete...)")
    for i = 1, 30 do emu.frameadvance() end
    log("")

    -- ── Post-wait diagnostics ─────────────────────────────────────────────
    local tcp_ran_flag = ram_u8(0xFF00F5)   -- $5A if TransferCommonPatterns ran
    log("─── Post-wait diagnostics ─────────────────────────────────────")
    log(string.format("  ($00F5): %s  ← $5A = TransferCommonPatterns ran",
        tcp_ran_flag ~= nil and string.format("$%02X", tcp_ran_flag) or "??"))

    -- Scan Plane A nametable area: VDP VRAM $2000-$23BF (960 words = 1920 bytes)
    -- Each entry is 2 bytes (tile word).
    -- The 960 entries map to the 32×30 NES nametable (32 cols × 30 rows).
    local NT_BASE = 0xC000
    local NT_ROWS = 30
    local NT_COLS = 32
    local NT_ROW_STRIDE = 0x80     -- 64-tile-wide plane, 2 bytes/tile
    local nonzero_count = 0
    local palette_bits_count = 0   -- entries where palette bits 14-13 are set
    local first_nz_addr = nil
    local first_nz_val  = nil

    log("─── Plane A nametable scan ($2000-$23BF in Genesis tile-word layout) ─")
    log(string.format("  (Plane A at $2000, 64H×32V plane, row stride=$%02X)", NT_ROW_STRIDE))
    log("")

    local dump_count = 0
    for row = 0, NT_ROWS-1 do
        for col = 0, NT_COLS-1 do
            local vdp_addr = NT_BASE + row * NT_ROW_STRIDE + col * 2
            local word = vram_u16(vdp_addr)
            if word and word ~= 0 then
                nonzero_count = nonzero_count + 1
                if first_nz_addr == nil then
                    first_nz_addr = vdp_addr
                    first_nz_val  = word
                end
                -- Palette bits are 14-13 of the tile word (mask $6000).
                if (word & 0x6000) ~= 0 then
                    palette_bits_count = palette_bits_count + 1
                end
                if dump_count < 12 then
                    log(string.format("    VRAM[$%04X] = $%04X  (row=%d col=%d tile=$%02X)",
                        vdp_addr, word, row, col, word & 0xFF))
                    dump_count = dump_count + 1
                end
            end
        end
    end
    if dump_count >= 12 then log("    ... (truncated)") end
    log("")
    log(string.format("  nonzero_count      = %d  (of 960 nametable entries)", nonzero_count))
    log(string.format("  palette_bits_count = %d  (entries with palette bits 14-13 set)", palette_bits_count))
    log("")

    -- Also dump raw VRAM $2000-$200F for spot check
    log("─── Raw VRAM spot check $2000-$200F ───────────────────────────")
    for i = 0, 15 do
        local v = vram_u8(NT_BASE + i)
        log(string.format("    VRAM[$%04X] = $%02X", NT_BASE + i, v or 0))
    end
    log("")

    -- ── Tests ─────────────────────────────────────────────────────────────
    log("─── T18: Nametable → Plane A ─────────────────────────────────────")

    -- T18_NO_EXCEPTION
    if not exception_hit then
        record("T18_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T18_NO_EXCEPTION", FAIL, "exception hit: " .. (exception_name or "unknown"))
    end

    -- T18_LOOPFOREVER_HIT
    if visit_frame["LoopForever"] then
        record("T18_LOOPFOREVER_HIT", PASS, "frame " .. visit_frame["LoopForever"])
    else
        record("T18_LOOPFOREVER_HIT", FAIL, "LoopForever never reached in " .. FRAMES .. " frames")
    end

    -- T18_NT_DATA_PRESENT
    if first_nz_addr ~= nil then
        record("T18_NT_DATA_PRESENT", PASS,
            string.format("VRAM[$%04X]=$%04X (first non-zero nametable word)", first_nz_addr, first_nz_val))
    else
        record("T18_NT_DATA_PRESENT", FAIL, "VRAM[$2000..$23BF] all zero — nametable writes never fired")
    end

    -- T18_NT_COVERAGE
    if nonzero_count >= 64 then
        record("T18_NT_COVERAGE", PASS,
            string.format("%d non-zero entries (≥64 threshold — substantial nametable coverage)", nonzero_count))
    else
        record("T18_NT_COVERAGE", FAIL,
            string.format("only %d non-zero entries (need ≥64 for coverage confidence)", nonzero_count))
    end

    -- T18_PALETTE_BITS_PRESENT
    -- Post-T20, the attribute-mapping path writes palette index into bits
    -- 14-13 of each tile word. A build with T20 live should have at least
    -- one entry with palette bits set.
    if palette_bits_count >= 1 then
        record("T18_PALETTE_BITS_PRESENT", PASS,
            string.format("%d entries carry palette bits (T20 attribute path is live)", palette_bits_count))
    elseif nonzero_count == 0 then
        record("T18_PALETTE_BITS_PRESENT", FAIL, "no nametable data to validate palette mapping")
    else
        record("T18_PALETTE_BITS_PRESENT", FAIL,
            string.format("all %d entries have palette=0 (T20 attribute path not reaching Plane A)", nonzero_count))
    end

    -- ── Summary ───────────────────────────────────────────────────────────
    log("")
    log("=================================================================")
    log("NAMETABLE PROBE SUMMARY  (T18)")
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
        log("T18 NAMETABLE PROBE: ALL PASS")
    else
        log("T18 NAMETABLE PROBE: " .. fail_cnt .. " FAILURE(S)")
    end
    log("")

    f:close()
    client.exit()
end

main()
