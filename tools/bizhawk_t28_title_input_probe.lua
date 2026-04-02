-- bizhawk_t28_title_input_probe.lua
-- T28: Title Input — inject Start button press on title screen,
--      verify game transitions away from title mode.
--
-- Verifies that:
--   1. No exception during title → file-select transition
--   2. NMI keeps firing through transition (game not hanging)
--   3. Mode byte at $FF0012 starts at 1 (title) during title phase
--   4. Mode byte advances after Start is pressed (transition occurred)
--   5. CheckInput continues running after transition
--
-- Note: Manual active-button confirmation is tested here via joypad injection.

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t28_title_input_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-30s  %s", status, name, detail))
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

-- Press Start for a window of frames (before frameadvance).
-- BizHawk 2.x joypad.set: button names for GPGX 3-button pad are "P1 X"
local function press_start()
    joypad.set({["P1 Start"] = true})
end

local function main()
    local MAX_FRAMES    = 400
    local PRESS_START   = 90    -- begin pressing Start at this frame
    local PRESS_END     = 130   -- stop pressing Start

    log("=================================================================")
    log("T28: Title Input Probe  —  up to " .. MAX_FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log(string.format("  Start button injected frames %d–%d", PRESS_START, PRESS_END))
    log("")

    local exception_hit  = false
    local exception_name = nil
    local nmi_start  = 0
    local nmi_end    = 0
    local ci_start   = 0
    local ci_end     = 0
    local mode_early = 0
    local mode_mid   = 0
    local mode_late  = 0

    for frame = 1, MAX_FRAMES do
        -- Inject Start button press BEFORE frameadvance so the NMI sees it
        if frame >= PRESS_START and frame <= PRESS_END then
            press_start()
        end

        emu.frameadvance()

        local pc = emu.getregister("M68K PC") or 0
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit  = true
                exception_name = (pc==EXC_BUS  and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
            end
        end

        if frame == 80 then
            nmi_start  = ram_read(0xFF1003, 1) or 0
            ci_start   = ram_read(0xFF100A, 1) or 0
            mode_early = ram_read(0xFF0012, 1) or 0xFF
        end
        if frame == PRESS_START + 10 then
            mode_mid = ram_read(0xFF0012, 1) or 0xFF
        end

        if exception_hit and frame > 50 then break end
    end

    nmi_end   = ram_read(0xFF1003, 1) or 0
    ci_end    = ram_read(0xFF100A, 1) or 0
    mode_late = ram_read(0xFF0012, 1) or 0xFF

    -- Additional state
    local btn1  = ram_read(0xFF00F8, 1) or 0
    local new1  = ram_read(0xFF00FA, 1) or 0
    local latch = ram_read(0xFF1100, 1) or 0
    local idx   = ram_read(0xFF1101, 1) or 0

    log(string.format("  Mode byte ($FF0012): frame-80=%02X  frame-%d=%02X  final=%02X",
        mode_early, PRESS_START+10, mode_mid, mode_late))
    log(string.format("  NMI count:     start=%d  end=%d  delta=%d",
        nmi_start, nmi_end, nmi_end - nmi_start))
    log(string.format("  CheckInput:    start=%d  end=%d  delta=%d",
        ci_start, ci_end, ci_end - ci_start))
    log(string.format("  Button regs:   $F8=%02X (held)  $FA=%02X (new-press)",
        btn1, new1))
    log(string.format("  CTL1_LATCH=$%02X  CTL1_IDX=%d", latch, idx))
    log("")

    -- ── Tests ──────────────────────────────────────────────────────────
    log("─── T28: Title Input Tests ──────────────────────────────────────")

    -- T28_NO_EXCEPTION
    if not exception_hit then
        record("T28_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T28_NO_EXCEPTION", FAIL, "exception: " .. (exception_name or "?"))
    end

    -- T28_NMI_CONTINUOUS: NMI keeps firing through and after transition
    local nmi_delta = nmi_end - nmi_start
    if nmi_delta >= 50 then
        record("T28_NMI_CONTINUOUS", PASS,
            string.format("NMI advanced %d over frames 80–%d — no hang", nmi_delta, MAX_FRAMES))
    else
        record("T28_NMI_CONTINUOUS", FAIL,
            string.format("NMI advanced only %d — game may be hanging", nmi_delta))
    end

    -- T28_TITLE_MODE: mode byte was 1 (title) at frame 80
    if mode_early == 0x01 then
        record("T28_TITLE_MODE", PASS,
            string.format("mode=$%02X at frame 80 — title screen confirmed", mode_early))
    else
        record("T28_TITLE_MODE", FAIL,
            string.format("mode=$%02X at frame 80 — expected $01 (title)", mode_early))
    end

    -- T28_MODE_ADVANCE: mode changed after Start press
    if mode_late ~= mode_early then
        record("T28_MODE_ADVANCE", PASS,
            string.format("mode $%02X → $%02X after Start press — transition fired",
                mode_early, mode_late))
    else
        record("T28_MODE_ADVANCE", FAIL,
            string.format("mode stayed $%02X — Start press may not have registered",
                mode_early))
    end

    -- T28_CI_POST_TRANSITION: CheckInput still running after mode change
    local ci_delta = ci_end - ci_start
    if ci_delta >= 50 then
        record("T28_CI_POST_TRANSITION", PASS,
            string.format("CheckInput advanced %d past transition — input loop intact", ci_delta))
    else
        record("T28_CI_POST_TRANSITION", FAIL,
            string.format("CheckInput advanced only %d — may have stalled", ci_delta))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("T28 TITLE INPUT SUMMARY")
    log("=================================================================")
    local pass_cnt, fail_cnt = 0, 0
    for _, res in ipairs(results) do
        log(string.format("  [%s] %s", res.status, res.name))
        if res.status == PASS then pass_cnt = pass_cnt + 1
        else                       fail_cnt = fail_cnt + 1 end
    end
    log("")
    log(string.format("  %d PASS  /  %d FAIL  /  %d total", pass_cnt, fail_cnt, #results))
    log("")
    if fail_cnt == 0 then log("T28 TITLE INPUT: ALL PASS")
    else                  log("T28 TITLE INPUT: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
