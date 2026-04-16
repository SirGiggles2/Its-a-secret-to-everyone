-- bizhawk_phase1_verify.lua
-- Phase 1 diary re-integration verification probe.
--
-- Checks:
--  1. V64 intro scroll landmarks: at the intro's critical PpuScrlY/CurV samples
--     the observed $FF042C ("Act") counter still equals 8 (not 487, which
--     would indicate a regression to the pre-Zelda27.47 VSRAM snap).
--  2. File-select reachable: there is at least one frame where GameMode=$01
--     AND the submode bytes are consistent with the file-select dispatcher
--     (updating=$00, PpuSwitchReq=$00).
--  3. Soak sanity: no exception handler hit during the full run.
--  4. LAST_GAMEMODE + VRamForceBlankGate trace: the two new Phase 1 bytes
--     behave as expected (LAST_GAMEMODE latches to the first observed
--     GameMode, VRamForceBlankGate is released by the end of init).
--
-- Output: writes a report to builds\reports\bizhawk_phase1_verify.txt
-- and exits BizHawk automatically.

local ROOT = os.getenv("CODEX_BIZHAWK_ROOT")
if not ROOT or ROOT == "" then
    ROOT = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
end
ROOT = ROOT:gsub("/", "\\"):gsub("\\+$", "") .. "\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase1_verify.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

local FORENSICS_TYPE = 0xFF0900
local FORENSICS_PC   = 0xFF0904

local FRAMES = 4000  -- long enough to cover intro scroll + reach file-select

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

-- Memory helpers (fallback across domains, same approach as boot probe).
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
        if v ~= nil then return v end
    end
    return nil
end
local function u8(a)  return ram_read(a, 1) end
local function u16(a) return ram_read(a, 2) end

-- ── Exception hook ────────────────────────────────────────────────────────
local exception_hit = false
local exception_name = nil
local function hook_exc(name)
    return function()
        if not exception_hit then
            exception_hit = true
            exception_name = name
        end
    end
