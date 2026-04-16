-- bizhawk_ppu_increment_probe.lua
-- T13: PPU increment mode
--
-- Verifies that _ppu_write_7's .inc_ppuaddr correctly advances PPU_VADDR by 1
-- (horizontal mode, PPUCTRL bit 2 = 0) after each PPUDATA write, causing
-- successive byte-pairs to land at consecutive VDP word addresses.
--
-- ClearNameTable (called from IsrReset via RunGame) writes tile $24 to all
-- 960 tile bytes of NES nametable 0 ($2000-$23BF) and $00 to 64 attribute
-- bytes ($23C0-$23FF), then repeats for nametable 2 ($2800-$2BFF).
-- If increment is wrong, tiles would pile up at address $2000 or skip rows.
--
-- Checks (T13):
--   T13_NO_EXCEPTION       — no exception hit
--   T13_LOOPFOREVER_HIT    — boot completes
--   T13_PPUCTRL_INC_BIT    — PPU_CTRL bit 2 = 0 at LoopForever entry
--                             confirms horizontal (+1) mode was active for ClearNameTable
--   T13_PLANEA_SEQ_RUN     — Plane A ($C000+) has a run of ≥ 20 consecutive
--                             non-zero tile words. If ClearNameTable's 960
--                             sequential +1-increment writes landed on
--                             consecutive Plane A cells, long runs naturally
--                             emerge. A missing/broken +1 would produce
--                             pile-up at one address or sparse scatter, not
--                             long contiguous runs.
--   T13_PLANEA_ROW_COVERAGE — ≥ 10 distinct Plane A rows have non-zero words.
--                             Cross-validates that row-stride wrap works
--                             (former T13_VRAM_NT0_W16 goal).
--
-- History: original probe asserted VRAM[$2000..$2802] = $2424 at seven
-- specific addresses. Those assumptions were invalidated by T18 (Plane A
-- moved to VDP $C000), T20 (palette bits now occupy high byte), and T21
-- (title screen overlays blank $24 fill). The specific-content checks are
-- replaced by invariant checks on the +1-increment semantics themselves.
-- Retired 2026-04-16.
--
-- Note on +32 (vertical) mode: .inc_ppuaddr checks PPUCTRL bit 2 and adds 32
-- when set.  Zelda does not use vertical mode during IsrReset/ClearNameTable.
-- Vertical mode will be exercised and verified in T16/T17 (CHR tile upload).

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_ppu_increment_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF, ISRRESET, RUNGAME, ISRNMI

local PPU_CTRL    = 0xFF0804   -- PPUCTRL shadow (nes_io.asm PPU_CTRL)

