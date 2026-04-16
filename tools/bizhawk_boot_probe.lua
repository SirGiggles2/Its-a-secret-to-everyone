-- bizhawk_boot_probe.lua
-- Boot validation suite — T7 / T8 / T9 / T10 / T11
--
-- T7  Reset trace sanity    — boot landmarks hit in correct order
-- T8  Frame/NMI cadence     — IsrNmi fires once per frame after LoopForever
-- T9  No hidden exceptions  — 300-frame soak produces no exception dump
-- T10 NES RAM map soundness — key boot-time RAM values are sane
-- T11 RAM snapshot parity   — pre-PPU init values match expected NES boot state
--
-- Addresses from builds/whatif.lst (regenerate after any code change):
--   IsrReset       $0034F2
--   RunGame        $0005CC
--   LoopForever    $0005F2
--   IsrNmi         $000622
--   ExcBusError    $000362
--   ExcAddrError   $000384
--   DefaultException $0003A6

-- Resolve ROOT via CODEX_BIZHAWK_ROOT env var (set by run batch files).
-- Prior hard-coded ROOT pointed at the main tree and silently read that
-- tree's whatif.lst, producing wrong landmark addresses when run from a
-- worktree.  Fall back to main tree only if env var is unset.
local ROOT = os.getenv("CODEX_BIZHAWK_ROOT")
if not ROOT or ROOT == "" then
    ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
end
ROOT = ROOT:gsub("/", "\\"):gsub("\\+$", "")

local OUT_DIR  = ROOT .. "\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_boot_probe.txt"

dofile(ROOT .. "\\tools\\probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF, ISRRESET, RUNGAME, ISRNMI

local FORENSICS_TYPE = 0xFF0900
local FORENSICS_SR   = 0xFF0902
local FORENSICS_PC   = 0xFF0904
local FORENSICS_D0   = 0xFF0908

-- T10/T11 watch addresses
local INIT_GAME_ADDR   = 0xFF00F4   -- NES $00F4 = InitializedGame (RunGame writes 0)
local CUR_PPUCTRL_ADDR = 0xFF00FF   -- NES $00FF = CurPpuControl_2000 (RunGame writes $A0)
local PPU_CTRL_SHADOW  = 0xFF0804   -- nes_io.asm PPU_CTRL shadow (written by _ppu_write_0)

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-30s  %s", status, name, detail))
    results[#results+1] = {name=name, status=status}
end

-- ── Memory helpers ────────────────────────────────────────────────────────
local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram_read(bus_addr, width)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        {"M68K BUS",  bus_addr},
        {"68K RAM",   ofs},
        {"System Bus",bus_addr},
        {"Main RAM",  ofs},
    }) do
        local v = try_dom(spec[1], spec[2], width or 1)
        if v ~= nil then return v, spec[1] end
    end
    return nil, nil
end

local function ram_u8(a)  local v,d = ram_read(a,1) return v,d end
local function ram_u16(a) local v,d = ram_read(a,2) return v,d end
local function ram_u32(a) local v,d = ram_read(a,4) return v,d end

-- ── Exec hook helper ──────────────────────────────────────────────────────
local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function()
        return event.onmemoryexecute(cb, addr, tag)
    end)
    if ok and id then return id end
    return nil
end

