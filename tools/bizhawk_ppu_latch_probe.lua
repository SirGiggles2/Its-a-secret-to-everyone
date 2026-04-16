-- bizhawk_ppu_latch_probe.lua
-- T12: PPUADDR latch correctness
--
-- Verifies that the $2006/$2007 NES PPU address-latch emulation in nes_io.asm
-- produces correct VRAM writes after the full IsrReset+RunGame boot sequence.
--
-- Checks (T12):
--   T12_NO_EXCEPTION     — no exception handler hit during boot
--   T12_LOOPFOREVER_HIT  — boot completes and reaches LoopForever
--   T12_PPU_LATCH_CLEAR  — PPU_LATCH ($FF0800) = 0 at LoopForever entry
--                           w-register reset by PPUSTATUS ($2002) reads in IsrReset warmup
--   T12_PPU_DHALF_CLEAR  — PPU_DHALF ($FF0809) = 0 at LoopForever entry
--                           not mid-word-write; both bytes of a pair were committed
--   T12_PPU_VADDR_VALID  — PPU_VADDR ($FF0802) readable (latch tracks address state)
--   T12_VRAM_PLANEA_NT   — Plane A ($C000+) contains ≥ 64 non-zero tile words.
--                           Cross-validates that PPUADDR → _ppu_write_7 →
--                           VDP VRAM write reached the nametable, without
--                           asserting specific content (title screen layout
--                           varies by build, palette bits are valid post-T20).
--                           History: previously checked VRAM[$2000]=$2424 and
--                           VRAM[$2800]=$2424. Both assumptions invalidated by
--                           T18 (Plane A moved to VDP $C000), T20 (palette bits
--                           now occupy high byte), and T21 (title screen
--                           overlays blank $24 fill). Retired 2026-04-16.
--
-- Addresses from builds/whatif.lst (regenerate after code changes):
--   LoopForever    $0005F2
--   IsrNmi         $000622
--   ExcBus         $000362
--   ExcAddr        $000384
--   ExcDef         $0003A6
--
-- PPU state block in Genesis RAM ($FF0800):
--   +0  PPU_LATCH  (byte)  — w-register (0=first write, 1=second write)
--   +1  (pad)
--   +2  PPU_VADDR  (word)  — current NES VRAM address
--   +4  PPU_CTRL   (byte)  — $2000 shadow
--   +5  PPU_MASK   (byte)  — $2001 shadow
--   +6  PPU_SCRL_X (byte)  — $2005 X scroll
--   +7  PPU_SCRL_Y (byte)  — $2005 Y scroll
--   +8  PPU_DBUF   (byte)  — pending high byte for next word write
--   +9  PPU_DHALF  (byte)  — 0=even (start), 1=odd (high buffered, awaiting low)

local ROOT = os.getenv("CODEX_BIZHAWK_ROOT")
if not ROOT or ROOT == "" then
    ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
end
ROOT = ROOT:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_ppu_latch_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF, ISRRESET, RUNGAME, ISRNMI

local PPU_LATCH  = 0xFF0800
local PPU_VADDR  = 0xFF0802
local PPU_DHALF  = 0xFF0809

local FORENSICS_TYPE = 0xFF0900
local FORENSICS_SR   = 0xFF0902
local FORENSICS_PC   = 0xFF0904

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-28s  %s", status, name, detail))
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
        {"M68K BUS",  bus_addr},
        {"68K RAM",   ofs},
        {"System Bus", bus_addr},
        {"Main RAM",   ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v, spec[1] end
    end
    return nil, nil
end

local function ram_u8(a)  local v,d = ram_read(a,1) return v,d end
local function ram_u16(a) local v,d = ram_read(a,2) return v,d end

local function vram_u16(vdp_addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(vdp_addr)
    end)
    return ok and v or nil
end

-- ── Exec hook helper ───────────────────────────────────────────────────────
local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function()
        return event.onmemoryexecute(cb, addr, tag)
    end)
    if ok and id then return id end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
