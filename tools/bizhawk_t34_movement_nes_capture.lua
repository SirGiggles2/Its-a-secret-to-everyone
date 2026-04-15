-- bizhawk_t34_movement_nes_capture.lua
-- T34 NES reference trace: drive Link through a scripted D-pad square walk
-- inside room $77 and record per-frame (ObjX, ObjXFrac, ObjY, ObjYFrac,
-- ObjInputDir, HeldButtons). Paired with bizhawk_t34_movement_gen_capture.lua
-- for byte-for-byte parity comparison by tools/compare_t34_movement_parity.py.
--
-- Outputs:
--   builds/reports/t34_movement_nes_capture.txt
--   builds/reports/t34_movement_nes_capture.json
--   builds/reports/t34_movement_nes_capture.png

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

local SCENARIO = dofile(repo_path("tools\\t34_input_scenario.lua"))

local OUT_TXT  = repo_path("builds\\reports\\t34_movement_nes_capture.txt")
local OUT_JSON = repo_path("builds\\reports\\t34_movement_nes_capture.json")
local OUT_PNG  = repo_path("builds\\reports\\t34_movement_nes_capture.png")

local MAX_FRAMES = 7000
local MODE0_BOOT_TIMEOUT = 1200
local TARGET_NAME_PROGRESS = 5
local MODE5_STABLE_FRAMES = 10
local LINK_STABLE_FRAMES = 60
local TARGET_ROOM_ID = 0x77

-- NES RAM addresses
local ADDR_MODE     = 0x0012
local ADDR_SUBMODE  = 0x0013
local ADDR_OBJ_X    = 0x0070
local ADDR_OBJ_XF   = 0x0071
local ADDR_OBJ_Y    = 0x0084
local ADDR_OBJ_YF   = 0x0085
local ADDR_HELD     = 0x00F8
local ADDR_ROOM_ID  = 0x00EB
local ADDR_OBJ_DIR  = 0x03F8
local ADDR_CUR_SLOT = 0x0016
local ADDR_SLOT_A0  = 0x0633
local ADDR_SLOT_A1  = 0x0634
local ADDR_SLOT_A2  = 0x0635
local ADDR_NAME_OFS = 0x0421

local FLOW_BOOT_TO_FS1       = "BOOT_TO_FS1"
local FLOW_FS1_SELECT_REG    = "FS1_SELECT_REGISTER"
local FLOW_FS1_ENTER_REG     = "FS1_ENTER_REGISTER"
local FLOW_MODEE_TYPE_NAME   = "MODEE_TYPE_NAME"
local FLOW_MODEE_FINISH      = "MODEE_FINISH"
local FLOW_WAIT_GAMEPLAY     = "WAIT_GAMEPLAY"
local FLOW_FS1_START_GAME    = "FS1_START_GAME"
local FLOW_T34_STABILIZE     = "T34_STABILIZE"
local FLOW_T34_CAPTURE       = "T34_CAPTURE"
local FLOW_DONE              = "DONE"

-- ---------------------------------------------------------------------------
-- Memory helpers
-- ---------------------------------------------------------------------------
local AVAILABLE_DOMAINS = {}
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and type(domains) == "table" then
        for _, name in ipairs(domains) do AVAILABLE_DOMAINS[name] = true end
    end
end

local function domain_ok(name) return AVAILABLE_DOMAINS[name] == true end

-- Wipe SRAM so no saved game auto-boots; reboot so game re-reads empty SRAM.
-- Guard: only reboot if SRAM had non-zero bytes (prevents loop after reboot).
do
    local needs_reboot = false
    for _, dn in ipairs({"SRAM", "Cart (Save) RAM", "Save RAM", "Battery RAM", "CartRAM"}) do
        if domain_ok(dn) then
            pcall(function()
                memory.usememorydomain(dn)
                local sz = memory.getmemorydomainsize(dn)
                local any_nonzero = false
                for a = 0, sz - 1 do
                    if memory.readbyte(a) ~= 0 then any_nonzero = true end
                    memory.writebyte(a, 0)
                end
                if any_nonzero then needs_reboot = true end
            end)
        end
    end
    if needs_reboot then pcall(function() client.reboot_core() end) end
end

local function try_read(domain, addr)
    if not domain_ok(domain) then return nil end
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local function ram_u8(addr)
    local cpu = addr % 0x10000
    local candidates = {"System Bus", "CPU Bus", "RAM", "Main RAM", "WRAM"}
    for i = 1, #candidates do
        local read_addr = cpu
        if candidates[i] ~= "System Bus" and candidates[i] ~= "CPU Bus" and cpu < 0x2000 then
            read_addr = cpu % 0x0800
        end
        local v = try_read(candidates[i], read_addr)
        if v ~= nil then return v end
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- Input helpers
-- ---------------------------------------------------------------------------
local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end

