-- bizhawk_t30_room_load_probe.lua
-- T30: Room Load — register a name, start Quest 1, verify room $77 loads
-- without exception and the game reaches Mode 5 (gameplay).
--
-- Tests:
--   1. No exception through the entire title → file select → gameplay chain
--   2. Mode byte reaches Mode 2 (load quest)
--   3. Mode byte reaches Mode 5 (gameplay)
--   4. Current room = $77 (opening overworld screen)
--   5. NMI keeps firing through all transitions (no hang)

local ROOT     = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\"
local OUT_DIR  = ROOT .. "builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_t30_room_load_probe.txt"

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

-- Memory helpers
local function try_dom(dom, offset, width)
    local ok, v = pcall(function()
        memory.usememorydomain(dom)
        if     width == 1 then return memory.read_u8(offset)
        elseif width == 2 then return memory.read_u16_be(offset)
        else                    return memory.read_u32_be(offset) end
    end)
    return ok and v or nil
end

local function ram8(nes_offset)
    local bus = 0xFF0000 + nes_offset
    for _, spec in ipairs({
        {"M68K BUS", bus}, {"68K RAM", nes_offset},
        {"System Bus", bus}, {"Main RAM", nes_offset},
    }) do
        local v = try_dom(spec[1], spec[2], 1)
        if v ~= nil then return v end
    end
    return 0
end