-- ═════════════════════════════════════════════════════════════════════════
local function main()
    local FRAMES = 300
    log("=================================================================")
    log("Boot probe  T7/T8/T9/T10/T11  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  IsrReset=$%06X  RunGame=$%06X  LoopForever=$%06X  IsrNmi=$%06X",
        ISRRESET, RUNGAME, LOOPFOREVER, ISRNMI))
    log(string.format("  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local nmi_per_frame = {}
    local cur_frame     = 0
    local hook_ids      = {}
    local hooks_ok      = true

    -- Snapshot of key NES RAM values taken the moment LoopForever is FIRST hit.
    -- IsrReset and RunGame have completed; IsrNmi has not yet run.
    -- This is the correct comparison point for T11 parity checks.
    local snap_initgame   = nil   -- $FF00F4 at LoopForever entry
    local snap_ppuctrl_ne = nil   -- $FF00FF at LoopForever entry  (NES RAM mirror)
    local snap_ppuctrl_sh = nil   -- $FF0804 at LoopForever entry  (nes_io.asm shadow)

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                -- Capture RAM snapshot the instant LoopForever first executes.
                if name == "LoopForever" then
                    snap_initgame,   _ = ram_u8(INIT_GAME_ADDR)
                    snap_ppuctrl_ne, _ = ram_u8(CUR_PPUCTRL_ADDR)
                    snap_ppuctrl_sh, _ = ram_u8(PPU_CTRL_SHADOW)
                end
            end
            if name == "IsrNmi" then
                nmi_per_frame[cur_frame] = (nmi_per_frame[cur_frame] or 0) + 1
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
        {ISRRESET,    "IsrReset"},
        {RUNGAME,     "RunGame"},
        {LOOPFOREVER, "LoopForever"},
        {ISRNMI,      "IsrNmi"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }
    for _, lm in ipairs(landmark_defs) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "boot_"..lm[2])
        if id then
            hook_ids[#hook_ids+1] = id
        else
            hooks_ok = false
            log("  [warn] exec hook unavailable for "..lm[2].." — using PC polling fallback")
        end
    end

    -- ── Main loop ─────────────────────────────────────────────────────────
    local pc_last = 0
    local pc_prev = -1
    local stuck   = 0

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()

        local pc = emu.getregister("M68K PC") or 0
        pc_last = pc

        -- PC-polling fallbacks (covers hook-unavailable case)
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            visit_frame["LoopForever"] = visit_frame["LoopForever"] or frame
        end
        if pc == ISRNMI then
            visit_frame["IsrNmi"] = visit_frame["IsrNmi"] or frame
            nmi_per_frame[frame]  = (nmi_per_frame[frame] or 0) + 1
        end
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit = true
                exception_name = (pc==EXC_BUS and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
            end
        end

        if pc == pc_prev then stuck = stuck+1 else stuck = 0 end
        pc_prev = pc

        if frame <= 5 or frame % 60 == 0 then
            log(string.format("  f%03d pc=$%06X  reset=%s game=%s forever=%s nmi=%s exc=%s",
                frame, pc,
                tostring(visit_frame["IsrReset"]    or "-"),
                tostring(visit_frame["RunGame"]     or "-"),
                tostring(visit_frame["LoopForever"] or "-"),
                tostring(visit_frame["IsrNmi"]      or "-"),
                tostring(exception_hit)))
        end

        if exception_hit and stuck >= 20 then
            log(string.format("  ** stuck at exception for %d frames — stopping early at f%d", stuck, frame))
            break
        end
    end

    for _, id in ipairs(hook_ids) do
        pcall(function() event.unregisterbyid(id) end)
    end
    log("")

    -- ═══════════════════════════════════════════════════════════════════
    -- T7 — Reset trace sanity
    -- ═══════════════════════════════════════════════════════════════════
    log("─── T7: Reset Trace Sanity ─────────────────────────────────────")

    local fr = visit_frame["IsrReset"]
    local fg = visit_frame["RunGame"]
    local fl = visit_frame["LoopForever"]
    local fn = visit_frame["IsrNmi"]

    if fr then record("T7_ISRRESET_HIT",    PASS, "frame "..fr)
    else       record("T7_ISRRESET_HIT",    FAIL, string.format("IsrReset ($%06X) never hit",ISRRESET)) end

    if fg then record("T7_RUNGAME_HIT",     PASS, "frame "..fg)
    else       record("T7_RUNGAME_HIT",     FAIL, string.format("RunGame ($%06X) never hit",RUNGAME)) end

    if fl then record("T7_LOOPFOREVER_HIT", PASS, "frame "..fl)
    else       record("T7_LOOPFOREVER_HIT", FAIL, "LoopForever never hit") end

    if fn then record("T7_ISRNMI_HIT",      PASS, "frame "..fn)
    else       record("T7_ISRNMI_HIT",      FAIL, string.format("IsrNmi ($%06X) never hit",ISRNMI)) end

    if fr and fg and fl and fn then
        if fr <= fg and fg <= fl and fl <= fn then
            record("T7_ORDER", PASS,
                string.format("Reset(f%d)≤Game(f%d)≤Forever(f%d)≤Nmi(f%d)", fr,fg,fl,fn))
        else
            record("T7_ORDER", FAIL,
                string.format("Bad order: Reset(f%d) Game(f%d) Forever(f%d) Nmi(f%d)", fr,fg,fl,fn))
        end
    else
        record("T7_ORDER", FAIL, "cannot verify — some landmarks missing")
    end

    if not exception_hit then
        record("T7_NO_EXCEPTION", PASS, "no exception handler executed")
    else
        local et  = ram_u8(FORENSICS_TYPE)  or 0
        local epc = ram_u32(FORENSICS_PC)   or 0
        local esr = ram_u16(FORENSICS_SR)   or 0
        record("T7_NO_EXCEPTION", FAIL,
            string.format("%s type=%d SR=$%04X faulting_PC=$%06X", exception_name, et, esr, epc))
    end

    log("")

    -- ═══════════════════════════════════════════════════════════════════
    -- T8 — Frame/NMI cadence
    -- ═══════════════════════════════════════════════════════════════════
    log("─── T8: Frame / NMI Cadence ────────────────────────────────────")

    if not fn then
        record("T8_NMI_CADENCE",   FAIL, "IsrNmi never hit")
        record("T8_NMI_NO_DOUBLE", FAIL, "IsrNmi never hit")
    else
        local eligible  = FRAMES - fn
        if eligible < 1 then eligible = 1 end
        local with_nmi  = 0
        local multi_nmi = 0
        for frm = fn, FRAMES do
            local c = nmi_per_frame[frm] or 0
            if c >= 1 then with_nmi  = with_nmi  + 1 end
            if c >= 2 then multi_nmi = multi_nmi + 1 end
        end
        local rate = with_nmi / eligible
        log(string.format("  first_nmi=f%d  eligible=%d  with_nmi=%d  multi_nmi=%d  rate=%.1f%%",
            fn, eligible, with_nmi, multi_nmi, rate*100))

        if rate >= 0.95 then
            record("T8_NMI_CADENCE", PASS,
                string.format("IsrNmi in %d/%d frames (%.1f%%)", with_nmi, eligible, rate*100))
        else
            record("T8_NMI_CADENCE", FAIL,
                string.format("%.1f%% < 95%% (%d/%d)", rate*100, with_nmi, eligible))
        end

        if multi_nmi == 0 then
            record("T8_NMI_NO_DOUBLE", PASS, "no frame had >1 IsrNmi call")
        else
            record("T8_NMI_NO_DOUBLE", FAIL, multi_nmi.." frames had multiple IsrNmi calls")
        end
    end

    log("")

    -- ═══════════════════════════════════════════════════════════════════
    -- T9 — No hidden exceptions (300-frame soak)
    -- ═══════════════════════════════════════════════════════════════════
    log("─── T9: No Hidden Exceptions (300-frame soak) ──────────────────")

    if not exception_hit then
        record("T9_NO_EXCEPTION", PASS, "300 frames clean")
    else
        local et  = ram_u8(FORENSICS_TYPE)  or 0
        local epc = ram_u32(FORENSICS_PC)   or 0
        local esr = ram_u16(FORENSICS_SR)   or 0
        record("T9_NO_EXCEPTION", FAIL,
            string.format("%s type=%d SR=$%04X faulting_PC=$%06X", exception_name, et, esr, epc))
        for i = 0, 7 do
            local v = ram_u32(FORENSICS_D0 + i*4) or 0
            log(string.format("    D%d=$%08X", i, v))
        end
    end

    log("")

    -- ═══════════════════════════════════════════════════════════════════
    -- T10 — NES RAM map soundness
    -- ═══════════════════════════════════════════════════════════════════
    log("─── T10: NES RAM Map Soundness ─────────────────────────────────")

    local init_game,   dom_ig = ram_u8(INIT_GAME_ADDR)
    local cur_ppuctrl, dom_pp = ram_u8(CUR_PPUCTRL_ADDR)
    local ppu_ctrl,    dom_pc = ram_u8(PPU_CTRL_SHADOW)

    log(string.format("  $FF00F4 InitializedGame  = %s  (domain=%s)",
        init_game   ~= nil and string.format("$%02X",init_game)   or "??", tostring(dom_ig)))
    log(string.format("  $FF00FF CurPpuControl    = %s  (domain=%s)",
        cur_ppuctrl ~= nil and string.format("$%02X",cur_ppuctrl) or "??", tostring(dom_pp)))
    log(string.format("  $FF0804 PPU_CTRL shadow  = %s  (domain=%s)",
        ppu_ctrl    ~= nil and string.format("$%02X",ppu_ctrl)    or "??", tostring(dom_pc)))

    if init_game ~= nil then
        record("T10_RAM_READABLE", PASS, string.format("NES RAM accessible ($FF00F4=$%02X)", init_game))
    else
        record("T10_RAM_READABLE", FAIL, "Cannot read $FF00F4 from any domain")
    end

    -- At frame 300, IsrNmi has modified PPUCTRL many times.
    -- Mid-NMI, bit 7 may be clear (IsrNmi clears it at entry, sets at exit).
    -- Accept any non-zero value; T11 validates the exact boot-time value.
    if cur_ppuctrl == nil then
        record("T10_PPUCTRL_SET", FAIL, "Cannot read $FF00FF")
    elseif cur_ppuctrl ~= 0 then
        record("T10_PPUCTRL_SET", PASS,
            string.format("$FF00FF=$%02X (PPU_CTRL active, non-zero)", cur_ppuctrl))
    else
        record("T10_PPUCTRL_SET", FAIL,
            string.format("$FF00FF=$%02X -- PPU_CTRL is zero (never initialized)", cur_ppuctrl))
    end

    if ppu_ctrl == nil then
        record("T10_PPU_STATE", FAIL, "Cannot read $FF0804 (PPU_CTRL shadow)")
    elseif ppu_ctrl ~= 0 then
        record("T10_PPU_STATE", PASS,
            string.format("$FF0804=$%02X (PPU_CTRL shadow non-zero)", ppu_ctrl))
    else
        record("T10_PPU_STATE", FAIL, "$FF0804=$00 — PPU_CTRL shadow never written?")
    end

    log("")

    -- ═══════════════════════════════════════════════════════════════════
    -- T11 — RAM snapshot parity (pre-PPU init scope)
    -- ═══════════════════════════════════════════════════════════════════
    log("─── T11: RAM Snapshot Parity (pre-PPU scope) ───────────────────")
    log("  Snapshot taken at LoopForever-entry (RunGame done, IsrNmi not yet run).")
    log(string.format("  snap_initgame=$%s  snap_ppuctrl_ne=$%s  snap_ppuctrl_sh=$%s",
        snap_initgame   ~= nil and string.format("%02X",snap_initgame)   or "??",
        snap_ppuctrl_ne ~= nil and string.format("%02X",snap_ppuctrl_ne) or "??",
        snap_ppuctrl_sh ~= nil and string.format("%02X",snap_ppuctrl_sh) or "??"))

    -- InitializedGame ($00F4) must be 0 at LoopForever entry.
    -- RunGame: moveq #0,D0; move.b D0,($F4,A4). No cross-bank call changes it yet.
    if snap_initgame == nil then
        record("T11_INIT_GAME", FAIL, "snapshot not captured (LoopForever hook may have missed)")
    elseif snap_initgame == 0 then
        record("T11_INIT_GAME", PASS, "snap $FF00F4=0 matches NES (RunGame clears InitializedGame)")
    else
        record("T11_INIT_GAME", FAIL,
            string.format("snap $FF00F4=$%02X expected $00", snap_initgame))
    end

    -- CurPpuControl_2000 ($00FF) must be $B0 at LoopForever entry.
    -- ClearAllAudioAndVideo (called from RunGame, defined in z_07) reads $00FF,
    -- sets bit 4 (BG pattern table = $1000), writes back.  RunGame then reads
    -- that value and ORs $A0, producing $B0 ($10 | $A0 = $B0).
    -- This matches real NES behaviour — the expected value is $B0, not $A0.
    if snap_ppuctrl_ne == nil then
        record("T11_PPUCTRL_PARITY", FAIL, "snapshot not captured (LoopForever hook may have missed)")
    elseif snap_ppuctrl_ne == 0xB0 then
        record("T11_PPUCTRL_PARITY", PASS, "snap $FF00FF=$B0 matches NES boot value (ClearAllAudioAndVideo+RunGame)")
    else
        record("T11_PPUCTRL_PARITY", FAIL,
            string.format("snap $FF00FF=$%02X expected $B0", snap_ppuctrl_ne))
    end

    -- D7 = NES SP shadow: genesis_shell sets D7=$FF, IsrReset does TXS → D7=$FF unchanged
    local d7 = emu.getregister("M68K D7")
    if d7 ~= nil then
        local b = d7 & 0xFF
        if b == 0xFF then
            record("T11_SP_SHADOW", PASS, "D7 low byte=$FF (NES SP=$FF, TXS in IsrReset)")
        else
            record("T11_SP_SHADOW", FAIL, string.format("D7=$%08X low byte=$%02X expected $FF", d7, b))
        end
    else
        record("T11_SP_SHADOW", FAIL, "Cannot read M68K D7 register")
    end

    log("")

    -- ═══════════════════════════════════════════════════════════════════
    -- Summary
    -- ═══════════════════════════════════════════════════════════════════
    log("=================================================================")
    log("BOOT PROBE SUMMARY  (T7 / T8 / T9 / T10 / T11)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nBOOT PROBE: ALL PASS" or "\nBOOT PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
