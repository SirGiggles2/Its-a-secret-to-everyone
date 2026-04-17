-- bizhawk_t38_enemy_nes_capture.lua
-- T35 NES reference trace: drive Link west out of room $77 across the left
-- screen-scroll transition into room $76, recording per-frame room_id, mode,
-- submode, ObjX/Y/dir, HeldButtons, CurHScroll/CurVScroll. Paired with
-- bizhawk_T38_cave_gen_capture.lua for byte-parity comparison by
-- tools/compare_T38_cave_parity.py.
--
-- Outputs:
--   builds/reports/t38_enemy_nes_capture.txt
--   builds/reports/t38_enemy_nes_capture.json
--   builds/reports/t38_enemy_nes_capture.png

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

local SCENARIO = dofile(repo_path("tools\\t38_input_scenario.lua"))

local OUT_TXT  = repo_path("builds\\reports\\t38_enemy_nes_capture.txt")
local OUT_JSON = repo_path("builds\\reports\\t38_enemy_nes_capture.json")
local OUT_PNG  = repo_path("builds\\reports\\t38_enemy_nes_capture.png")

-- T39 render-classification: NES reference screenshots matching Gen shots.
-- T38 phase 1: spawn-in-$76 capture (720-frame budget).
local T39_SHOTS = {
    { t = 40,  png = repo_path("builds\\reports\\t38_nes_pre.png") },
    { t = 300, png = repo_path("builds\\reports\\t38_nes_in76.png") },
    { t = 500, png = repo_path("builds\\reports\\t38_nes_spawn.png") },
    { t = 700, png = repo_path("builds\\reports\\t38_nes_observe.png") },
}
local t39_done = {}

local MAX_FRAMES = 8000
local MODE0_BOOT_TIMEOUT = 1200
local TARGET_NAME_PROGRESS = 5
local LINK_STABLE_FRAMES = 60
local TARGET_ROOM_ID = 0x77

-- NES RAM addresses
local ADDR_FRAME_CTR = 0x0015
local ADDR_MODE     = 0x0012
local ADDR_SUBMODE  = 0x0013
local ADDR_CUR_SLOT = 0x0016
local ADDR_OBJ_X    = 0x0070
local ADDR_OBJ_XF   = 0x0071
local ADDR_OBJ_Y    = 0x0084
local ADDR_OBJ_YF   = 0x0085
local ADDR_ROOM_ID  = 0x00EB
local ADDR_CUR_COL  = 0x00E8
local ADDR_CUR_ROW  = 0x00E9
local ADDR_CUR_VSCROLL = 0x00FC
local ADDR_CUR_HSCROLL = 0x00FD
local ADDR_CUR_PPUMASK = 0x00FE
local ADDR_HELD     = 0x00F8
local ADDR_PREV_HELD = 0x00FA
local ADDR_OBJ_DIR  = 0x03F8
local ADDR_OBJSTATE = 0x00AC  -- ObjState[0] (Link state high-nibble gates movement)
local ADDR_MOVEDIR  = 0x000F  -- moving direction (zeroed by Walker_Move item-state branch)
local ADDR_FACEDIR  = 0x0098  -- facing direction
local ADDR_PERSONSTATE = 0x00AD
local ADDR_CAVETYPE    = 0x0350
local ADDR_OBJTIMER0   = 0x0029
local ADDR_AUTOWALK    = 0x0394
local ADDR_OBJ_TEMPL   = 0x0002
local ADDR_LVL_BLOCK   = 0x00EB
local ADDR_ROOM_FLAGS  = 0x04CD
local ADDR_CAVE_TMPL   = 0x034E
local ADDR_SLOT_A0  = 0x0633
local ADDR_SLOT_A1  = 0x0634
local ADDR_SLOT_A2  = 0x0635
local ADDR_NAME_OFS = 0x0421
-- T38: inventory array at $0657. Slot 0 = sword level (0=none, 1=wood, 2=white, 3=magic).
local ADDR_INV_SWORD = 0x0657

-- T38 enemy slots. Zelda uses 9 object slots (0=Link, 1..8=enemies/other).
-- ObjType[N] = $34F+N, ObjX[N] = $70+N, ObjY[N] = $84+N, ObjDir[N] = $98+N.
local ENEMY_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8 }

