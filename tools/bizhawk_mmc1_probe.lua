-- bizhawk_mmc1_probe.lua
-- T11b: MMC1 shift-register state tracking
--
-- Verifies that _mmc1_write_8000/_a000/_c000/_e000 correctly implement the
-- MMC1 5-write shift-register protocol and store results in Genesis RAM.
--
-- Zelda boot sequence writes:
--   IsrReset → SetMMC1Control($0F):  5 writes to $8000 → MMC1_CTRL = $0F
--   RunGame  → SwitchBank(5):        5 writes to $E000 → MMC1_PRG  = $05
--   CHR banks ($A000/$C000) not written before LoopForever → stay $00
--
-- MMC1 state RAM layout ($FF0810–$FF0815):
--   $FF0810: MMC1_SHIFT  (shift accumulator, must be 0 at rest)
--   $FF0811: MMC1_COUNT  (bits accumulated, must be 0 at rest)
--   $FF0812: MMC1_CTRL   (control register,  expected $0F after IsrReset)
--   $FF0813: MMC1_CHR0   (CHR bank 0,        expected $00 — not written at boot)
--   $FF0814: MMC1_CHR1   (CHR bank 1,        expected $00 — not written at boot)
--   $FF0815: MMC1_PRG    (PRG bank,           expected $05 after SwitchBank(5))
--
-- Checks (T11b):
--   T11b_NO_EXCEPTION    — no exception hit
--   T11b_LOOPFOREVER_HIT — boot completes to LoopForever
--   T11b_SHIFT_CLEAR     — MMC1_SHIFT = $00 (accumulator reset after last write)
--   T11b_COUNT_CLEAR     — MMC1_COUNT = $00 (count reset after last write)
--   T11b_CTRL_VALUE      — MMC1_CTRL  = $0F (SetMMC1Control($0F) applied)
--   T11b_CHR0_ZERO       — MMC1_CHR0  = $00 (no CHR bank write before LoopForever)
--   T11b_CHR1_ZERO       — MMC1_CHR1  = $00 (no CHR bank write before LoopForever)
--   T11b_PRG_VALUE       — MMC1_PRG   = $05 (SwitchBank(5) applied)

local ROOT = os.getenv("CODEX_BIZHAWK_ROOT")
if not ROOT or ROOT == "" then
    ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
end
ROOT = ROOT:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_mmc1_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")  -- sets LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF, ISRRESET, RUNGAME, ISRNMI

local MMC1_SHIFT = 0xFF0810
local MMC1_COUNT = 0xFF0811
local MMC1_CTRL  = 0xFF0812
local MMC1_CHR0  = 0xFF0813
local MMC1_CHR1  = 0xFF0814
local MMC1_PRG   = 0xFF0815

