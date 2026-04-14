-- bizhawk_t30_room_load_probe.lua
-- T30/T31/T32 runtime gate for room-load progression.
--
-- This probe uses a natural frontend path:
--   title -> FS1 (mode $01) -> REGISTER (slot 3) -> Mode E ($0E)
--   -> name input pulses -> END confirmation -> gameplay transition.
--
-- T30: room-load progression and no Mode3/Sub8 hang.
-- T31: capture screenshot in room $77 once gameplay mode is reached.
-- T32: dump $FF0000-$FF07FF RAM.
--
-- Authoritative room-id for gameplay gating is NES RAM $00EB (RoomId).
-- $003C is logged as diagnostic-only telemetry.

dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    if not tools_dir then
        error("unable to resolve tools directory from '" .. source .. "'")
    end
    return tools_dir .. "\\probe_root.lua"
end)())

dofile(repo_path("tools\\probe_addresses.lua"))

local OUT_DIR = repo_path("builds\\reports")
local OUT_TXT = repo_path("builds\\reports\\bizhawk_t30_room_load_probe.txt")
local OUT_PNG = repo_path("builds\\reports\\bizhawk_t31_room77.png")
local OUT_RAM = repo_path("builds\\reports\\bizhawk_t32_ram_ff0000_ff07ff.bin")

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')

local function try_read(domain, addr, width)
    local ok, value = pcall(function()
        memory.usememorydomain(domain)
        if width == 1 then
            return memory.read_u8(addr)
        end
        if width == 2 then
            return memory.read_u16_be(addr)
        end
        return memory.read_u32_be(addr)
    end)
    if ok then
        return value
    end
    return nil
end

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    local domains = {
        {"68K RAM", ofs},
        {"M68K BUS", bus_addr},
        {"System Bus", bus_addr},
        {"Main RAM", ofs},
    }
    for _, spec in ipairs(domains) do
        local v = try_read(spec[1], spec[2], 1)
        if v ~= nil then
            return v
        end
    end
    return 0
end

local function safe_set(pad)
    local ok = pcall(function()
        joypad.set(pad or {}, 1)
    end)
    if not ok then
        joypad.set(pad or {})
    end
end

