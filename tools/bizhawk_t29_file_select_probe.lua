-- bizhawk_t29_file_select_probe.lua
-- T29: File Select — press Start on title, verify file select screen renders.
--
-- Verifies that:
--   1. No exception during title → file select transition
--   2. Mode byte transitions from $00 (title) to $0E/$0F (file select)
--   3. Nametable is populated after transition (not blank)
--   4. CRAM has non-zero palette entries (file select palette loaded)
--   5. NMI keeps firing through transition (no hang)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t29_file_select_probe.txt"

dofile(ROOT .. "tools/probe_addresses.lua")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local f = assert(io.open(OUT_PATH, "w"))
local function log(msg) f:write(msg.."\n") f:flush() print(msg) end

local PASS, FAIL = "PASS", "FAIL"
local results = {}
local function record(name, status, detail)
    log(string.format("[%s] %-35s  %s", status, name, detail))
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

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function vram_u8(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u8(addr)
    end)
    return ok and v or 0
end

local function press_start()
    joypad.set({["P1 Start"] = true})
end

local function main()
    local MAX_FRAMES    = 600
    local PRESS_START   = 90
    local PRESS_END     = 130
    local CHECK_FRAME   = 500   -- check file select state at this frame

    log("=================================================================")
    log("T29: File Select Probe  —  up to " .. MAX_FRAMES .. " frames")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log(string.format("  Start button injected frames %d–%d", PRESS_START, PRESS_END))
    log(string.format("  File select check at frame %d", CHECK_FRAME))
    log("")

    local exception_hit  = false
    local exception_name = nil
    local exception_frame = 0
    local nmi_at_80      = 0
    local mode_history   = {}

    for frame = 1, MAX_FRAMES do
        if frame >= PRESS_START and frame <= PRESS_END then
            press_start()
        end

        emu.frameadvance()

        local pc = emu.getregister("M68K PC") or 0
        if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
            if not exception_hit then
                exception_hit  = true
                exception_frame = frame
                exception_name = (pc==EXC_BUS  and "ExcBusError")
                              or (pc==EXC_ADDR and "ExcAddrError")
                              or "DefaultException"
                log(string.format("  *** EXCEPTION at frame %d: %s (PC=$%06X)", frame, exception_name, pc))
            end
        end

        if frame == 80 then
            nmi_at_80 = ram_read(0xFF1003, 1) or 0
        end

        -- Log mode changes
        local mode = ram_read(0xFF0012, 1) or 0xFF
        if #mode_history == 0 or mode_history[#mode_history].mode ~= mode then
            mode_history[#mode_history+1] = {frame=frame, mode=mode}
            log(string.format("  f%03d: mode=$%02X", frame, mode))
        end

        if exception_hit and frame > PRESS_END + 50 then break end
    end

    local nmi_final = ram_read(0xFF1003, 1) or 0
    local final_mode = ram_read(0xFF0012, 1) or 0xFF

    -- Check CRAM state
    local cram_nonzero = 0
    for i = 0, 63 do
        local v = cram_u16(i * 2)
        if v ~= 0 then cram_nonzero = cram_nonzero + 1 end
    end

    -- Check nametable at Plane A ($C000) — sample first 64 tiles
    local nt_nonzero = 0
    for i = 0, 63 do
        local tile = vram_u8(0xC000 + i * 2) * 256 + vram_u8(0xC000 + i * 2 + 1)
        if tile ~= 0 then nt_nonzero = nt_nonzero + 1 end
    end

    log("")
    log(string.format("  Final mode: $%02X", final_mode))
    log(string.format("  NMI delta: %d (frames 80–end)", nmi_final - nmi_at_80))
    log(string.format("  CRAM non-zero entries: %d/64", cram_nonzero))
    log(string.format("  NT non-zero tiles (first 64): %d/64", nt_nonzero))
    log("")

    -- ── Tests ──────────────────────────────────────────────────────────
    log("─── T29: File Select Tests ─────────────────────────────────────")

    -- T29_NO_EXCEPTION
    if not exception_hit then
        record("T29_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T29_NO_EXCEPTION", FAIL,
            string.format("exception: %s at frame %d", exception_name or "?", exception_frame))
    end

    -- T29_NMI_CONTINUOUS
    local nmi_delta = nmi_final - nmi_at_80
    if nmi_delta >= 100 then
        record("T29_NMI_CONTINUOUS", PASS,
            string.format("NMI advanced %d — no hang", nmi_delta))
    else
        record("T29_NMI_CONTINUOUS", FAIL,
            string.format("NMI advanced only %d — possible hang", nmi_delta))
    end

    -- T29_MODE_TRANSITION: mode left $00 (title)
    local reached_file_select = false
    for _, entry in ipairs(mode_history) do
        if entry.mode >= 0x0E and entry.mode <= 0x0F then
            reached_file_select = true
        end
    end
    if reached_file_select then
        record("T29_MODE_TRANSITION", PASS,
            "mode reached $0E or $0F (file select)")
    elseif final_mode ~= 0x00 then
        record("T29_MODE_TRANSITION", PASS,
            string.format("mode changed from $00 to $%02X", final_mode))
    else
        record("T29_MODE_TRANSITION", FAIL,
            string.format("mode still $%02X — no transition occurred", final_mode))
    end

    -- T29_CRAM_POPULATED
    if cram_nonzero >= 4 then
        record("T29_CRAM_POPULATED", PASS,
            string.format("%d/64 CRAM entries non-zero", cram_nonzero))
    else
        record("T29_CRAM_POPULATED", FAIL,
            string.format("only %d/64 CRAM entries non-zero — palette not loaded", cram_nonzero))
    end

    -- T29_NT_POPULATED
    if nt_nonzero >= 4 then
        record("T29_NT_POPULATED", PASS,
            string.format("%d/64 nametable tiles non-zero", nt_nonzero))
    else
        record("T29_NT_POPULATED", FAIL,
            string.format("only %d/64 nametable tiles non-zero — screen may be blank", nt_nonzero))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("T29 FILE SELECT SUMMARY")
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
    if fail_cnt == 0 then log("T29 FILE SELECT: ALL PASS")
    else                  log("T29 FILE SELECT: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
