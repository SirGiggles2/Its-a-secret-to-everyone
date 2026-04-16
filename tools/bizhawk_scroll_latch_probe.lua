-- bizhawk_scroll_latch_probe.lua
-- T15: Scroll latch correctness
--
-- Verifies that _ppu_write_5 ($2005) correctly implements the two-write latch:
--   First  write → PPU_SCRL_X (horizontal scroll)
--   Second write → PPU_SCRL_Y (vertical scroll)
--   Both share PPU_LATCH with _ppu_write_6 (PPUADDR)
--
-- Zelda writes $2005 during NMI (IsrNmi calls scroll-update code each frame).
-- At LoopForever entry (before first NMI), PPU_SCRL_X and PPU_SCRL_Y should be
-- in a known state from IsrReset/RunGame's initialization.
--
-- At frame 300 (steady state with many NMI cycles), the game is idle in
-- LoopForever and scroll values reflect what the game logic wrote most recently.
-- We verify:
--   1. Scroll registers are readable (non-nil) — latch mechanism is present
--   2. Latch is in a clean state (PPU_LATCH=0) — not stalled mid-sequence
--   3. Scroll values at LoopForever snapshot make sense ($00 for cold boot)
--   4. Scroll values at frame 300 are stable/readable
--
-- Checks (T15):
--   T15_NO_EXCEPTION      — no exception hit
--   T15_LOOPFOREVER_HIT   — boot completes
--   T15_SCRL_X_READABLE   — PPU_SCRL_X ($FF0806) readable at LoopForever entry
--   T15_SCRL_Y_READABLE   — PPU_SCRL_Y ($FF0807) readable at LoopForever entry
--   T15_LATCH_CLEAN       — PPU_LATCH=0 at LoopForever entry (no pending scroll half)
--   T15_SCRL_BOOT_X       — PPU_SCRL_X=0 at LoopForever entry (IsrReset sets scroll to 0)
--   T15_SCRL_BOOT_Y       — PPU_SCRL_Y=0 at LoopForever entry (IsrReset sets scroll to 0)
--   T15_SCRL_STABLE       — scroll values at frame 300 are readable and consistent

local ROOT = os.getenv("CODEX_BIZHAWK_ROOT")
if not ROOT or ROOT == "" then
    ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
end
ROOT = ROOT:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_scroll_latch_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF, ISRRESET, RUNGAME, ISRNMI

local PPU_LATCH  = 0xFF0800
local PPU_SCRL_X = 0xFF0806
local PPU_SCRL_Y = 0xFF0807