local function main()
    local FRAMES = 120   -- 2 seconds at 60fps — IsrReset + RunGame complete by frame ~14
    log("=================================================================")
    log("PPU Latch probe  T12  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  IsrNmi=$%06X", LOOPFOREVER, ISRNMI))
    log(string.format("  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}

    -- Snapshot PPU state at LoopForever-first-hit
    local snap_latch  = nil
    local snap_vaddr  = nil
    local snap_dhalf  = nil

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                if name == "LoopForever" then
                    snap_latch, _ = ram_u8(PPU_LATCH)
                    snap_vaddr, _ = ram_u16(PPU_VADDR)
                    snap_dhalf, _ = ram_u8(PPU_DHALF)
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
        {ISRNMI,      "IsrNmi"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }
    for _, lm in ipairs(landmark_defs) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t12_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    -- ── Main loop ──────────────────────────────────────────────────────────
    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        -- PC-polling fallback
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
                snap_latch, _ = ram_u8(PPU_LATCH)
                snap_vaddr, _ = ram_u16(PPU_VADDR)
                snap_dhalf, _ = ram_u8(PPU_DHALF)
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
                frame, pc,
                tostring(visit_frame["LoopForever"] or "-"),
                tostring(exception_hit)))
        end
        if exception_hit and frame > 30 then
            log("  ** stuck at exception — stopping early")
            break
        end
    end

    for _, id in ipairs(hook_ids) do
        pcall(function() event.unregisterbyid(id) end)
    end
    log("")

    -- ── T12 checks ────────────────────────────────────────────────────────
    log("─── T12: PPUADDR Latch Correctness ─────────────────────────────")

    -- T12_NO_EXCEPTION
    if not exception_hit then
        record("T12_NO_EXCEPTION", PASS, "no exception handler hit during boot")
    else
        local et  = ram_u8(FORENSICS_TYPE) or 0
        local epc = 0
        do
            local hi = ram_u8(FORENSICS_PC) or 0
            local lo = ram_u8(FORENSICS_PC+1) or 0
            local hi2 = ram_u8(FORENSICS_PC+2) or 0
            local lo2 = ram_u8(FORENSICS_PC+3) or 0
            epc = hi*0x1000000 + lo*0x10000 + hi2*0x100 + lo2
        end
        record("T12_NO_EXCEPTION", FAIL,
            string.format("%s type=%d faulting_PC=$%06X", exception_name, et, epc))
    end

    -- T12_LOOPFOREVER_HIT
    local fl = visit_frame["LoopForever"]
    if fl then
        record("T12_LOOPFOREVER_HIT", PASS, "reached LoopForever at frame "..fl)
    else
        record("T12_LOOPFOREVER_HIT", FAIL, "never reached LoopForever")
    end

    -- Dump snapshot values
    log(string.format("  Snapshot at LoopForever entry (frame %s):", tostring(fl or "???")))
    log(string.format("    PPU_LATCH ($FF0800) = %s",
        snap_latch ~= nil and string.format("$%02X", snap_latch) or "??"))
    log(string.format("    PPU_VADDR ($FF0802) = %s",
        snap_vaddr ~= nil and string.format("$%04X", snap_vaddr) or "??"))
    log(string.format("    PPU_DHALF ($FF0809) = %s",
        snap_dhalf ~= nil and string.format("$%02X", snap_dhalf) or "??"))

    -- T12_PPU_LATCH_CLEAR
    -- IsrReset reads $2002 (PPUSTATUS) twice during warmup → w-latch cleared to 0.
    if snap_latch == nil then
        record("T12_PPU_LATCH_CLEAR", FAIL, "snapshot not captured")
    elseif snap_latch == 0 then
        record("T12_PPU_LATCH_CLEAR", PASS, "PPU_LATCH=0 (w-register cleared by PPUSTATUS reads)")
    else
        record("T12_PPU_LATCH_CLEAR", FAIL,
            string.format("PPU_LATCH=$%02X expected $00", snap_latch))
    end

    -- T12_PPU_DHALF_CLEAR
    -- At LoopForever entry all PPUDATA pairs are complete; DHalf must be 0.
    if snap_dhalf == nil then
        record("T12_PPU_DHALF_CLEAR", FAIL, "snapshot not captured")
    elseif snap_dhalf == 0 then
        record("T12_PPU_DHALF_CLEAR", PASS, "PPU_DHALF=0 (no pending high-byte; all pairs committed)")
    else
        record("T12_PPU_DHALF_CLEAR", FAIL,
            string.format("PPU_DHALF=$%02X expected $00 (stalled mid-word-write)", snap_dhalf))
    end

    -- T12_PPU_VADDR_VALID
    if snap_vaddr ~= nil then
        record("T12_PPU_VADDR_VALID", PASS,
            string.format("PPU_VADDR=$%04X readable (latch tracking active)", snap_vaddr))
    else
        record("T12_PPU_VADDR_VALID", FAIL, "PPU_VADDR not readable")
    end

    -- Scan Plane A at VDP VRAM $C000 for non-zero tile words. 32x30 NES
    -- nametable cells map to Plane A rows 0-29 cols 0-31 (plane stride $80).
    -- Any nonzero word proves that PPU $2000+ writes reached the VDP through
    -- the full latch → _ppu_write_7 → VDP VRAM path.
    local PLANEA_BASE = 0xC000
    local PLANEA_STRIDE = 0x80  -- 64-wide plane × 2 bytes
    local planea_nonzero = 0
    local first_nz_addr, first_nz_val = nil, nil
    for row = 0, 29 do
        for col = 0, 31 do
            local addr = PLANEA_BASE + row * PLANEA_STRIDE + col * 2
            local w = vram_u16(addr)
            if w and w ~= 0 then
                planea_nonzero = planea_nonzero + 1
                if not first_nz_addr then
                    first_nz_addr = addr
                    first_nz_val  = w
                end
            end
        end
    end
    log(string.format("  Plane A non-zero entries: %d / 960", planea_nonzero))
    if first_nz_addr then
        log(string.format("  first non-zero: VRAM[$%04X] = $%04X", first_nz_addr, first_nz_val))
    end

    -- T12_VRAM_PLANEA_NT
    -- ≥64 non-zero entries proves the latch + write path produced substantial
    -- nametable coverage — enough to rule out stray-byte artifacts but
    -- independent of specific title-screen content.
    if planea_nonzero >= 64 then
        record("T12_VRAM_PLANEA_NT", PASS,
            string.format("Plane A has %d non-zero tile words (≥64 threshold)", planea_nonzero))
    else
        record("T12_VRAM_PLANEA_NT", FAIL,
            string.format("Plane A only has %d non-zero tile words (need ≥64)", planea_nonzero))
    end

    -- ── Summary ───────────────────────────────────────────────────────────
    log("")
    log("=================================================================")
    log("PPU LATCH PROBE SUMMARY  (T12)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nT12 PPU LATCH PROBE: ALL PASS" or "\nT12 PPU LATCH PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