local FORENSICS_TYPE = 0xFF0900

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
    local FRAMES = 120
    log("=================================================================")
    log("MMC1 State probe  T11b  —  " .. FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    local visit_frame   = {}
    local exception_hit = false
    local exception_name= nil
    local cur_frame     = 0
    local hook_ids      = {}

    -- Snapshots at LoopForever
    local snap = {}

    local function mark(name)
        return function()
            if not visit_frame[name] then
                visit_frame[name] = cur_frame
                if name == "LoopForever" then
                    snap.shift, _ = ram_u8(MMC1_SHIFT)
                    snap.count, _ = ram_u8(MMC1_COUNT)
                    snap.ctrl,  _ = ram_u8(MMC1_CTRL)
                    snap.chr0,  _ = ram_u8(MMC1_CHR0)
                    snap.chr1,  _ = ram_u8(MMC1_CHR1)
                    snap.prg,   _ = ram_u8(MMC1_PRG)
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
        local id = add_exec_hook(lm[1], mark(lm[2]), "t11b_"..lm[2])
        if id then hook_ids[#hook_ids+1] = id end
    end

    for frame = 1, FRAMES do
        cur_frame = frame
        emu.frameadvance()
        local pc = emu.getregister("M68K PC") or 0
        if pc >= LOOPFOREVER and pc <= LOOPFOREVER+3 then
            if not visit_frame["LoopForever"] then
                visit_frame["LoopForever"] = frame
                snap.shift, _ = ram_u8(MMC1_SHIFT)
                snap.count, _ = ram_u8(MMC1_COUNT)
                snap.ctrl,  _ = ram_u8(MMC1_CTRL)
                snap.chr0,  _ = ram_u8(MMC1_CHR0)
                snap.chr1,  _ = ram_u8(MMC1_CHR1)
                snap.prg,   _ = ram_u8(MMC1_PRG)
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

    log("─── T11b: MMC1 Shift-Register State ────────────────────────────")

    if not exception_hit then
        record("T11b_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        local et = ram_u8(FORENSICS_TYPE) or 0
        record("T11b_NO_EXCEPTION", FAIL, string.format("%s type=%d", exception_name, et))
    end

    local fl = visit_frame["LoopForever"]
    if fl then
        record("T11b_LOOPFOREVER_HIT", PASS, "frame "..fl)
    else
        record("T11b_LOOPFOREVER_HIT", FAIL, "never reached LoopForever")
    end

    log(string.format("  Snapshot at LoopForever (frame %s):", tostring(fl or "???")))
    log(string.format("    MMC1_SHIFT ($FF0810) = %s", snap.shift ~= nil and string.format("$%02X", snap.shift) or "??"))
    log(string.format("    MMC1_COUNT ($FF0811) = %s", snap.count ~= nil and string.format("$%02X", snap.count) or "??"))
    log(string.format("    MMC1_CTRL  ($FF0812) = %s", snap.ctrl  ~= nil and string.format("$%02X", snap.ctrl)  or "??"))
    log(string.format("    MMC1_CHR0  ($FF0813) = %s", snap.chr0  ~= nil and string.format("$%02X", snap.chr0)  or "??"))
    log(string.format("    MMC1_CHR1  ($FF0814) = %s", snap.chr1  ~= nil and string.format("$%02X", snap.chr1)  or "??"))
    log(string.format("    MMC1_PRG   ($FF0815) = %s", snap.prg   ~= nil and string.format("$%02X", snap.prg)   or "??"))

    -- T11b_SHIFT_CLEAR — accumulator must be reset after every completed 5-write sequence
    if snap.shift == nil then
        record("T11b_SHIFT_CLEAR", FAIL, "snapshot not captured")
    elseif snap.shift == 0 then
        record("T11b_SHIFT_CLEAR", PASS, "MMC1_SHIFT=$00 (accumulator clean)")
    else
        record("T11b_SHIFT_CLEAR", FAIL, string.format("MMC1_SHIFT=$%02X expected $00", snap.shift))
    end

    -- T11b_COUNT_CLEAR — count must be 0 when no write sequence is in progress
    if snap.count == nil then
        record("T11b_COUNT_CLEAR", FAIL, "snapshot not captured")
    elseif snap.count == 0 then
        record("T11b_COUNT_CLEAR", PASS, "MMC1_COUNT=$00 (count reset)")
    else
        record("T11b_COUNT_CLEAR", FAIL, string.format("MMC1_COUNT=$%02X expected $00", snap.count))
    end

    -- T11b_CTRL_VALUE — IsrReset → SetMMC1Control($0F) → 5 writes to $8000
    -- $0F = 0b00001111: H mirroring, fix-last PRG mode, 8KB CHR mode
    if snap.ctrl == nil then
        record("T11b_CTRL_VALUE", FAIL, "snapshot not captured")
    elseif snap.ctrl == 0x0F then
        record("T11b_CTRL_VALUE", PASS, "MMC1_CTRL=$0F (SetMMC1Control applied correctly)")
    else
        record("T11b_CTRL_VALUE", FAIL, string.format("MMC1_CTRL=$%02X expected $0F", snap.ctrl))
    end

    -- T11b_CHR0_ZERO — no CHR bank write occurs before LoopForever
    if snap.chr0 == nil then
        record("T11b_CHR0_ZERO", FAIL, "snapshot not captured")
    elseif snap.chr0 == 0 then
        record("T11b_CHR0_ZERO", PASS, "MMC1_CHR0=$00 (no CHR bank write at boot)")
    else
        record("T11b_CHR0_ZERO", FAIL, string.format("MMC1_CHR0=$%02X expected $00", snap.chr0))
    end

    -- T11b_CHR1_ZERO — same for CHR bank 1
    if snap.chr1 == nil then
        record("T11b_CHR1_ZERO", FAIL, "snapshot not captured")
    elseif snap.chr1 == 0 then
        record("T11b_CHR1_ZERO", PASS, "MMC1_CHR1=$00 (no CHR bank write at boot)")
    else
        record("T11b_CHR1_ZERO", FAIL, string.format("MMC1_CHR1=$%02X expected $00", snap.chr1))
    end

    -- T11b_PRG_VALUE — RunGame → SwitchBank(5) → 5 writes to $E000
    if snap.prg == nil then
        record("T11b_PRG_VALUE", FAIL, "snapshot not captured")
    elseif snap.prg == 0x05 then
        record("T11b_PRG_VALUE", PASS, "MMC1_PRG=$05 (SwitchBank(5) applied correctly)")
    else
        record("T11b_PRG_VALUE", FAIL, string.format("MMC1_PRG=$%02X expected $05", snap.prg))
    end

    log("")
    log("=================================================================")
    log("MMC1 STATE PROBE SUMMARY  (T11b)")
    log("=================================================================")
    local npass, nfail = 0, 0
    for _, r in ipairs(results) do
        log(string.format("  [%s] %s", r.status, r.name))
        if r.status == PASS then npass = npass+1 else nfail = nfail+1 end
    end
    log(string.format("\n  %d PASS  /  %d FAIL  /  %d total", npass, nfail, npass+nfail))
    log(nfail == 0 and "\nT11b MMC1 STATE PROBE: ALL PASS" or "\nT11b MMC1 STATE PROBE: FAIL")
end

local ok, err = pcall(main)
if not ok then log("PROBE CRASH: " .. tostring(err)) end
f:close()
client.exit()