local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 0 }

local function schedule_input(button, hold_frames, release_frames)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return false end
    input_state.button = button
    input_state.hold_left = hold_frames or 1
    input_state.release_left = 0
    input_state.release_after = release_frames or 8
    return true
end

local function build_boot_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

-- ---------------------------------------------------------------------------
-- Output helpers
-- ---------------------------------------------------------------------------
local lines = {}
local function record(text)
    lines[#lines + 1] = text
    print(text)
    local f = io.open(OUT_TXT, "w")
    if f then f:write(table.concat(lines, "\n") .. "\n"); f:close() end
end

local function write_file(path, text)
    local f, err = io.open(path, "w")
    if not f then
        print("ERROR open " .. path .. ": " .. tostring(err))
        return
    end
    f:write(text)
    f:close()
end

local function json_num_array(v)
    local parts = {}
    for i = 1, #v do parts[#parts + 1] = tostring(v[i]) end
    return "[" .. table.concat(parts, ",") .. "]"
end

-- ---------------------------------------------------------------------------
-- Capture state
-- ---------------------------------------------------------------------------
local flow_state = FLOW_BOOT_TO_FS1
local function set_flow(next_state, frame, reason)
    if flow_state == next_state then return end
    record(string.format("f%04d flow %s -> %s (%s)", frame, flow_state, next_state, reason or ""))
    flow_state = next_state
end

local CAPTURE = {
    reached_mode5     = false,
    reached_mode5_frame = -1,
    stable_start_frame = -1,
    t0_frame          = -1,
    baseline_x        = nil,
    baseline_y        = nil,
    baseline_dir      = nil,
    stable_count      = 0,
    stable_prev_x     = nil,
    stable_prev_y     = nil,
    register_seen     = false,
    name_progress_events = 0,
    last_name_offset  = 0,
    trace             = {},  -- [{t, obj_x, obj_xf, obj_y, obj_yf, obj_dir, held}]
    ended_naturally   = false,
}

record("=================================================================")
record("T34 NES capture: room $77 Link movement reference trace")
record("=================================================================")
record(string.format("SCENARIO_LENGTH=%d", SCENARIO.SCENARIO_LENGTH))

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------
local last_heartbeat = 0
for frame = 1, MAX_FRAMES do
    local mode     = ram_u8(ADDR_MODE)
    if frame - last_heartbeat >= 200 then
        last_heartbeat = frame
        record(string.format("HB f%04d flow=%s mode=$%02X sub=$%02X room=$%02X slot=$%02X",
            frame, flow_state, mode, ram_u8(ADDR_SUBMODE), ram_u8(ADDR_ROOM_ID), ram_u8(ADDR_CUR_SLOT)))
    end
    local sub      = ram_u8(ADDR_SUBMODE)
    local room_id  = ram_u8(ADDR_ROOM_ID)
    local cur_slot = ram_u8(ADDR_CUR_SLOT)
    local name_ofs = ram_u8(ADDR_NAME_OFS)
    local slot_a0  = ram_u8(ADDR_SLOT_A0)
    local slot_a1  = ram_u8(ADDR_SLOT_A1)
    local slot_a2  = ram_u8(ADDR_SLOT_A2)

    -- T34 fresh-register flow: shortcut removed. Every run wipes SRAM at init
    -- and drives full title->FS1->register-name->FS2->start-game path so Link
    -- spawn state ($71/$85 frac bytes, $F8/$FA controller prev-held) matches
    -- between NES and Gen via identical code path (no stale save residue).

    if flow_state == FLOW_BOOT_TO_FS1 then
        if mode == 0x01 then
            set_flow(FLOW_FS1_SELECT_REG, frame, "entered Mode1")
        elseif frame > MODE0_BOOT_TIMEOUT then
            record(string.format("f%04d timeout waiting for Mode1 (mode=$%02X)", frame, mode))
            break
        else
            schedule_input("Start", 2, 3)
        end

    elseif flow_state == FLOW_FS1_SELECT_REG then
        if mode == 0x01 then
            if cur_slot == 0x03 then
                set_flow(FLOW_FS1_ENTER_REG, frame, "CurSaveSlot reached 3")
            else
                schedule_input("Down", 1, 10)
            end
        end

    elseif flow_state == FLOW_FS1_ENTER_REG then
        if mode == 0x0E then
            set_flow(FLOW_MODEE_TYPE_NAME, frame, "entered ModeE")
            CAPTURE.register_seen = true
            CAPTURE.last_name_offset = name_ofs
        elseif mode == 0x01 then
            schedule_input("Start", 2, 14)
        end

    elseif flow_state == FLOW_MODEE_TYPE_NAME then
        CAPTURE.register_seen = true
        if name_ofs ~= CAPTURE.last_name_offset then
            CAPTURE.name_progress_events = CAPTURE.name_progress_events + 1
            CAPTURE.last_name_offset = name_ofs
        end
        if CAPTURE.name_progress_events >= TARGET_NAME_PROGRESS then
            set_flow(FLOW_MODEE_FINISH, frame, "name progress target reached")
        else
            schedule_input("A", 1, 10)
        end

    elseif flow_state == FLOW_MODEE_FINISH then
        if mode ~= 0x0E then
            set_flow(FLOW_WAIT_GAMEPLAY, frame, "left ModeE")
        else
            if cur_slot ~= 0x03 then
                schedule_input("Select", 1, 10)
            else
                schedule_input("Start", 2, 14)
            end
        end

    elseif flow_state == FLOW_WAIT_GAMEPLAY then
        if mode == 0x01 then
            set_flow(FLOW_FS1_START_GAME, frame, "back to Mode1 after register")
        end

    elseif flow_state == FLOW_FS1_START_GAME then
        if mode ~= 0x01 then
            set_flow(FLOW_T34_STABILIZE, frame, "left Mode1 (gameplay starting)")
        else
            local target_slot = 0x00
            if slot_a0 == 0 and slot_a1 ~= 0 then
                target_slot = 0x01
            elseif slot_a0 == 0 and slot_a1 == 0 and slot_a2 ~= 0 then
                target_slot = 0x02
            end
            if cur_slot ~= target_slot then
                schedule_input(target_slot > cur_slot and "Down" or "Up", 1, 10)
            else
                schedule_input("Start", 2, 14)
            end
        end

    elseif flow_state == FLOW_T34_STABILIZE then
        if mode == 0x05 and room_id == TARGET_ROOM_ID then
            if not CAPTURE.reached_mode5 then
                CAPTURE.reached_mode5 = true
                CAPTURE.reached_mode5_frame = frame
                record(string.format("f%04d reached Mode5 room $%02X", frame, room_id))
            end
            local obj_x = ram_u8(ADDR_OBJ_X)
            local obj_y = ram_u8(ADDR_OBJ_Y)
            if CAPTURE.stable_prev_x == obj_x and CAPTURE.stable_prev_y == obj_y then
                CAPTURE.stable_count = CAPTURE.stable_count + 1
            else
                CAPTURE.stable_count = 0
                CAPTURE.stable_prev_x = obj_x
                CAPTURE.stable_prev_y = obj_y
            end
            if CAPTURE.stable_count >= LINK_STABLE_FRAMES then
                CAPTURE.t0_frame = frame
                CAPTURE.baseline_x = obj_x
                CAPTURE.baseline_y = obj_y
                CAPTURE.baseline_dir = ram_u8(ADDR_OBJ_DIR)
                record(string.format("f%04d T=0 baseline x=$%02X y=$%02X dir=$%02X",
                    frame, obj_x, obj_y, CAPTURE.baseline_dir))
                set_flow(FLOW_T34_CAPTURE, frame, "T34 capture window open")
                CAPTURE.trace[#CAPTURE.trace + 1] = {
                    t = 0, obj_x = obj_x, obj_xf = ram_u8(ADDR_OBJ_XF),
                    obj_y = obj_y, obj_yf = ram_u8(ADDR_OBJ_YF),
                    obj_dir = CAPTURE.baseline_dir, held = ram_u8(ADDR_HELD),
                    mode = mode, sub = sub, room = room_id,
                }
            end
        else
            CAPTURE.stable_count = 0
        end

    elseif flow_state == FLOW_T34_CAPTURE then
        local t = frame - CAPTURE.t0_frame
        if t < 0 or t >= SCENARIO.SCENARIO_LENGTH then
            set_flow(FLOW_DONE, frame, "capture complete")
            CAPTURE.ended_naturally = true
            break
        end
        local obj_x  = ram_u8(ADDR_OBJ_X)
        local obj_xf = ram_u8(ADDR_OBJ_XF)
        local obj_y  = ram_u8(ADDR_OBJ_Y)
        local obj_yf = ram_u8(ADDR_OBJ_YF)
        local obj_dir = ram_u8(ADDR_OBJ_DIR)
        local held   = ram_u8(ADDR_HELD)
        CAPTURE.trace[#CAPTURE.trace + 1] = {
            t = t,
            obj_x = obj_x, obj_xf = obj_xf,
            obj_y = obj_y, obj_yf = obj_yf,
            obj_dir = obj_dir, held = held,
            mode = mode, sub = sub, room = room_id,
        }
    end

    -- Choose pad for the frame about to advance
    local pad
    if flow_state == FLOW_T34_CAPTURE then
        local t = frame - CAPTURE.t0_frame
        pad = SCENARIO.get_input_for_relative_frame(t)
    else
        pad = build_boot_pad()
    end
    safe_set(pad)
    emu.frameadvance()

    if mode == 0x05 and room_id == TARGET_ROOM_ID and flow_state == FLOW_T34_STABILIZE then
        -- stability loop continues on next iter
    end
end

-- Final screenshot (before cleanup)
pcall(function() client.screenshot(OUT_PNG) end)

-- ---------------------------------------------------------------------------
-- Final summary
-- ---------------------------------------------------------------------------
local trace = CAPTURE.trace
local trace_len = #trace

record(string.format("TRACE_LENGTH=%d (expected %d)", trace_len, SCENARIO.SCENARIO_LENGTH))
record(string.format("REACHED_MODE5=%s", CAPTURE.reached_mode5 and "true" or "false"))
record(string.format("T0_FRAME=%d", CAPTURE.t0_frame))
if trace_len > 0 then
    local last = trace[trace_len]
    record(string.format("FINAL t=%d x=$%02X.%02X y=$%02X.%02X dir=$%02X held=$%02X",
        last.t, last.obj_x, last.obj_xf, last.obj_y, last.obj_yf, last.obj_dir, last.held))
    if CAPTURE.baseline_x then
        record(string.format("BASELINE x=$%02X y=$%02X dir=$%02X",
            CAPTURE.baseline_x, CAPTURE.baseline_y, CAPTURE.baseline_dir))
    end
end

-- ---------------------------------------------------------------------------
-- JSON output
-- ---------------------------------------------------------------------------
local function build_json()
    local t_arr, x_arr, xf_arr, y_arr, yf_arr, dir_arr, held_arr = {}, {}, {}, {}, {}, {}, {}
    for i = 1, trace_len do
        local e = trace[i]
        t_arr[i]    = e.t
        x_arr[i]    = e.obj_x
        xf_arr[i]   = e.obj_xf
        y_arr[i]    = e.obj_y
        yf_arr[i]   = e.obj_yf
        dir_arr[i]  = e.obj_dir
        held_arr[i] = e.held
    end
    local phase_parts = {}
    local phases = SCENARIO.phase_summary()
    for i = 1, #phases do
        local p = phases[i]
        phase_parts[#phase_parts + 1] = string.format(
            '{"name":"%s","button":%s,"start_t":%d,"end_t":%d}',
            p.name, p.button and ('"' .. p.button .. '"') or "null",
            p.start_t, p.end_t
        )
    end
    return table.concat({
        "{",
        '"system":"NES",',
        '"scenario_length":' .. SCENARIO.SCENARIO_LENGTH .. ",",
        '"reached_mode5":' .. (CAPTURE.reached_mode5 and "true" or "false") .. ",",
        '"reached_mode5_frame":' .. CAPTURE.reached_mode5_frame .. ",",
        '"t0_frame":' .. CAPTURE.t0_frame .. ",",
        '"target_room_id":' .. TARGET_ROOM_ID .. ",",
        '"baseline":{',
        '"obj_x":' .. (CAPTURE.baseline_x or -1) .. ",",
        '"obj_y":' .. (CAPTURE.baseline_y or -1) .. ",",
        '"obj_dir":' .. (CAPTURE.baseline_dir or -1),
        "},",
        '"phases":[' .. table.concat(phase_parts, ",") .. "],",
        '"trace":{',
        '"t":'       .. json_num_array(t_arr)    .. ",",
        '"obj_x":'   .. json_num_array(x_arr)    .. ",",
        '"obj_xf":'  .. json_num_array(xf_arr)   .. ",",
        '"obj_y":'   .. json_num_array(y_arr)    .. ",",
        '"obj_yf":'  .. json_num_array(yf_arr)   .. ",",
        '"obj_dir":' .. json_num_array(dir_arr)  .. ",",
        '"held":'    .. json_num_array(held_arr),
        "}",
        "}",
    }, "\n")
end

write_file(OUT_TXT, table.concat(lines, "\n") .. "\n")
write_file(OUT_JSON, build_json())

local verdict = (trace_len == SCENARIO.SCENARIO_LENGTH) and "T34_NES_CAPTURE: OK" or "T34_NES_CAPTURE: FAIL"
record(verdict)
write_file(OUT_TXT, table.concat(lines, "\n") .. "\n")

-- Halt BizHawk
pcall(function() client.exit() end)
pcall(function() client.pause() end)