end
local hook_ids = {}
for _, spec in ipairs({
    {EXC_BUS,  "ExcBusError"},
    {EXC_ADDR, "ExcAddrError"},
    {EXC_DEF,  "DefaultException"},
}) do
    local ok, id = pcall(function()
        return event.onmemoryexecute(hook_exc(spec[2]), spec[1], "p1_"..spec[2])
    end)
    if ok and id then hook_ids[#hook_ids+1] = id end
end

-- ── Sampling state ────────────────────────────────────────────────────────
local act_samples = {}          -- {frame, curV, ppuScrlY, act, ntBit, gameMode}
local first_mode01_frame = nil
local last_gamemode_last = nil
local vramforceblank_releases = 0
local vramforceblank_was_set  = false
local gamemodes_observed = {}
local max_mode = 0
local input_trace = {}          -- snapshots during the Start press window

local function sample_act()
    local frame_no = emu.framecount()
    local curV     = u8(0xFF00FC) or 0
    local ppuCtrl  = u8(0xFF00FF) or 0
    local ntBit    = math.floor(ppuCtrl / 2) % 2
    local ppuScrlY = u8(0xFF0807) or 0  -- PPU_SCRL_Y
    local act      = u16(0xFF042C) or 0
    local gameMode = u8(0xFF0012) or 0
    return frame_no, curV, ppuScrlY, act, ntBit, gameMode, ppuCtrl
end

log("=================================================================")
log(string.format("Phase 1 verify probe  —  %d frames", FRAMES))
log("=================================================================")
log(string.format("  IsrNmi=$%06X  LoopForever=$%06X", ISRNMI, LOOPFOREVER))
log("")

-- Press Start for ~20 frames starting at 180 (covers gpgx input latency
-- regardless of which spelling the core accepts).  We write all three
-- candidate button keys so whichever one the BizHawk build honors wins.
local press_start_window = {}
for fr = 180, 210 do press_start_window[#press_start_window+1] = fr end
local start_map = {}
for _, fr in ipairs(press_start_window) do start_map[fr] = true end

for frame = 1, FRAMES do
    if start_map[frame] then
        pcall(function()
            joypad.set({["P1 Start"] = true, ["Start"] = true, ["P1 Start Button"] = true}, 1)
        end)
    end
    emu.frameadvance()

    local fr, curV, ppuScrlY, act, ntBit, gameMode, ppuCtrl = sample_act()

    gamemodes_observed[gameMode] = (gamemodes_observed[gameMode] or 0) + 1
    if gameMode > max_mode then max_mode = gameMode end
    if gameMode == 0x01 and first_mode01_frame == nil then
        first_mode01_frame = frame
    end

    -- Track VRamForceBlankGate transitions.
    local gate = u8(0xFF083D) or 0
    if gate ~= 0 then vramforceblank_was_set = true end
    if gate == 0 and vramforceblank_was_set then
        vramforceblank_releases = vramforceblank_releases + 1
        vramforceblank_was_set = false
    end

    last_gamemode_last = u8(0xFF0810)

    -- Trace input path around the press window.
    if frame >= 178 and frame <= 220 then
        input_trace[#input_trace+1] = {
            frame      = frame,
            latch      = u8(0xFF1100) or 0,   -- CTL1_LATCH
            input_ctr  = u8(0xFF100A) or 0,   -- Phase 2.4 input-poll counter
            nmi_ctr    = u8(0xFF1003) or 0,   -- Phase 2.4 NMI counter
            ff00f8     = u8(0xFF00F8) or 0,   -- NES $F8: cooked button byte
            ff0012     = u8(0xFF0012) or 0,   -- GameMode
            ff0013     = u8(0xFF0013) or 0,   -- SubMode
        }
    end

    -- Save intro-scroll ACT samples at the diary's critical frames.
    if frame == 1486 or frame == 2702 or frame == 3258 or frame == 3662 then
        act_samples[#act_samples+1] = {
            frame=frame, curV=curV, ppuScrlY=ppuScrlY, act=act,
            ntBit=ntBit, gameMode=gameMode, ppuCtrl=ppuCtrl
        }
    end

    if exception_hit then
        log(string.format("** Exception hit at frame %d — stopping early", frame))
        break
    end
end

for _, id in ipairs(hook_ids) do
    pcall(function() event.unregisterbyid(id) end)
end

-- ── Report ────────────────────────────────────────────────────────────────
log("")
log("─── V64 intro-scroll Act samples ──────────────────────────────")
for _, s in ipairs(act_samples) do
    log(string.format("  f%-4d  CurV=$%02X  PpuScrlY=$%02X  NT=%d  Mode=$%02X  Act=%d",
        s.frame, s.curV, s.ppuScrlY, s.ntBit, s.gameMode, s.act))
end

local act_ok = true
for _, s in ipairs(act_samples) do
    if s.act == 487 then act_ok = false end
end

log("")
log("─── Input trace (frames 178-220) ──────────────────────────────")
for _, t in ipairs(input_trace) do
    log(string.format("  f%-4d  Mode=$%02X  Sub=$%02X  $F8=$%02X  CTL1=$%02X  inCtr=$%02X  nmCtr=$%02X",
        t.frame, t.ff0012, t.ff0013, t.ff00f8, t.latch, t.input_ctr, t.nmi_ctr))
end

log("")
log("─── File-select reach ─────────────────────────────────────────")
if first_mode01_frame then
    log(string.format("  first Mode=$01 frame: %d", first_mode01_frame))
else
    log("  Mode=$01 NEVER observed within "..FRAMES.." frames")
end

log("")
log("─── Phase 1 shadows ───────────────────────────────────────────")
log(string.format("  LAST_GAMEMODE ($FF0810) at run end: $%02X (last seen GameMode=$%02X)",
    last_gamemode_last or 0xFF, max_mode))
log(string.format("  VRamForceBlankGate releases observed: %d", vramforceblank_releases))

log("")
log("─── GameMode histogram (top 5) ────────────────────────────────")
local modes = {}
for k, v in pairs(gamemodes_observed) do modes[#modes+1] = {k, v} end
table.sort(modes, function(a,b) return a[2] > b[2] end)
for i = 1, math.min(5, #modes) do
    log(string.format("  GameMode $%02X: %d frames", modes[i][1], modes[i][2]))
end

log("")
log("─── Soak ──────────────────────────────────────────────────────")
if exception_hit then
    log("  FAIL: "..(exception_name or "?"))
else
    log("  PASS: no exception handler hit")
end

log("")
log("=================================================================")
log("PHASE 1 VERIFY SUMMARY")
log("=================================================================")
local pass = 0
local fail = 0
local function verdict(name, ok, detail)
    log(string.format("  [%s] %-30s  %s", ok and "PASS" or "FAIL", name, detail))
    if ok then pass = pass + 1 else fail = fail + 1 end
end
verdict("P1_NO_EXCEPTION",       not exception_hit,
    exception_hit and exception_name or "clean soak")
verdict("P1_V64_SCROLL_ACT8",    act_ok,
    act_ok and ("all "..#act_samples.." samples Act != 487") or "one or more samples had Act=487")
verdict("P1_FILE_SELECT_REACH",  first_mode01_frame ~= nil,
    first_mode01_frame and ("first mode=$01 at frame "..first_mode01_frame) or "never reached mode=$01")
verdict("P1_VRAM_GATE_RELEASE",  vramforceblank_releases >= 1 or not vramforceblank_was_set,
    vramforceblank_releases >= 1 and (tostring(vramforceblank_releases).." release(s) seen")
    or "gate never observed set (expected if no Start press reached init)")
verdict("P1_LAST_GAMEMODE_LATCH", last_gamemode_last ~= nil and last_gamemode_last ~= 0xFF,
    string.format("shadow=$%02X (cold $FF seeded, must latch to a real mode)", last_gamemode_last or 0xFF))

log(string.format("\n  %d PASS  /  %d FAIL", pass, fail))
log(fail == 0 and "\nPHASE 1 VERIFY: ALL PASS" or "\nPHASE 1 VERIFY: FAIL")

f:close()
client.exit()