local FLOW_BOOT_TO_FS1       = "BOOT_TO_FS1"
local FLOW_FS1_SELECT_REG    = "FS1_SELECT_REGISTER"
local FLOW_FS1_ENTER_REG     = "FS1_ENTER_REGISTER"
local FLOW_MODEE_TYPE_NAME   = "MODEE_TYPE_NAME"
local FLOW_MODEE_FINISH      = "MODEE_FINISH"
local FLOW_WAIT_GAMEPLAY     = "WAIT_GAMEPLAY"
local FLOW_FS1_START_GAME    = "FS1_START_GAME"
local FLOW_T38_STABILIZE     = "T38_STABILIZE"
local FLOW_T38_CAPTURE       = "T38_CAPTURE"
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
    t0_frame          = -1,
    baseline_x        = nil,
    baseline_y        = nil,
    baseline_dir      = nil,
    baseline_hscroll  = nil,
    baseline_vscroll  = nil,
    baseline_room     = nil,
    stable_count      = 0,
    stable_prev_x     = nil,
    stable_prev_y     = nil,
    name_progress_events = 0,
    last_name_offset  = 0,
    trace             = {},
    ended_naturally   = false,
}

record("=================================================================")
record("T36 NES capture: cave-enter from room $76")
record("=================================================================")
record(string.format("SCENARIO_LENGTH=%d", SCENARIO.SCENARIO_LENGTH))