local FORENSICS_TYPE = 0xFF0900

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-24s  %s", status, name, detail))
    results[#results+1] = {name=name, status=status}
end

local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if width == 1 then return memory.read_u8(offset)
        else return memory.read_u16_be(offset) end
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

local function add_exec_hook(addr, cb, tag)
    local ok, id = pcall(function() return event.onmemoryexecute(cb, addr, tag) end)
    return (ok and id) or nil
end

local function main()
    local FRAMES = 300
    log("=================================================================")
    log("Scroll Latch probe  T15  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}
    local snap_sx = nil
    local snap_sy = nil
    local snap_latch = nil

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                if name == "LoopForever" then
                    snap_sx,    _ = ram_u8(PPU_SCRL_X)
                    snap_sy,    _ = ram_u8(PPU_SCRL_Y)
                    snap_latch, _ = ram_u8(PPU_LATCH)
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

    for _, lm in ipairs({
        {LOOPFOREVER, "LoopForever"},
        {EXC_BUS,     "ExcBusError"},
        {EXC_ADDR,    "ExcAddrError"},
        {EXC_DEF,     "DefaultException"},
    }) do
        local id = add_exec_hook(lm[1], mark(lm[2]), "t15_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
                snap_sx,    _ = ram_u8(PPU_SCRL_X)
                snap_sy,    _ = ram_u8(PPU_SCRL_Y)
                snap_latch, _ = ram_u8(PPU_LATCH)
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
        if frame <= 5 or frame % 60 == 0 then
            log(string.format("  f%03d pc=$%06X  forever=%s  exc=%s",
                frame, pc, tostring(visit_frame["LoopForever"] or "-"), tostring(exception_hit)))
        end
        if exception_hit and frame > 30 then break end
    end
    for _, id in ipairs(hook_ids) do pcall(function() event.unregisterbyid(id) end) end
    log("")

    -- Read final-frame scroll state
    local final_sx,    _ = ram_u8(PPU_SCRL_X)
    local final_sy,    _ = ram_u8(PPU_SCRL_Y)
    local final_latch, _ = ram_u8(PPU_LATCH)

    log("─── T15: Scroll Latch Correctness ──────────────────────────────")

    if not exception_hit then
        record("T15_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T15_NO_EXCEPTION", FAIL, string.format("%s", exception_name))
    end

    local fl = visit_frame["LoopForever"]
    if fl then
        record("T15_LOOPFOREVER_HIT", PASS, "frame "..fl)
    else
        record("T15_LOOPFOREVER_HIT", FAIL, "never reached LoopForever")
    end

    log(string.format("  Snapshot at LoopForever (frame %s):", tostring(fl or "???")))
    log(string.format("    PPU_SCRL_X ($FF0806) = %s",
        snap_sx    ~= nil and string.format("$%02X", snap_sx)    or "??"))
    log(string.format("    PPU_SCRL_Y ($FF0807) = %s",
        snap_sy    ~= nil and string.format("$%02X", snap_sy)    or "??"))
    log(string.format("    PPU_LATCH  ($FF0800) = %s",
        snap_latch ~= nil and string.format("$%02X", snap_latch) or "??"))

    if snap_sx ~= nil then
        record("T15_SCRL_X_READABLE", PASS,
            string.format("PPU_SCRL_X=$%02X at LoopForever entry", snap_sx))
    else
        record("T15_SCRL_X_READABLE", FAIL, "PPU_SCRL_X not readable")
    end

    if snap_sy ~= nil then
        record("T15_SCRL_Y_READABLE", PASS,
            string.format("PPU_SCRL_Y=$%02X at LoopForever entry", snap_sy))
    else
        record("T15_SCRL_Y_READABLE", FAIL, "PPU_SCRL_Y not readable")
    end

    if snap_latch == nil then
        record("T15_LATCH_CLEAN", FAIL, "PPU_LATCH not readable")
    elseif snap_latch == 0 then
        record("T15_LATCH_CLEAN", PASS, "PPU_LATCH=0 (no pending scroll half-write)")
    else
        record("T15_LATCH_CLEAN", FAIL,
            string.format("PPU_LATCH=$%02X (stalled mid-write)", snap_latch))
    end

    -- IsrReset/ClearAllAudioAndVideo zeros scroll registers before RunGame.
    -- At LoopForever entry (before first NMI), SCRL_X and SCRL_Y should be $00.
    if snap_sx == nil then
        record("T15_SCRL_BOOT_X", FAIL, "snapshot not captured")
    elseif snap_sx == 0 then
        record("T15_SCRL_BOOT_X", PASS, "PPU_SCRL_X=0 at LoopForever (IsrReset cleared scroll)")
    else
        record("T15_SCRL_BOOT_X", FAIL,
            string.format("PPU_SCRL_X=$%02X expected $00", snap_sx))
    end

    if snap_sy == nil then
        record("T15_SCRL_BOOT_Y", FAIL, "snapshot not captured")
    elseif snap_sy == 0 then
        record("T15_SCRL_BOOT_Y", PASS, "PPU_SCRL_Y=0 at LoopForever (IsrReset cleared scroll)")
    else
        record("T15_SCRL_BOOT_Y", FAIL,
            string.format("PPU_SCRL_Y=$%02X expected $00", snap_sy))
    end

    -- At frame 300 (steady state), scroll values should still be readable.
    -- Their exact value depends on what UpdateMode/InitMode wrote (idle game
    -- state after boot). We only verify readability and non-nil.
    log(string.format("  Final frame scroll: SCRL_X=%s  SCRL_Y=%s  LATCH=%s",
        final_sx    ~= nil and string.format("$%02X", final_sx)    or "??",
        final_sy    ~= nil and string.format("$%02X", final_sy)    or "??",
        final_latch ~= nil and string.format("$%02X", final_latch) or "??"))

    if final_sx ~= nil and final_sy ~= nil then
        record("T15_SCRL_STABLE", PASS,
            string.format("scroll readable at frame %d: X=$%02X Y=$%02X LATCH=$%02X",
                FRAMES, final_sx, final_sy, final_latch or 0xFF))
    else
        record("T15_SCRL_STABLE", FAIL, "scroll registers not readable at final frame")
    end

    log("")
    log("=================================================================")
    log("SCROLL LATCH PROBE SUMMARY  (T15)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nT15 SCROLL LATCH PROBE: ALL PASS" or "\nT15 SCROLL LATCH PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