local function record(lines, text)
    lines[#lines + 1] = text
    print(text)
end

local function read_bank_window_snapshot()
    local mmc1_prg = ram_u8(0xFF0815)
    local current_window_bank = ram_u8(0xFF083F)
    local bytes = {}
    local nonzero = false
    for i = 0, 7 do
        local b = ram_u8(0xFF8000 + i)
        bytes[#bytes + 1] = b
        if b ~= 0 then
            nonzero = true
        end
    end
    return {
        mmc1_prg = mmc1_prg,
        current_window_bank = current_window_bank,
        bytes = bytes,
        nonzero = nonzero,
    }
end

local function bank_bytes_hex(bytes)
    local out = {}
    for i = 1, #bytes do
        out[#out + 1] = string.format("%02X", bytes[i])
    end
    return table.concat(out, " ")
end

local function schedule_input(state, button, hold_frames, release_frames, frame, why, lines)
    if state.hold_left > 0 or state.release_left > 0 then
        return false
    end
    state.button = button
    state.hold_left = hold_frames or 1
    state.release_left = 0
    state.release_after = release_frames or 8
    record(lines, string.format(
        "f%04d input %-9s hold=%d release=%d (%s)",
        frame, button, state.hold_left, state.release_after, why or "n/a"
    ))
    return true
end

local function build_pad_for_frame(state)
    local pad = {}
    if state.hold_left > 0 and state.button then
        if state.button:sub(1, 3) == "P1 " then
            pad[state.button] = true
            pad[state.button:sub(4)] = true
        else
            pad[state.button] = true
            pad["P1 " .. state.button] = true
        end
        state.hold_left = state.hold_left - 1
        if state.hold_left == 0 then
            state.release_left = state.release_after
        end
    elseif state.release_left > 0 then
        state.release_left = state.release_left - 1
    end
    return pad
end

local lines = {}
local mode_changes = {}

local MAX_FRAMES = 6500
local MODE0_BOOT_TIMEOUT = 900
local MODE3_SUB8_TIMEOUT = 300
local MODE23_TELEMETRY_PERIOD = 30
local TARGET_NAME_PROGRESS = 5

local FLOW_BOOT_TO_FS1 = "BOOT_TO_FS1"
local FLOW_FS1_SELECT_REGISTER = "FS1_SELECT_REGISTER"
local FLOW_FS1_ENTER_REGISTER = "FS1_ENTER_REGISTER"
local FLOW_MODEE_TYPE_NAME = "MODEE_TYPE_NAME"
local FLOW_MODEE_FINISH = "MODEE_FINISH"
local FLOW_FS1_START_GAME = "FS1_START_GAME"
local FLOW_WAIT_GAMEPLAY = "WAIT_GAMEPLAY"

local flow_state = FLOW_BOOT_TO_FS1
local flow_state_frame = 1
local function set_flow_state(new_state, frame, reason)
    if flow_state ~= new_state then
        record(lines, string.format(
            "f%04d flow %s -> %s (%s)",
            frame, flow_state, new_state, reason or "n/a"
        ))
        flow_state = new_state
        flow_state_frame = frame
    end
end

local input_state = {
    button = nil,
    hold_left = 0,
    release_left = 0,
    release_after = 0,
}

local exception_hit = false
local exception_name = ""
local exception_frame = -1

local first_mode3_sub8 = nil
local left_mode3_sub8 = false
local mode3_sub8_streak = 0
local mode3_sub8_max_streak = 0

local saw_mode5 = false
local saw_room77 = false
local screenshot_done = false
local screenshot_room = nil
local register_mode_seen = false

local fs1_c_pulses = 0
local fs1_start_pulses = 0
local fs1_dpad_pulses = 0
local fs1_postreg_c_pulses = 0
local fs1_postreg_start_pulses = 0
local title_start_pulses = 0
local modee_c_pulses = 0
local modee_start_pulses = 0

local last_name_offset = 0
local name_progress_events = 0
local last_cur_slot = 0xFF

local window_loaded_in_mode23 = false
local first_window_loaded_frame = nil

local last_mode = nil
local last_sub = nil
local nmi_start = 0
local nmi_end = 0

record(lines, "=================================================================")
record(lines, "T30/T31/T32 probe: room-load progression (natural path)")
record(lines, "=================================================================")
record(lines, string.format("LoopForever=$%06X  IsrNmi=$%06X", LOOPFOREVER, ISRNMI))
record(lines, "")

for frame = 1, MAX_FRAMES do
    local mode = ram_u8(0xFF0012)
    local sub = ram_u8(0xFF0013)
    local room_id = ram_u8(0xFF00EB)
    local room_diag = ram_u8(0xFF003C)
    local cur_slot = ram_u8(0xFF0016)
    local name_ofs = ram_u8(0xFF0421)
    local slot_active0 = ram_u8(0xFF0633)
    local slot_active1 = ram_u8(0xFF0634)
    local slot_active2 = ram_u8(0xFF0635)

    if cur_slot ~= last_cur_slot then
        record(lines, string.format(
            "f%04d CurSaveSlot=$%02X active=%02X/%02X/%02X",
            frame, cur_slot, slot_active0, slot_active1, slot_active2
        ))
        last_cur_slot = cur_slot
    end

    if frame == 1 then
        nmi_start = ram_u8(0xFF1003)
    end

    if mode == 0x01 and flow_state == FLOW_BOOT_TO_FS1 then
        set_flow_state(FLOW_FS1_SELECT_REGISTER, frame, "entered Mode1")
    end
    if mode == 0x0E and flow_state ~= FLOW_MODEE_TYPE_NAME and flow_state ~= FLOW_MODEE_FINISH then
        set_flow_state(FLOW_MODEE_TYPE_NAME, frame, "entered ModeE register")
        register_mode_seen = true
        last_name_offset = name_ofs
    end

    if flow_state == FLOW_BOOT_TO_FS1 then
        if mode == 0x01 then
            set_flow_state(FLOW_FS1_SELECT_REGISTER, frame, "entered Mode1")
        elseif frame > MODE0_BOOT_TIMEOUT then
            record(lines, string.format(
                "f%04d boot timeout: never reached Mode1 (mode=$%02X sub=$%02X)",
                frame, mode, sub
            ))
            break
        else
            if schedule_input(input_state, "Start", 2, 3, frame, "fast title->file-select", lines) then
                title_start_pulses = title_start_pulses + 1
            end
        end

    elseif flow_state == FLOW_FS1_SELECT_REGISTER then
        if mode == 0x01 then
            if cur_slot == 0x03 then
                set_flow_state(FLOW_FS1_ENTER_REGISTER, frame, "CurSaveSlot reached 3")
            else
                if schedule_input(input_state, "Down", 1, 10, frame, "move to REGISTER (slot 3)", lines) then
                    fs1_dpad_pulses = fs1_dpad_pulses + 1
                end
            end
        end

    elseif flow_state == FLOW_FS1_ENTER_REGISTER then
        if mode == 0x0E then
            set_flow_state(FLOW_MODEE_TYPE_NAME, frame, "register mode entered")
            register_mode_seen = true
            last_name_offset = name_ofs
        elseif mode == 0x01 then
            if schedule_input(input_state, "Start", 2, 14, frame, "enter register mode", lines) then
                fs1_start_pulses = fs1_start_pulses + 1
            end
        end

    elseif flow_state == FLOW_MODEE_TYPE_NAME then
        register_mode_seen = true

        if name_ofs ~= last_name_offset then
            record(lines, string.format(
                "f%04d name progress $0421: %02X -> %02X",
                frame, last_name_offset, name_ofs
            ))
            last_name_offset = name_ofs
            name_progress_events = name_progress_events + 1
        end

        if name_progress_events >= TARGET_NAME_PROGRESS then
            set_flow_state(FLOW_MODEE_FINISH, frame, "name progress target met")
        else
            if schedule_input(input_state, "A", 1, 10, frame, "ModeE char pulse (A)", lines) then
                modee_c_pulses = modee_c_pulses + 1
            end
        end

    elseif flow_state == FLOW_MODEE_FINISH then
        if mode ~= 0x0E then
            set_flow_state(FLOW_WAIT_GAMEPLAY, frame, "left ModeE")
        else
            if cur_slot ~= 0x03 then
                if schedule_input(input_state, "C", 1, 10, frame, "cycle to END slot", lines) then
                    modee_c_pulses = modee_c_pulses + 1
                end
            else
                if schedule_input(input_state, "Start", 2, 14, frame, "confirm END", lines) then
                    modee_start_pulses = modee_start_pulses + 1
                end
            end
        end

    elseif flow_state == FLOW_WAIT_GAMEPLAY then
        if mode == 0x01 then
            set_flow_state(FLOW_FS1_START_GAME, frame, "back at FS1 after register")
        end

    elseif flow_state == FLOW_FS1_START_GAME then
        if mode == 0x01 then
            if slot_active0 == 0 and slot_active1 == 0 and slot_active2 == 0 and (frame - flow_state_frame) > 120 then
                record(lines, string.format(
                    "f%04d no active slots after register (active=%02X/%02X/%02X), aborting gameplay wait",
                    frame, slot_active0, slot_active1, slot_active2
                ))
                break
            end

            local target_slot = 0x00
            if slot_active0 == 0 and slot_active1 ~= 0 then
                target_slot = 0x01
            elseif slot_active0 == 0 and slot_active1 == 0 and slot_active2 ~= 0 then
                target_slot = 0x02
            end

            if cur_slot ~= target_slot then
                local move_btn = "Up"
                if target_slot > cur_slot then
                    move_btn = "Down"
                end
                if schedule_input(input_state, move_btn, 1, 10, frame, "move to active slot", lines) then
                    fs1_postreg_c_pulses = fs1_postreg_c_pulses + 1
                end
            else
                if schedule_input(input_state, "Start", 2, 14, frame, "start game from slot 0", lines) then
                    fs1_postreg_start_pulses = fs1_postreg_start_pulses + 1
                end
            end
        else
            set_flow_state(FLOW_WAIT_GAMEPLAY, frame, "left FS1 for gameplay path")
        end
    end

    local pad = build_pad_for_frame(input_state)
    safe_set(pad)
    emu.frameadvance()

    local pc = emu.getregister("M68K PC") or 0
    if not exception_hit and (pc == EXC_BUS or pc == EXC_ADDR or pc == EXC_DEF) then
        exception_hit = true
        exception_frame = frame
        if pc == EXC_BUS then
            exception_name = "ExcBusError"
        elseif pc == EXC_ADDR then
            exception_name = "ExcAddrError"
        else
            exception_name = "DefaultException"
        end
        record(lines, string.format("f%04d EXCEPTION %s PC=$%06X", frame, exception_name, pc))
    end

    mode = ram_u8(0xFF0012)
    sub = ram_u8(0xFF0013)
    room_id = ram_u8(0xFF00EB)
    room_diag = ram_u8(0xFF003C)

    local snap = read_bank_window_snapshot()
    local window_loaded = (snap.current_window_bank <= 0x06) and snap.nonzero
    if window_loaded and (mode == 0x02 or mode == 0x03) and not window_loaded_in_mode23 then
        window_loaded_in_mode23 = true
        first_window_loaded_frame = frame
        record(lines, string.format(
            "f%04d bank-window first load in mode $%02X: mmc1PRG=$%02X curBank=$%02X win=%s",
            frame, mode, snap.mmc1_prg, snap.current_window_bank, bank_bytes_hex(snap.bytes)
        ))
    end

    if mode ~= last_mode or sub ~= last_sub then
        mode_changes[#mode_changes + 1] = {frame = frame, mode = mode, sub = sub}
        record(lines, string.format(
            "f%04d mode=$%02X sub=$%02X roomId=$%02X room03C=$%02X mmc1PRG=$%02X curBank=$%02X win=%s",
            frame, mode, sub, room_id, room_diag, snap.mmc1_prg, snap.current_window_bank, bank_bytes_hex(snap.bytes)
        ))
        last_mode = mode
        last_sub = sub
    elseif (mode == 0x02 or mode == 0x03) and (frame % MODE23_TELEMETRY_PERIOD == 0) then
        record(lines, string.format(
            "f%04d mode23 telemetry mode=$%02X sub=$%02X mmc1PRG=$%02X curBank=$%02X win=%s",
            frame, mode, sub, snap.mmc1_prg, snap.current_window_bank, bank_bytes_hex(snap.bytes)
        ))
    end

    if mode == 0x03 and sub == 0x08 then
        mode3_sub8_streak = mode3_sub8_streak + 1
        if not first_mode3_sub8 then
            first_mode3_sub8 = frame
            record(lines, string.format("f%04d hit Mode3/Sub8 (LayoutRoomOW window)", frame))
        end
    else
        if mode3_sub8_streak > 0 and first_mode3_sub8 then
            left_mode3_sub8 = true
        end
        if mode3_sub8_streak > mode3_sub8_max_streak then
            mode3_sub8_max_streak = mode3_sub8_streak
        end
        mode3_sub8_streak = 0
    end

    if mode == 0x05 then
        saw_mode5 = true
        if flow_state ~= FLOW_WAIT_GAMEPLAY then
            set_flow_state(FLOW_WAIT_GAMEPLAY, frame, "entered Mode5")
        end
    end
    if room_id == 0x77 then
        saw_room77 = true
    end

    if not screenshot_done and mode == 0x05 then
        screenshot_done = true
        screenshot_room = room_id
        client.screenshot(OUT_PNG)
        record(lines, string.format("f%04d captured screenshot (roomId=$%02X room03C=$%02X): %s", frame, room_id, room_diag, OUT_PNG))
    end

    if mode3_sub8_streak > MODE3_SUB8_TIMEOUT then
        record(lines, string.format("f%04d Mode3/Sub8 streak exceeded %d frames", frame, MODE3_SUB8_TIMEOUT))
        break
    end

    if saw_mode5 and saw_room77 and frame > 1200 then
        break
    end
end

if mode3_sub8_streak > mode3_sub8_max_streak then
    mode3_sub8_max_streak = mode3_sub8_streak
end
nmi_end = ram_u8(0xFF1003)

-- T32 RAM dump artifact
local wrote_ram = false
do
    local fh = io.open(OUT_RAM, "wb")
    if fh then
        for off = 0, 0x07FF do
            fh:write(string.char(ram_u8(0xFF0000 + off) % 0x100))
        end
        fh:close()
        wrote_ram = true
    end
end

local function verdict(name, ok, detail)
    record(lines, string.format("[%s] %-30s %s", ok and "PASS" or "FAIL", name, detail))
    return ok and 1 or 0
end

record(lines, "")
record(lines, "Mode transitions (first 24):")
for i = 1, math.min(#mode_changes, 24) do
    local m = mode_changes[i]
    record(lines, string.format("  f%04d mode=$%02X sub=$%02X", m.frame, m.mode, m.sub))
end

local final_snap = read_bank_window_snapshot()
record(lines, "")
record(lines, string.format("NMI delta: %d", (nmi_end - nmi_start) % 0x100))
record(lines, string.format("flow_state_end: %s (since frame %d)", flow_state, flow_state_frame))
record(lines, string.format("register_mode_seen: %s", register_mode_seen and "yes" or "no"))
record(lines, string.format("name_progress_events: %d (target=%d)", name_progress_events, TARGET_NAME_PROGRESS))
record(lines, string.format("pulse_counts: titleStart=%d fs1C=%d fs1Dpad=%d fs1Start=%d fs1PostRegMove=%d fs1PostRegStart=%d modeeC=%d modeeStart=%d",
    title_start_pulses, fs1_c_pulses, fs1_dpad_pulses, fs1_start_pulses, fs1_postreg_c_pulses, fs1_postreg_start_pulses, modee_c_pulses, modee_start_pulses))
record(lines, string.format("final CurSaveSlot=$%02X active=%02X/%02X/%02X",
    ram_u8(0xFF0016), ram_u8(0xFF0633), ram_u8(0xFF0634), ram_u8(0xFF0635)))
record(lines, string.format("mode3_sub8_max_streak: %d", mode3_sub8_max_streak))
record(lines, string.format("final bank window: mmc1PRG=$%02X curBank=$%02X win=%s",
    final_snap.mmc1_prg, final_snap.current_window_bank, bank_bytes_hex(final_snap.bytes)))
record(lines, "")

local pass = 0
local total = 0

total = total + 1
pass = pass + verdict("T30_NO_EXCEPTION", not exception_hit,
    exception_hit and (exception_name .. " at frame " .. tostring(exception_frame)) or "no exception")

total = total + 1
pass = pass + verdict("T30_BANK_WINDOW_LOADED", window_loaded_in_mode23,
    window_loaded_in_mode23
        and ("first loaded in Mode2/3 at frame " .. tostring(first_window_loaded_frame))
        or string.format(
            "never loaded in Mode2/3 (final mmc1PRG=$%02X curBank=$%02X win=%s)",
            final_snap.mmc1_prg, final_snap.current_window_bank, bank_bytes_hex(final_snap.bytes)
        ))

total = total + 1
pass = pass + verdict("T30_REACHED_MODE3_SUB8", first_mode3_sub8 ~= nil,
    first_mode3_sub8 and ("first at frame " .. tostring(first_mode3_sub8)) or "never observed")

total = total + 1
pass = pass + verdict("T30_LEFT_MODE3_SUB8", first_mode3_sub8 ~= nil and left_mode3_sub8,
    left_mode3_sub8 and "progressed past submode 8" or "stayed in submode 8 too long")

total = total + 1
pass = pass + verdict("T30_REACHED_MODE5", saw_mode5,
    saw_mode5 and "Mode 5 observed" or "Mode 5 never observed")

total = total + 1
pass = pass + verdict("T30_ROOM77_OBSERVED", saw_room77,
    saw_room77 and "room $77 observed" or "room $77 not observed")

total = total + 1
pass = pass + verdict("T31_SCREENSHOT_CAPTURED", screenshot_done,
    screenshot_done and string.format("mode5 screenshot captured (room=$%02X)", screenshot_room or 0x00)
        or "mode5 screenshot not captured")

total = total + 1
pass = pass + verdict("T32_RAM_DUMP_WRITTEN", wrote_ram,
    wrote_ram and "RAM dump written" or "failed to write RAM dump")

record(lines, "")
record(lines, string.format("T30/T31/T32 SUMMARY: %d PASS / %d FAIL", pass, total - pass))
record(lines, (pass == total) and "T30/T31/T32: ALL PASS" or "T30/T31/T32: FAIL")

local out = assert(io.open(OUT_TXT, "w"))
out:write(table.concat(lines, "\n"))
out:write("\n")
out:close()
client.exit()