-- ---------------------------------------------------------------------------
-- NES bus-write watcher: log $0098 (facedir), $00AC (objstate), $000F (movedir)
-- during mode $0B. Captures 6502 PC for each hit.
-- ---------------------------------------------------------------------------
local NES_BP_LOG = repo_path("builds\\reports\\T38_cave_nes_statewrite.txt")
local nbp_lines = {}
local nbp_count = 0
local NBP_MAX = 4000
local function nbp_write(s)
    if nbp_count >= NBP_MAX then return end
    nbp_count = nbp_count + 1
    nbp_lines[#nbp_lines + 1] = s
    local f = io.open(NES_BP_LOG, "w")
    if f then f:write(table.concat(nbp_lines, "\n") .. "\n"); f:close() end
end
local nbp_current_frame = 0
local nbp_t0 = -1
local function nbp_make(label)
    return function(a, v, flags)
        local m = ram_u8(ADDR_MODE)
        if m ~= 0x0B and m ~= 0x10 and m ~= 0x05 then return end
        local pc = 0
        local ok, regs = pcall(function() return emu.getregisters() end)
        if ok and regs then pc = regs["PC"] or regs["6502 PC"] or regs["A"] or 0 end
        local t = (nbp_t0 >= 0) and (nbp_current_frame - nbp_t0) or -1
        nbp_write(string.format("WR f=%d t=%d %s val=%02X PC=%04X mode=%02X y=%02X",
            nbp_current_frame, t, label, v or -1, pc, m, ram_u8(ADDR_OBJ_Y)))
    end
end
do
    local dlist = {}
    local okl, lst = pcall(memory.getmemorydomainlist)
    if okl and type(lst) == "table" then for _, n in ipairs(lst) do dlist[#dlist+1] = n end end
    nbp_write("NES domains: " .. table.concat(dlist, ","))
end
local nbp_installed = false
for _, dn in ipairs({"System Bus", "RAM", "WRAM", "Main RAM"}) do
    if AVAILABLE_DOMAINS[dn] and not nbp_installed then
        local ok = pcall(function()
            event.on_bus_write(nbp_make("facedir "), 0x0098, dn)
            event.on_bus_write(nbp_make("objstate"), 0x00AC, dn)
            event.on_bus_write(nbp_make("movedir "), 0x000F, dn)
            event.on_bus_write(nbp_make("cavetype"), 0x0350, dn)
        end)
        if ok then nbp_write("NES BP installed on "..dn); nbp_installed = true end
    end
end
if not nbp_installed then nbp_write("NES BP FAILED to install") end
-- Also install via legacy memory.registerwrite (quickerNES compatibility)
do
    local ok2 = pcall(function()
        memory.registerwrite(0x0350, 1, nbp_make("cavetype-rw"), "System Bus")
        memory.registerwrite(0x00AC, 1, nbp_make("objstate-rw"), "System Bus")
    end)
    nbp_write("NES legacy registerwrite: " .. tostring(ok2))
end

-- ---------------------------------------------------------------------------
-- T38 enemy-slot helpers (defined after record/ram_u8 so both resolve)
-- ---------------------------------------------------------------------------
-- Per aldonunez Variables.inc: flat arrays (not interleaved).
--   ObjType = $34F+N, ObjX = $70+N, ObjY = $84+N, ObjDir = $98+N,
--   ObjState = $AC+N, ObjPosFrac = $3A8+N, ObjHP = $485+N.
local function read_enemy_slot(n)
    return {
        id    = ram_u8(0x034F + n),
        x     = ram_u8(0x0070 + n),
        y     = ram_u8(0x0084 + n),
        dir   = ram_u8(0x0098 + n),
        state = ram_u8(0x00AC + n),
        xf    = ram_u8(0x03A8 + n),
        hp    = ram_u8(0x0485 + n),
    }
end

local function snapshot_enemies(label, t)
    local parts = { string.format("ENEMY_SNAP t=%d %s", t, label) }
    local any = false
    for _, n in ipairs(ENEMY_SLOTS) do
        local s = read_enemy_slot(n)
        if s.id ~= 0 then
            any = true
            parts[#parts + 1] = string.format(
                "slot%d id=$%02X x=$%02X y=$%02X dir=$%02X hp=$%02X state=$%02X",
                n, s.id, s.x, s.y, s.dir, s.hp, s.state)
        end
    end
    if not any then parts[#parts + 1] = "(no enemies)" end
    record(table.concat(parts, " | "))
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------
local last_heartbeat = 0
for frame = 1, MAX_FRAMES do
    nbp_current_frame = frame
    nbp_t0 = CAPTURE.t0_frame
    local mode     = ram_u8(ADDR_MODE)
    if frame - last_heartbeat >= 200 then
        last_heartbeat = frame
        record(string.format("HB f%04d flow=%s mode=$%02X sub=$%02X room=$%02X hsc=$%02X",
            frame, flow_state, mode, ram_u8(ADDR_SUBMODE), ram_u8(ADDR_ROOM_ID),
            ram_u8(ADDR_CUR_HSCROLL)))
    end
    local sub      = ram_u8(ADDR_SUBMODE)
    local room_id  = ram_u8(ADDR_ROOM_ID)
    local cur_slot = ram_u8(ADDR_CUR_SLOT)
    local name_ofs = ram_u8(ADDR_NAME_OFS)
    local slot_a0  = ram_u8(ADDR_SLOT_A0)
    local slot_a1  = ram_u8(ADDR_SLOT_A1)
    local slot_a2  = ram_u8(ADDR_SLOT_A2)

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
            CAPTURE.last_name_offset = name_ofs
        elseif mode == 0x01 then
            schedule_input("Start", 2, 14)
        end

    elseif flow_state == FLOW_MODEE_TYPE_NAME then
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
            set_flow(FLOW_T38_STABILIZE, frame, "left Mode1 (gameplay starting)")
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

    elseif flow_state == FLOW_T38_STABILIZE then
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
            -- Gate T=0 on both Link stability AND $0015 & 3 == 0.
            -- Stair-descent cadence (mode $10) fires every 4 frames gated by
            -- (FrameCounter & 3 == 0).  NES and Gen boot times differ
            -- by 270 NMIs â†’ $0015 & 3 phase differs by 2 at Link-stable.
            -- Pinning T=0 to phase 0 on both sides aligns stair-step frames
            -- exactly and removes the 1px-y drift that was the residual
            -- failure of T38_CAVE_INTERIOR_MATCH / T38_ROUND_TRIP_READY.
            local frame_ctr = ram_u8(ADDR_FRAME_CTR)
            if CAPTURE.stable_count >= LINK_STABLE_FRAMES
               and (frame_ctr % 4) == 0 then
                CAPTURE.t0_frame = frame
                CAPTURE.baseline_x = obj_x
                CAPTURE.baseline_y = obj_y
                CAPTURE.baseline_dir = ram_u8(ADDR_OBJ_DIR)
                CAPTURE.baseline_hscroll = ram_u8(ADDR_CUR_HSCROLL)
                CAPTURE.baseline_vscroll = ram_u8(ADDR_CUR_VSCROLL)
                CAPTURE.baseline_room = room_id
                record(string.format("f%04d T=0 baseline x=$%02X y=$%02X dir=$%02X hsc=$%02X vsc=$%02X room=$%02X frame_ctr=$%02X",
                    frame, obj_x, obj_y, CAPTURE.baseline_dir,
                    CAPTURE.baseline_hscroll, CAPTURE.baseline_vscroll, room_id, frame_ctr))
                set_flow(FLOW_T38_CAPTURE, frame, "T35 capture window open")
                CAPTURE.trace[#CAPTURE.trace + 1] = {
                    t = 0,
                    obj_x = obj_x, obj_xf = ram_u8(ADDR_OBJ_XF),
                    obj_y = obj_y, obj_yf = ram_u8(ADDR_OBJ_YF),
                    obj_dir = CAPTURE.baseline_dir,
                    held = ram_u8(ADDR_HELD), prev_held = ram_u8(ADDR_PREV_HELD),
                    mode = mode, sub = sub, room = room_id,
                    hscroll = CAPTURE.baseline_hscroll,
                    vscroll = CAPTURE.baseline_vscroll,
                    cur_col = ram_u8(ADDR_CUR_COL),
                    cur_row = ram_u8(ADDR_CUR_ROW),
                    ppumask = ram_u8(ADDR_CUR_PPUMASK),
                    objstate = ram_u8(ADDR_OBJSTATE),
                    movedir = ram_u8(ADDR_MOVEDIR),
                    facedir = ram_u8(ADDR_FACEDIR),
                    personstate = ram_u8(ADDR_PERSONSTATE),
                    cavetype = ram_u8(ADDR_CAVETYPE),
                    objtimer0 = ram_u8(ADDR_OBJTIMER0),
                    autowalk = ram_u8(ADDR_AUTOWALK),
                    obj_templ = ram_u8(ADDR_OBJ_TEMPL),
                    lvl_block = ram_u8(ADDR_LVL_BLOCK),
                    room_flags = ram_u8(ADDR_ROOM_FLAGS),
                    cave_tmpl = ram_u8(ADDR_CAVE_TMPL),
                    sram_0975 = ram_u8(0x6975),
                }
            end
        else
            CAPTURE.stable_count = 0
        end

    elseif flow_state == FLOW_T38_CAPTURE then
        local t = frame - CAPTURE.t0_frame
        if t < 0 or t >= SCENARIO.SCENARIO_LENGTH then
            set_flow(FLOW_DONE, frame, "capture complete")
            CAPTURE.ended_naturally = true
            break
        end
        for _, shot in ipairs(T39_SHOTS) do
            if t == shot.t and not t39_done[shot.t] then
                t39_done[shot.t] = true
                pcall(function() client.screenshot(shot.png) end)
                record(string.format("f%04d T39_SHOT t=%d png=%s", frame, t, shot.png))
            end
        end
        -- T38: log Link pose + enemy-slot snapshot at key points through the
        -- walk_left -> $76 -> observe sequence.
        if t == 60 or t == 240 or t == 300 or t == 420 or t == 500
           or t == 600 or t == 700 then
            record(string.format("LINK t=%d x=$%02X.%02X y=$%02X.%02X dir=$%02X room=$%02X mode=$%02X sub=$%02X",
                t, ram_u8(ADDR_OBJ_X), ram_u8(ADDR_OBJ_XF),
                ram_u8(ADDR_OBJ_Y), ram_u8(ADDR_OBJ_YF),
                ram_u8(ADDR_OBJ_DIR), room_id, mode, sub))
            snapshot_enemies("t="..t, t)
        end
        CAPTURE.trace[#CAPTURE.trace + 1] = {
            t = t,
            obj_x = ram_u8(ADDR_OBJ_X), obj_xf = ram_u8(ADDR_OBJ_XF),
            obj_y = ram_u8(ADDR_OBJ_Y), obj_yf = ram_u8(ADDR_OBJ_YF),
            obj_dir = ram_u8(ADDR_OBJ_DIR),
            held = ram_u8(ADDR_HELD), prev_held = ram_u8(ADDR_PREV_HELD),
            mode = mode, sub = sub, room = room_id,
            hscroll = ram_u8(ADDR_CUR_HSCROLL),
            vscroll = ram_u8(ADDR_CUR_VSCROLL),
            cur_col = ram_u8(ADDR_CUR_COL),
            cur_row = ram_u8(ADDR_CUR_ROW),
            ppumask = ram_u8(ADDR_CUR_PPUMASK),
            objstate = ram_u8(ADDR_OBJSTATE),
            movedir = ram_u8(ADDR_MOVEDIR),
            facedir = ram_u8(ADDR_FACEDIR),
            inv_sword = ram_u8(ADDR_INV_SWORD),  -- T38: sword inventory slot
            cavetype = ram_u8(ADDR_CAVETYPE),    -- T38: cave-person spawn template
        }
    end

    local pad
    if flow_state == FLOW_T38_CAPTURE then
        pad = SCENARIO.get_input_for_relative_frame(frame - CAPTURE.t0_frame)
    else
        pad = build_boot_pad()
    end
    safe_set(pad)
    emu.frameadvance()
end

pcall(function() client.screenshot(OUT_PNG) end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
local trace = CAPTURE.trace
local trace_len = #trace

record(string.format("TRACE_LENGTH=%d (expected %d)", trace_len, SCENARIO.SCENARIO_LENGTH))
record(string.format("REACHED_MODE5=%s", CAPTURE.reached_mode5 and "true" or "false"))
record(string.format("T0_FRAME=%d", CAPTURE.t0_frame))
if trace_len > 0 then
    local last = trace[trace_len]
    record(string.format("FINAL t=%d x=$%02X.%02X y=$%02X.%02X dir=$%02X room=$%02X mode=$%02X sub=$%02X hsc=$%02X vsc=$%02X",
        last.t, last.obj_x, last.obj_xf, last.obj_y, last.obj_yf,
        last.obj_dir, last.room, last.mode, last.sub, last.hscroll, last.vscroll))
end

-- ---------------------------------------------------------------------------
-- JSON output
-- ---------------------------------------------------------------------------
local function build_json()
    local cols = {
        t = {}, obj_x = {}, obj_xf = {}, obj_y = {}, obj_yf = {},
        obj_dir = {}, held = {}, prev_held = {},
        mode = {}, sub = {}, room = {},
        hscroll = {}, vscroll = {},
        cur_col = {}, cur_row = {}, ppumask = {},
        objstate = {}, movedir = {}, facedir = {},
        personstate = {}, cavetype = {}, objtimer0 = {}, autowalk = {},
        obj_templ = {}, lvl_block = {}, room_flags = {}, cave_tmpl = {},
        sram_0975 = {},
        inv_sword = {},
    }
    for i = 1, trace_len do
        local e = trace[i]
        cols.t[i]         = e.t
        cols.obj_x[i]     = e.obj_x
        cols.obj_xf[i]    = e.obj_xf
        cols.obj_y[i]     = e.obj_y
        cols.obj_yf[i]    = e.obj_yf
        cols.obj_dir[i]   = e.obj_dir
        cols.held[i]      = e.held
        cols.prev_held[i] = e.prev_held or 0
        cols.mode[i]      = e.mode
        cols.sub[i]       = e.sub
        cols.room[i]      = e.room
        cols.hscroll[i]   = e.hscroll
        cols.vscroll[i]   = e.vscroll
        cols.cur_col[i]   = e.cur_col
        cols.cur_row[i]   = e.cur_row
        cols.ppumask[i]   = e.ppumask
        cols.objstate[i]  = e.objstate or 0
        cols.movedir[i]   = e.movedir or 0
        cols.facedir[i]   = e.facedir or 0
        cols.personstate[i] = e.personstate or 0
        cols.cavetype[i]    = e.cavetype or 0
        cols.objtimer0[i]   = e.objtimer0 or 0
        cols.autowalk[i]    = e.autowalk or 0
        cols.obj_templ[i]   = e.obj_templ or 0
        cols.lvl_block[i]   = e.lvl_block or 0
        cols.room_flags[i]  = e.room_flags or 0
        cols.cave_tmpl[i]   = e.cave_tmpl or 0
        cols.sram_0975[i]   = e.sram_0975 or 0
        cols.inv_sword[i]   = e.inv_sword or 0
    end
    local phase_parts = {}
    for i, p in ipairs(SCENARIO.phase_summary()) do
        phase_parts[i] = string.format(
            '{"name":"%s","button":%s,"start_t":%d,"end_t":%d}',
            p.name, p.button and ('"' .. p.button .. '"') or "null",
            p.start_t, p.end_t)
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
        '"obj_dir":' .. (CAPTURE.baseline_dir or -1) .. ",",
        '"hscroll":' .. (CAPTURE.baseline_hscroll or -1) .. ",",
        '"vscroll":' .. (CAPTURE.baseline_vscroll or -1) .. ",",
        '"room":' .. (CAPTURE.baseline_room or -1),
        "},",
        '"phases":[' .. table.concat(phase_parts, ",") .. "],",
        '"trace":{',
        '"t":'         .. json_num_array(cols.t)         .. ",",
        '"obj_x":'     .. json_num_array(cols.obj_x)     .. ",",
        '"obj_xf":'    .. json_num_array(cols.obj_xf)    .. ",",
        '"obj_y":'     .. json_num_array(cols.obj_y)     .. ",",
        '"obj_yf":'    .. json_num_array(cols.obj_yf)    .. ",",
        '"obj_dir":'   .. json_num_array(cols.obj_dir)   .. ",",
        '"held":'      .. json_num_array(cols.held)      .. ",",
        '"prev_held":' .. json_num_array(cols.prev_held) .. ",",
        '"mode":'      .. json_num_array(cols.mode)      .. ",",
        '"sub":'       .. json_num_array(cols.sub)       .. ",",
        '"room":'      .. json_num_array(cols.room)      .. ",",
        '"hscroll":'   .. json_num_array(cols.hscroll)   .. ",",
        '"vscroll":'   .. json_num_array(cols.vscroll)   .. ",",
        '"cur_col":'   .. json_num_array(cols.cur_col)   .. ",",
        '"cur_row":'   .. json_num_array(cols.cur_row)   .. ",",
        '"ppumask":'   .. json_num_array(cols.ppumask) .. ",",
        '"objstate":'  .. json_num_array(cols.objstate) .. ",",
        '"movedir":'   .. json_num_array(cols.movedir) .. ",",
        '"facedir":'   .. json_num_array(cols.facedir) .. ",",
        '"personstate":' .. json_num_array(cols.personstate) .. ",",
        '"cavetype":'    .. json_num_array(cols.cavetype) .. ",",
        '"objtimer0":'   .. json_num_array(cols.objtimer0) .. ",",
        '"autowalk":'    .. json_num_array(cols.autowalk) .. ",",
        '"obj_templ":'   .. json_num_array(cols.obj_templ) .. ",",
        '"lvl_block":'   .. json_num_array(cols.lvl_block) .. ",",
        '"room_flags":'  .. json_num_array(cols.room_flags) .. ",",
        '"cave_tmpl":'   .. json_num_array(cols.cave_tmpl) .. ",",
        '"sram_0975":'   .. json_num_array(cols.sram_0975) .. ",",
        '"inv_sword":'   .. json_num_array(cols.inv_sword),
        "}",
        "}",
    }, "\n")
end

write_file(OUT_TXT, table.concat(lines, "\n") .. "\n")
write_file(OUT_JSON, build_json())

local verdict = (trace_len == SCENARIO.SCENARIO_LENGTH) and "T38_NES_CAPTURE: OK" or "T38_NES_CAPTURE: FAIL"
record(verdict)
write_file(OUT_TXT, table.concat(lines, "\n") .. "\n")

pcall(function() client.exit() end)
pcall(function() client.pause() end)
