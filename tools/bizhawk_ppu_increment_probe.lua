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
--   T13_NO_EXCEPTION     — no exception hit
--   T13_LOOPFOREVER_HIT  — boot completes
--   T13_PPUCTRL_INC_BIT  — PPU_CTRL bit 2 = 0 at LoopForever entry
--                           confirms horizontal (+1) mode was active for ClearNameTable
--   T13_VRAM_NT0_W0      — VRAM[$2000]=$2424  (word 0:  NES bytes $2000/$2001)
--   T13_VRAM_NT0_W1      — VRAM[$2002]=$2424  (word 1:  NES bytes $2002/$2003 — proves +1 increment)
--   T13_VRAM_NT0_W16     — VRAM[$2020]=$2424  (word 16: row 1 start — proves 32-step row wrap)
--   T13_VRAM_NT0_TILE479 — VRAM[$23BE]=$2424  (word 479: last tile word in NT0 tile area)
--   T13_VRAM_NT0_ATTR0   — VRAM[$23C0]=$2424  (ClearNameTable writes $24 uniformly — no tile/attr distinction)
--   T13_VRAM_NT2_W0      — VRAM[$2800]=$2424  (nametable 2 word 0 — cross-nametable increment)
--   T13_VRAM_NT2_W1      — VRAM[$2802]=$2424  (nametable 2 word 1 — increment continued across NT2)
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

    -- Read VRAM spot-checks
    local checks = {
        {0x2000, 0x2424, "T13_VRAM_NT0_W0",      "word 0  (NES $2000/$2001)  — baseline"},
        {0x2002, 0x2424, "T13_VRAM_NT0_W1",      "word 1  (NES $2002/$2003)  — +1 increment"},
        {0x2020, 0x2424, "T13_VRAM_NT0_W16",     "word 16 (NES $2040/$2041)  — row 1 start"},
        {0x23BE, 0x2424, "T13_VRAM_NT0_TILE479", "word 479 (NES $23BC/$23BD) — last tile row"},
        {0x23C0, 0x2424, "T13_VRAM_NT0_ATTR0",   "attr word 0 (NES $23C0/$23C1) — ClearNameTable writes $24 uniformly (no tile/attr distinction)"},
        {0x2800, 0x2424, "T13_VRAM_NT2_W0",      "NT2 word 0 (NES $2800/$2801) — NT2 first tile"},
        {0x2802, 0x2424, "T13_VRAM_NT2_W1",      "NT2 word 1 (NES $2802/$2803) — NT2 +1 increment"},
    }

    log("")
    log("  VRAM spot-checks (BizHawk VRAM domain, word-addressed):")
    for _, c in ipairs(checks) do
        local v = vram_u16(c[1])
        local vstr = v ~= nil and string.format("$%04X", v) or "????"
        log(string.format("    VRAM[$%04X] = %s  (expect $%04X)  %s", c[1], vstr, c[2], c[4]))
    end
    log("")

    for _, c in ipairs(checks) do
        local addr, expected, name, desc = c[1], c[2], c[3], c[4]
        local v = vram_u16(addr)
        if v == nil then
            record(name, FAIL, "VRAM domain unavailable")
        elseif v == expected then
            record(name, PASS, string.format("VRAM[$%04X]=$%04X  %s", addr, v, desc))
        else
            record(name, FAIL, string.format("VRAM[$%04X]=$%04X expected $%04X  %s", addr, v, expected, desc))
        end
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