local FORENSICS_TYPE = 0xFF0900
local FORENSICS_PC   = 0xFF0904

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-26s  %s", status, name, detail))
    results[#results+1] = {name=name, status=status}
end

-- ── Memory helpers ─────────────────────────────────────────────────────────
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
        if v ~= nil then return v, spec[1] end
    end
    return nil, nil
end

local function ram_u8(a) local v,d = ram_read(a,1) return v,d end

local function vram_u16(vdp_addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(vdp_addr)
    end)
    return ok and v or nil
end

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

-- ═══════════════════════════════════════════════════════════════════════════
local function main()
    local FRAMES = 120
    log("=================================================================")
    log("PPU Increment probe  T13  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}
    local snap_ppu_ctrl = nil

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                if name == "LoopForever" then
                    snap_ppu_ctrl, _ = ram_u8(PPU_CTRL)
                end
            end
            if name == "ExcBusError" or name == "ExcAddrError" or name == "DefaultException" then
                if not exception_hit then
                    exception_hit = true
                    exception_name = name
                end
            end
        end
    end

    local landmark_defs = {
        {LOOPFOREVER, "LoopForever"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }
    for _, lm in ipairs(landmark_defs) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t13_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
                snap_ppu_ctrl, _ = ram_u8(PPU_CTRL)
            end
        end
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit = true
                exception_name = (pc==EXC_BUS and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
            end
        end
        if frame <= 5 or frame % 30 == 0 then
            log(string.format("  f%03d pc=$%06X  forever=%s  exc=%s",
                frame, pc, tostring(visit_frame["LoopForever"] or "-"), tostring(exception_hit)))
        end
        if exception_hit and frame > 30 then break end
    end

    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end
    log("")

    -- ── T13 checks ────────────────────────────────────────────────────────
    log("─── T13: PPU Increment Mode ─────────────────────────────────────")

    if not exception_hit then
        record("T13_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        local et = ram_u8(FORENSICS_TYPE) or 0
        record("T13_NO_EXCEPTION", FAIL,
            string.format("%s type=%d", exception_name, et))
    end

    local fl = visit_frame["LoopForever"]
    if fl then
        record("T13_LOOPFOREVER_HIT", PASS, "frame "..fl)
    else
        record("T13_LOOPFOREVER_HIT", FAIL, "never reached LoopForever")
    end

    -- Verify PPUCTRL bit 2 = 0 (horizontal/+1 mode) at LoopForever entry.
    -- ClearNameTable runs in this mode; PPU_CTRL=$B0, bit 2 = 0.
    log(string.format("  PPU_CTRL ($FF0804) at LoopForever = %s",
        snap_ppu_ctrl ~= nil and string.format("$%02X", snap_ppu_ctrl) or "??"))
    if snap_ppu_ctrl == nil then
        record("T13_PPUCTRL_INC_BIT", FAIL, "snapshot not captured")
    elseif (snap_ppu_ctrl & 0x04) == 0 then
        record("T13_PPUCTRL_INC_BIT", PASS,
            string.format("PPU_CTRL=$%02X bit2=0 (+1 horizontal increment was active)", snap_ppu_ctrl))
    else
        record("T13_PPUCTRL_INC_BIT", FAIL,
            string.format("PPU_CTRL=$%02X bit2=1 (unexpected +32 mode)", snap_ppu_ctrl))
    end

    -- Scan Plane A ($C000+) and measure:
    --   (1) longest run of consecutive non-zero tile words (SEQ_RUN)
    --   (2) number of distinct rows that contain at least one non-zero word
    -- A working +1 increment produces long contiguous runs because
    -- ClearNameTable writes 960 consecutive bytes and each +1 advance lands
    -- on the next Plane A cell. A broken increment would either pile up at
    -- one address (run = 1 elsewhere) or scatter sparsely.
    local PLANEA_BASE = 0xC000
    local PLANEA_STRIDE = 0x80  -- 64-wide plane × 2 bytes
    local longest_run = 0
    local current_run = 0
    local rows_with_nz = 0
    local total_nz = 0

    for row = 0, 29 do
        local row_has_nz = false
        for col = 0, 31 do
            local addr = PLANEA_BASE + row * PLANEA_STRIDE + col * 2
            local w = vram_u16(addr)
            if w and w ~= 0 then
                total_nz = total_nz + 1
                row_has_nz = true
                current_run = current_run + 1
                if current_run > longest_run then longest_run = current_run end
            else
                current_run = 0
            end
        end
        if row_has_nz then rows_with_nz = rows_with_nz + 1 end
    end

    log("")
    log(string.format("  Plane A scan: %d non-zero / 960 entries", total_nz))
    log(string.format("  Longest consecutive non-zero run: %d (≥20 → +1 increment proven)", longest_run))
    log(string.format("  Rows with any non-zero entry:     %d / 30 (≥10 → row stride works)", rows_with_nz))

    if longest_run >= 20 then
        record("T13_PLANEA_SEQ_RUN", PASS,
            string.format("longest run = %d (≥20 — +1 increment advances sequentially)", longest_run))
    else
        record("T13_PLANEA_SEQ_RUN", FAIL,
            string.format("longest run = %d (need ≥20 — +1 increment may be broken or pile-up)", longest_run))
    end

    if rows_with_nz >= 10 then
        record("T13_PLANEA_ROW_COVERAGE", PASS,
            string.format("%d / 30 rows have non-zero content (row-stride wrap works)", rows_with_nz))
    else
        record("T13_PLANEA_ROW_COVERAGE", FAIL,
            string.format("only %d / 30 rows have non-zero content (need ≥10)", rows_with_nz))
    end

    -- ── Summary ───────────────────────────────────────────────────────────
    log("")
    log("=================================================================")
    log("PPU INCREMENT PROBE SUMMARY  (T13)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nT13 PPU INCREMENT PROBE: ALL PASS" or "\nT13 PPU INCREMENT PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