local function vram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("VRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

local function cram_u16(addr)
    local ok, v = pcall(function()
        memory.usememorydomain("CRAM")
        return memory.read_u16_be(addr)
    end)
    return ok and v or 0
end

-- Exception tracking
local exception_hit = false
local exception_name = nil
local exception_frame = 0

local function check_exception(frame)
    local pc = emu.getregister("M68K PC") or 0
    if pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF then
        if not exception_hit then
            exception_hit = true
            exception_frame = frame
            exception_name = (pc == EXC_BUS  and "ExcBusError")
                          or (pc == EXC_ADDR and "ExcAddrError")
                          or "DefaultException"
            log(string.format("  *** EXCEPTION at frame %d: %s (PC=$%06X)", frame, exception_name, pc))
        end
        return true
    end
    return false
end

-- Advance N frames, pressing buttons if specified, checking exceptions
local function advance(n, buttons)
    for i = 1, n do
        if buttons then joypad.set(buttons, 1) end
        emu.frameadvance()
        check_exception(_G._frame_counter or 0)
        _G._frame_counter = (_G._frame_counter or 0) + 1
    end
end

-- Wait until a mode is reached, with timeout
local function wait_for_mode(target, timeout, label)
    for i = 1, timeout do
        emu.frameadvance()
        check_exception(_G._frame_counter or 0)
        _G._frame_counter = (_G._frame_counter or 0) + 1
        local mode = ram8(0x0012)
        if mode == target then
            log(string.format("  %s: Mode $%02X reached at frame %d", label, target, _G._frame_counter))
            return true
        end
    end
    log(string.format("  %s: Mode $%02X NOT reached within %d frames (current=$%02X)",
        label, target, timeout, ram8(0x0012)))
    return false
end

-- Wait until mode changes away from current
local function wait_mode_change(from, timeout, label)
    for i = 1, timeout do
        emu.frameadvance()
        check_exception(_G._frame_counter or 0)
        _G._frame_counter = (_G._frame_counter or 0) + 1
        local mode = ram8(0x0012)
        if mode ~= from then
            log(string.format("  %s: Mode changed from $%02X to $%02X at frame %d",
                label, from, mode, _G._frame_counter))
            return true, mode
        end
    end
    return false, from
end

local function main()
    _G._frame_counter = 0
    local mode_history = {}
    local nmi_baseline = 0

    log("=================================================================")
    log("T30: Room Load Probe  —  Boot → File Select → Quest 1 → Room $77")
    log("=================================================================")
    log(string.format("  LoopForever=$%06X  ExcBus=$%06X  ExcAddr=$%06X  ExcDef=$%06X",
        LOOPFOREVER, EXC_BUS, EXC_ADDR, EXC_DEF))
    log("")

    -- Phase 1: Boot, let title screen settle
    log("--- Phase 1: Boot + title screen ---")
    advance(90)
    nmi_baseline = ram8(0x1003)
    log(string.format("  NMI counter at f90: %d", nmi_baseline))
    log(string.format("  GameMode: $%02X", ram8(0x0012)))

    -- Phase 2: Press Start to reach FS1 (Mode 1)
    log("")
    log("--- Phase 2: Press Start → File Select ---")
    advance(40, {Start = true})
    advance(20)
    local fs1_ok = wait_for_mode(0x01, 300, "FS1")
    if not fs1_ok then
        -- Try pressing Start again
        advance(20, {Start = true})
        fs1_ok = wait_for_mode(0x01, 300, "FS1 retry")
    end

    -- Phase 3: Navigate to REGISTER (slot 3 = down 3 times)
    log("")
    log("--- Phase 3: Navigate to REGISTER ---")
    advance(60)  -- let FS1 settle
    for rep = 1, 3 do
        advance(5, {Down = true})
        advance(15)
    end
    log(string.format("  CurSaveSlot ($0016): $%02X", ram8(0x0016)))

    -- Press Start to enter REGISTER (Mode E)
    advance(5, {Start = true})
    advance(10)
    local modeE_ok = wait_for_mode(0x0E, 300, "REGISTER")

    -- Phase 4: Type 5 letters (press A 5 times — types "AAAAA")
    log("")
    log("--- Phase 4: Type name ---")
    advance(60)  -- let REGISTER screen settle
    for letter = 1, 5 do
        advance(5, {A = true})
        advance(15)
    end

    -- Show name buffer
    local name_str = ""
    for i = 0, 7 do
        name_str = name_str .. string.format("%02X ", ram8(0x0638 + i))
    end
    log("  Name buffer ($0638): " .. name_str)

    -- Phase 5: Press Select (Genesis C) to advance CurSaveSlot to "End" ($03),
    --           then press Start to trigger ChoseEnd and return to FS1.
    --
    --   In Mode E, $0016 starts at 0 (first empty slot).
    --   UpdateModeEandF_Idle checks Select ($20): each press increments $0016.
    --   When $0016 == 3, pressing Start triggers ChoseEnd (saves name, exits).
    log("")
    log("--- Phase 5: Select END → finish registration ---")
    advance(30)  -- release buttons, let REGISTER settle
    log(string.format("  CurSaveSlot before Select: $%02X", ram8(0x0016)))

    -- Press C (Select) 3 times to advance $0016 from 0 → 1 → 2 → 3
    for sel = 1, 3 do
        advance(5, {C = true})
        advance(20)
        log(string.format("  After Select %d: CurSaveSlot=$%02X", sel, ram8(0x0016)))
    end

    -- Now $0016 should be 3 ("End").  Press Start to trigger ChoseEnd.
    advance(10)  -- release C
    advance(5, {Start = true})
    advance(60)  -- let mode transition happen
    local back_fs1 = wait_for_mode(0x01, 600, "back to FS1")
    if not back_fs1 then
        -- Retry: maybe needed an extra frame gap
        advance(30)
        advance(5, {Start = true})
        advance(30)
        back_fs1 = wait_for_mode(0x01, 600, "back to FS1 retry")
    end
    advance(60)  -- let FS1 settle

    -- Phase 6: Select slot 0 (should now be active) and press Start
    log("")
    log("--- Phase 6: Select slot 0 → start game ---")
    -- Navigate up to slot 0
    for rep = 1, 4 do
        advance(5, {Up = true})
        advance(15)
    end
    log(string.format("  CurSaveSlot ($0016): $%02X", ram8(0x0016)))
    log(string.format("  Slot active flags ($0633): %02X %02X %02X",
        ram8(0x0633), ram8(0x0634), ram8(0x0635)))

    -- Press Start to begin quest
    advance(5, {Start = true})
    advance(10)

    -- Phase 7: Watch mode transitions through Mode 2 → 3 → 5
    log("")
    log("--- Phase 7: Quest loading chain ---")
    local reached_mode2 = false
    local reached_mode5 = false
    local mode_log = {}

    local diag_interval = 60  -- log diagnostics every 60 frames while in Mode 3
    local diag_counter = 0

    for i = 1, 1200 do
        emu.frameadvance()
        check_exception(_G._frame_counter)
        _G._frame_counter = _G._frame_counter + 1

        local mode = ram8(0x0012)
        if #mode_log == 0 or mode_log[#mode_log] ~= mode then
            mode_log[#mode_log + 1] = mode
            log(string.format("  f%04d: Mode $%02X", _G._frame_counter, mode))
            diag_counter = 0  -- reset diag on mode change
        end

        -- Periodic diagnostics while stuck in Mode 3
        if mode == 0x03 then
            diag_counter = diag_counter + 1
            if diag_counter % diag_interval == 0 then
                log(string.format("  f%04d: Mode3 diag — $007C=%02X $007D=%02X $0028=%02X $0013=%02X $00EB=%02X",
                    _G._frame_counter,
                    ram8(0x007C), ram8(0x007D), ram8(0x0028),
                    ram8(0x0013), ram8(0x00EB)))
            end
        end

        if mode == 0x02 then reached_mode2 = true end
        if mode == 0x05 then reached_mode5 = true break end

        if exception_hit then break end
    end

    -- Extra frames in Mode 5 to let room settle
    if reached_mode5 then
        advance(120)
    end

    -- Phase 8: Read final state
    log("")
    log("--- Phase 8: Final state ---")
    local final_mode = ram8(0x0012)
    local current_room = ram8(0x00EB)
    local nmi_final = ram8(0x1003)
    local nmi_delta = (nmi_final - nmi_baseline) % 256

    log(string.format("  GameMode:    $%02X", final_mode))
    log(string.format("  CurrentRoom: $%02X  (want $77)", current_room))
    log(string.format("  NMI delta:   %d", nmi_delta))

    -- Check Plane A for nametable content
    local nt_nonzero = 0
    for i = 0, 127 do
        local tile = vram_u16(0xC000 + i * 2)
        if tile ~= 0 then nt_nonzero = nt_nonzero + 1 end
    end
    log(string.format("  Plane A non-zero tiles (first 128): %d/128", nt_nonzero))

    -- Check CRAM
    local cram_nonzero = 0
    for i = 0, 63 do
        if cram_u16(i * 2) ~= 0 then cram_nonzero = cram_nonzero + 1 end
    end
    log(string.format("  CRAM non-zero entries: %d/64", cram_nonzero))

    -- ── Tests ──────────────────────────────────────────────────────────
    log("")
    log("─── T30: Room Load Tests ───────────────────────────────────────")

    -- T30_NO_EXCEPTION
    if not exception_hit then
        record("T30_NO_EXCEPTION", PASS, "no exception handler hit")
    else
        record("T30_NO_EXCEPTION", FAIL,
            string.format("exception: %s at frame %d", exception_name or "?", exception_frame))
    end

    -- T30_NMI_CONTINUOUS
    if nmi_delta >= 50 then
        record("T30_NMI_CONTINUOUS", PASS,
            string.format("NMI advanced %d — no hang", nmi_delta))
    else
        record("T30_NMI_CONTINUOUS", FAIL,
            string.format("NMI advanced only %d — possible hang", nmi_delta))
    end

    -- T30_MODE2_REACHED
    if reached_mode2 then
        record("T30_MODE2_REACHED", PASS, "Mode 2 (load quest) was entered")
    else
        record("T30_MODE2_REACHED", FAIL, "Mode 2 never reached — quest load did not start")
    end

    -- T30_MODE5_REACHED
    if reached_mode5 or final_mode == 0x05 then
        record("T30_MODE5_REACHED", PASS,
            string.format("Mode 5 (gameplay) reached — final mode $%02X", final_mode))
    else
        record("T30_MODE5_REACHED", FAIL,
            string.format("Mode 5 not reached — final mode $%02X", final_mode))
    end

    -- T30_ROOM_77
    if current_room == 0x77 then
        record("T30_ROOM_77", PASS,
            string.format("current room = $%02X (opening overworld)", current_room))
    else
        record("T30_ROOM_77", FAIL,
            string.format("current room = $%02X (expected $77)", current_room))
    end

    -- Summary
    log("")
    log("=================================================================")
    log("T30 ROOM LOAD SUMMARY")
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
    if fail_cnt == 0 then log("T30 ROOM LOAD: ALL PASS")
    else                  log("T30 ROOM LOAD: " .. fail_cnt .. " FAILURE(S)") end
    log("")
    f:close()
    client.exit()
end

main()
