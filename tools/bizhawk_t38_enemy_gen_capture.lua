-- bizhawk_t38_enemy_gen_capture.lua
-- T35 Genesis trace: mirror of bizhawk_T38_cave_nes_capture.lua on the
-- Genesis core. Drives Link west out of room $77 across the left screen-scroll
-- transition, reading NES-mirror addresses at $FF00xx plus Genesis-side VSRAM
-- shadow state (ACTIVE_BASE_VSRAM/ACTIVE_EVENT_VSRAM/STAGED_SCROLL_MODE).
-- Pairs with the NES capture for byte-parity comparison.
--
-- Outputs:
--   builds/reports/t38_enemy_gen_capture.txt
--   builds/reports/t38_enemy_gen_capture.json
--   builds/reports/t38_enemy_gen_capture.png

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

-- Optional recorded boot flow. If tools\bootflow_gen.txt exists, replay it
-- verbatim instead of the boot-flow state machine below. Recording is produced
-- by tools\bizhawk_record_bootflow.lua.
local REPLAY = nil
do
    local replay_mod = dofile(repo_path("tools\\bootflow_replay.lua"))
    local ok, r = pcall(replay_mod.load, repo_path("tools\\bootflow_gen.txt"), "GEN")
    if ok and r then REPLAY = r end
end

local OUT_TXT  = repo_path("builds\\reports\\t38_enemy_gen_capture.txt")
local OUT_JSON = repo_path("builds\\reports\\t38_enemy_gen_capture.json")
local OUT_PNG  = repo_path("builds\\reports\\t38_enemy_gen_capture.png")

-- T39 render-classification shot manifest. Helpers (t39_dump_nt /
-- t39_dump_vdp) live further down, after ram_u8 is declared.
-- T38 visual waypoints. Times match the sword-pickup scenario:
--   t=40   overworld pre-cave   t=400  cave interior pre-sword
--   t=600  cave w/ sword held   t=900  post-exit back on overworld
local T39_SHOTS = {
    { t = 40,  png = repo_path("builds\\reports\\t38_gen_pre.png"),
               nt  = repo_path("builds\\reports\\t38_nt_gen_pre.hex"),
               vdp = repo_path("builds\\reports\\t38_vdp_gen_pre.hex") },
    { t = 300, png = repo_path("builds\\reports\\t38_gen_in76.png"),
               nt  = repo_path("builds\\reports\\t38_nt_gen_in76.hex"),
               vdp = repo_path("builds\\reports\\t38_vdp_gen_in76.hex") },
    { t = 500, png = repo_path("builds\\reports\\t38_gen_spawn.png"),
               nt  = repo_path("builds\\reports\\t38_nt_gen_spawn.hex"),
               vdp = repo_path("builds\\reports\\t38_vdp_gen_spawn.hex") },
    { t = 700, png = repo_path("builds\\reports\\t38_gen_observe.png"),
               nt  = repo_path("builds\\reports\\t38_nt_gen_observe.hex"),
               vdp = repo_path("builds\\reports\\t38_vdp_gen_observe.hex") },
}
local T39_NT_BASE = 0xFF0840   -- NT_CACHE_BASE (960 bytes Plane A)
local T39_NT_LEN  = 960
local T39_PPUCTRL = 0xFF0804
local T39_PPUMASK = 0xFF0805
local t39_done = {}
local t39_dump_nt, t39_dump_vdp

local MAX_FRAMES = 8000
local MODE0_BOOT_TIMEOUT = 1200
local TARGET_NAME_PROGRESS = 5
local LINK_STABLE_FRAMES = 60
local TARGET_ROOM_ID = 0x77

-- NES-mirror bus addresses (A4 = $FF0000)
local BUS = 0xFF0000
local A_FRAME_CTR = BUS + 0x0015
local A_MODE     = BUS + 0x0012
local A_SUBMODE  = BUS + 0x0013
local A_CUR_SLOT = BUS + 0x0016
local A_OBJ_X    = BUS + 0x0070
local A_OBJ_XF   = BUS + 0x0071
local A_OBJ_Y    = BUS + 0x0084
local A_OBJ_YF   = BUS + 0x0085
local A_ROOM_ID  = BUS + 0x00EB
local A_CUR_COL  = BUS + 0x00E8
local A_CUR_ROW  = BUS + 0x00E9
local A_CUR_VSCROLL = BUS + 0x00FC
local A_CUR_HSCROLL = BUS + 0x00FD
local A_CUR_PPUMASK = BUS + 0x00FE
local A_HELD     = BUS + 0x00F8
local A_PREV_HELD = BUS + 0x00FA
local A_OBJ_DIR  = BUS + 0x03F8
local A_OBJSTATE = BUS + 0x00AC
local A_MOVEDIR  = BUS + 0x000F
local A_FACEDIR  = BUS + 0x0098
local A_PERSONSTATE = BUS + 0x00AD   -- cave-person state-machine
local A_CAVETYPE    = BUS + 0x0350   -- cave-person object type ($0350)
local A_OBJTIMER0   = BUS + 0x0029   -- Link ObjTimer (text advance gate)
local A_AUTOWALK    = BUS + 0x0394   -- auto-walk counter set to 48 on cave-enter
local A_OBJ_TEMPL   = BUS + 0x0002   -- object template type
local A_LVL_BLOCK   = BUS + 0x00EB   -- level block attribute index
local A_ROOM_FLAGS  = BUS + 0x04CD   -- level block attr byte F
local A_CAVE_TMPL   = BUS + 0x034E   -- obj template (cave-person selector)
local A_SRAM_68FE   = BUS + 0x68FE   -- PROBE: byte read by AssignObjSpawnPositions InCave
local A_SLOT_A0  = BUS + 0x0633
local A_SLOT_A1  = BUS + 0x0634
local A_SLOT_A2  = BUS + 0x0635
local A_NAME_OFS = BUS + 0x0421
-- T38: inventory array. Slot 0 = sword level (0=none, 1=wood, ...).
local A_INV_SWORD = BUS + 0x0657
local A_EXC_BASE = BUS + 0x0900
local EXC_BYTES  = 16

-- Genesis-side PPU/VSRAM shadow state (see src/nes_io.asm PPU/CHR state block)
local A_PPU_SCRL_X         = BUS + 0x0806  -- byte
local A_PPU_SCRL_Y         = BUS + 0x0807  -- byte
local A_STAGED_SCROLL_MODE = BUS + 0x080A  -- byte
local A_STAGED_HINT_CTR    = BUS + 0x080B  -- byte
local A_STAGED_BASE_VSRAM  = BUS + 0x080C  -- word
local A_STAGED_EVENT_VSRAM = BUS + 0x080E  -- word
local A_ACTIVE_BASE_VSRAM  = BUS + 0x0836  -- word
local A_ACTIVE_EVENT_VSRAM = BUS + 0x0838  -- word
local A_ACTIVE_HINT_CTR    = BUS + 0x083A  -- byte

-- T35 Stage B diag: Mode7 dispatch-gating bytes
local A_ISUPDATING_MODE    = BUS + 0x0011  -- byte (0=Update table, !=0=Init table)
local A_SECRET_COLOR_CYCLE = BUS + 0x051A  -- byte (InitMode7_Sub0 stall gate)
local A_WHIRL_STATE        = BUS + 0x0522  -- byte (InitMode7_Sub0 teleport gate)

local FLOW_REPLAY          = "REPLAY_BOOTFLOW"
local FLOW_BOOT_TO_FS1     = "BOOT_TO_FS1"
local FLOW_FS1_SELECT_REG  = "FS1_SELECT_REGISTER"
local FLOW_FS1_ENTER_REG   = "FS1_ENTER_REGISTER"
local FLOW_MODEE_TYPE_NAME = "MODEE_TYPE_NAME"
local FLOW_MODEE_FINISH    = "MODEE_FINISH"
local FLOW_WAIT_GAMEPLAY   = "WAIT_GAMEPLAY"
local FLOW_FS1_START_GAME  = "FS1_START_GAME"
local FLOW_T38_STABILIZE   = "T38_STABILIZE"
local FLOW_T38_CAPTURE     = "T38_CAPTURE"
local FLOW_DONE            = "DONE"

-- ---------------------------------------------------------------------------
-- Memory domains
-- ---------------------------------------------------------------------------
local AVAILABLE_DOMAINS = {}
do
    local ok, domains = pcall(memory.getmemorydomainlist)
    if ok and type(domains) == "table" then
        for _, n in ipairs(domains) do AVAILABLE_DOMAINS[n] = true end
    end
end

local function domain_ok(n) return AVAILABLE_DOMAINS[n] == true end

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

local function try_read(domain, addr, width)
    if not domain_ok(domain) then return nil end
    local ok, v = pcall(function()
        memory.usememorydomain(domain)
        if width == 2 then return memory.read_u16_be(addr) end
        return memory.read_u8(addr)
    end)
    if ok then return v end
    return nil
end

local function m68k_bus_u8(bus_addr)
    if not domain_ok("M68K BUS") then return nil end
    local even = bus_addr - (bus_addr % 2)
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        local w = memory.read_u16_be(even)
        if (bus_addr % 2) == 0 then return math.floor(w / 256) % 256 end
        return w % 256
    end)
    if ok then return v end
    return nil
end

local function m68k_bus_u16(bus_addr)
    -- Bus word reads (must be even-aligned; we rely on caller to pass word addrs)
    if not domain_ok("M68K BUS") then return nil end
    local ok, v = pcall(function()
        memory.usememorydomain("M68K BUS")
        return memory.read_u16_be(bus_addr - (bus_addr % 2))
    end)
    if ok then return v end
    return nil
end

local function ram_u8(bus_addr)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        domain_ok("68K RAM")  and {"68K RAM",  ofs} or nil,
        domain_ok("Main RAM") and {"Main RAM", ofs} or nil,
    }) do
        local v = try_read(spec[1], spec[2], 1)
        if v ~= nil then return v end
    end
    local v = m68k_bus_u8(bus_addr)
    if v ~= nil then return v end
    if domain_ok("System Bus") then
        v = try_read("System Bus", bus_addr, 1)
        if v ~= nil then return v end
    end
    return 0
end

local function ram_u16(bus_addr)
    local ofs = bus_addr - 0xFF0000
    for _, spec in ipairs({
        domain_ok("68K RAM")  and {"68K RAM",  ofs} or nil,
        domain_ok("Main RAM") and {"Main RAM", ofs} or nil,
    }) do
        local v = try_read(spec[1], spec[2], 2)
        if v ~= nil then return v end
    end
    local v = m68k_bus_u16(bus_addr)
    if v ~= nil then return v end
    return 0
end

-- T39 dump helpers (declared up top; bodies here, once ram_u8 is visible).
function t39_dump_nt(path, tval)
    local parts = {string.format("; T39 NT_CACHE dump at scenario t=%d\n", tval)}
    local pc = ram_u8(T39_PPUCTRL) or 0
    local pm = ram_u8(T39_PPUMASK) or 0
    local gmode  = ram_u8(0xFF0012) or 0
    local gtmode = ram_u8(0xFF005B) or 0
    local gscrolly = ram_u8(0xFF00FD) or 0
    parts[#parts+1] = string.format(
        "; PPUCTRL=$%02X PPUMASK=$%02X GameMode=$%02X TargetMode=$%02X ScrollY=$%02X\n",
        pc, pm, gmode, gtmode, gscrolly)
    local row = {}
    for i = 0, T39_NT_LEN - 1 do
        row[#row+1] = string.format("%02X", ram_u8(T39_NT_BASE + i) or 0)
        if (i % 32) == 31 then
            parts[#parts+1] = string.format("r%02d: %s\n",
                math.floor(i / 32), table.concat(row, " "))
            row = {}
        end
    end
    local f = io.open(path, "w")
    if f then f:write(table.concat(parts)); f:close() end
end

function t39_dump_vdp(path, tval)
    local parts = {string.format("; T39 VDP VRAM pattern dump at scenario t=%d\n", tval)}
    local ok_vdp = false
    pcall(function()
        if memory.getmemorydomainlist then
            for _, dn in ipairs(memory.getmemorydomainlist()) do
                if dn == "VRAM" then ok_vdp = true end
            end
        end
    end)
    if not ok_vdp then
        parts[#parts+1] = "; VRAM domain unavailable\n"
    else
        pcall(function()
            memory.usememorydomain("VRAM")
            local row = {}
            for i = 0, 0x3FFF do
                row[#row+1] = string.format("%02X", memory.read_u8(i))
                if (i % 32) == 31 then
                    parts[#parts+1] = string.format("v%04X: %s\n",
                        (i - 31), table.concat(row, " "))
                    row = {}
                end
            end
        end)
    end
    local f = io.open(path, "w")
    if f then f:write(table.concat(parts)); f:close() end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------
local function safe_set(pad)
    local expanded = {}
    for k, v in pairs(pad or {}) do
        expanded[k] = v
        if k:sub(1, 3) ~= "P1 " then expanded["P1 " .. k] = v end
    end
    local ok = pcall(function() joypad.set(expanded, 1) end)
    if not ok then joypad.set(expanded) end
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
-- Output
-- ---------------------------------------------------------------------------
local lines = {}
local function record(t)
    lines[#lines + 1] = t
    print(t)
    local f = io.open(OUT_TXT, "w")
    if f then f:write(table.concat(lines, "\n") .. "\n"); f:close() end
end

local function write_file(path, text)
    local f, err = io.open(path, "w")
    if not f then print("ERROR open " .. path .. ": " .. tostring(err)); return end
    f:write(text); f:close()
end

local function json_num_array(v)
    local p = {}
    for i = 1, #v do p[i] = tostring(v[i]) end
    return "[" .. table.concat(p, ",") .. "]"
end

-- T38 enemy-slot helpers. Per aldonunez Variables.inc: flat arrays.
--   ObjType=$34F+N, ObjX=$70+N, ObjY=$84+N, ObjDir=$98+N,
--   ObjState=$AC+N, ObjHP=$485+N.  NES-mirrored at A4=$FF0000.
local ENEMY_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8 }
local function read_enemy_slot(n)
    return {
        id    = ram_u8(BUS + 0x034F + n),
        x     = ram_u8(BUS + 0x0070 + n),
        y     = ram_u8(BUS + 0x0084 + n),
        dir   = ram_u8(BUS + 0x0098 + n),
        state = ram_u8(BUS + 0x00AC + n),
        hp    = ram_u8(BUS + 0x0485 + n),
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
-- Exception guard
-- ---------------------------------------------------------------------------
local function read_exception_block()
    local type_byte = ram_u8(A_EXC_BASE)
    local bytes = { type_byte }
    for i = 1, EXC_BYTES - 1 do
        bytes[#bytes + 1] = ram_u8(A_EXC_BASE + i)
    end
    local hit = (type_byte == 2 or type_byte == 3) and 1 or 0
    return hit, bytes
end

-- ---------------------------------------------------------------------------
-- Capture state
-- ---------------------------------------------------------------------------
local flow_state = REPLAY and FLOW_REPLAY or FLOW_BOOT_TO_FS1
if REPLAY then
    record(string.format("REPLAY: loaded bootflow_gen.txt (%d frames)", REPLAY:length()))
end
local function set_flow(next_state, frame, reason)
    if flow_state == next_state then return end
    record(string.format("f%04d flow %s -> %s (%s)", frame, flow_state, next_state, reason or ""))
    flow_state = next_state
end

local CAPTURE = {
    reached_mode5 = false,
    reached_mode5_frame = -1,
    t0_frame = -1,
    baseline_x = nil, baseline_y = nil, baseline_dir = nil,
    baseline_hscroll = nil, baseline_vscroll = nil, baseline_room = nil,
    stable_count = 0, stable_prev_x = nil, stable_prev_y = nil,
    name_progress_events = 0, last_name_offset = 0,
    trace = {},
    gen_exception_frame = nil,
    gen_exception_bytes = nil,
    ended_naturally = false,
}

record("=================================================================")
record("T35 Genesis capture: room $77 -> $76 left-scroll trace")
record("=================================================================")
record(string.format("SCENARIO_LENGTH=%d", SCENARIO.SCENARIO_LENGTH))

-- ---------------------------------------------------------------------------
-- State-write watcher (T36 Stage C debug): log writes to $FF0098 (facedir),
-- $FF00AC (objstate), $FF000F (movedir) during cave-related modes.
-- ---------------------------------------------------------------------------
local BP_LOG = repo_path("builds\\reports\\T38_cave_statewrite.txt")
local bp_lines = {}
local bp_count = 0
local BP_MAX = 4000
local function bp_write(s)
    if bp_count >= BP_MAX then return end
    bp_count = bp_count + 1
    bp_lines[#bp_lines + 1] = s
    local f = io.open(BP_LOG, "w")
    if f then f:write(table.concat(bp_lines, "\n") .. "\n"); f:close() end
end
local bp_current_frame = 0
local bp_t0 = -1
local function bp_make(label)
    return function(a, v, flags)
        local m = ram_u8(A_MODE)
        -- objstate: watch across all modes (want to see clear-writers in any mode).
        -- facedir/movedir: keep mode-$0B-only filter from prior stage.
        if label ~= "objstate" and label ~= "cavetype" and m ~= 0x0B then return end
        -- skip Walker_Move's per-frame zero+set (PC $5206A/$5201E) to trim noise
        local ok2, regs2 = pcall(function() return emu.getregisters() end)
        local pc_pre = (ok2 and regs2) and (regs2["M68K PC"] or regs2["PC"] or 0) or 0
        if label == "movedir " and (pc_pre == 0x5206A or pc_pre == 0x5201E) then return end
        local pc = 0
        local ok, regs = pcall(function() return emu.getregisters() end)
        if ok and regs then pc = regs["M68K PC"] or regs["PC"] or 0 end
        local t = (bp_t0 >= 0) and (bp_current_frame - bp_t0) or -1
        local eb = ram_u8(BUS + 0x00EB)
        local sram_val = ram_u8(BUS + 0x6000 + 0x08FE + eb)
        local zp02 = ram_u8(BUS + 0x0002)
        local zp03 = ram_u8(BUS + 0x0003)
        local zp0350 = ram_u8(BUS + 0x0350)
        bp_write(string.format("WR f=%d t=%d %s val=%02X PC=%08X mode=%02X y=%02X EB=%02X SRAM[%04X]=%02X zp02=%02X zp03=%02X cur0350=%02X",
            bp_current_frame, t, label, v or -1, pc, m, ram_u8(A_OBJ_Y), eb, 0x08FE+eb, sram_val, zp02, zp03, zp0350))
    end
end
for _, dn in ipairs({"System Bus", "68K BUS", "M68K BUS"}) do
    if domain_ok(dn) then
        local ok = pcall(function()
            event.on_bus_write(bp_make("facedir "), 0xFF0098, dn)
            event.on_bus_write(bp_make("objstate"), 0xFF00AC, dn)
            event.on_bus_write(bp_make("movedir "), 0xFF000F, dn)
            event.on_bus_write(bp_make("cavetype"), 0xFF0350, dn)
            -- T36 Stage F: who writes to $FF6975 (the SRAM byte InCave reads)?
            local sram_writes = 0
            event.on_bus_write(function(a, v)
                if sram_writes >= 200 then return end
                sram_writes = sram_writes + 1
                local pc = 0
                local ok, regs = pcall(function() return emu.getregisters() end)
                if ok and regs then pc = regs["M68K PC"] or regs["PC"] or 0 end
                local t = (bp_t0 >= 0) and (bp_current_frame - bp_t0) or -1
                bp_write(string.format("SRAM6975 f=%d t=%d val=%02X PC=%08X",
                    bp_current_frame, t, v or -1, pc))
            end, 0xFF6975, dn)
        end)
        if ok then bp_write("BP installed on "..dn); break end
    end
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------
local last_heartbeat = 0
for frame = 1, MAX_FRAMES do
    bp_current_frame = frame
    bp_t0 = CAPTURE.t0_frame
    local mode     = ram_u8(A_MODE)
    if frame - last_heartbeat >= 200 then
        last_heartbeat = frame
        record(string.format("HB f%04d flow=%s mode=$%02X sub=$%02X room=$%02X hsc=$%02X scrmode=$%02X",
            frame, flow_state, mode, ram_u8(A_SUBMODE), ram_u8(A_ROOM_ID),
            ram_u8(A_CUR_HSCROLL), ram_u8(A_STAGED_SCROLL_MODE)))
    end
    local sub      = ram_u8(A_SUBMODE)
    local room_id  = ram_u8(A_ROOM_ID)
    local cur_slot = ram_u8(A_CUR_SLOT)
    local name_ofs = ram_u8(A_NAME_OFS)
    local slot_a0  = ram_u8(A_SLOT_A0)
    local slot_a1  = ram_u8(A_SLOT_A1)
    local slot_a2  = ram_u8(A_SLOT_A2)

    -- Exception guard every frame
    local exc_count, exc_bytes = read_exception_block()
    if exc_count > 0 and CAPTURE.gen_exception_frame == nil then
        CAPTURE.gen_exception_frame = frame
        CAPTURE.gen_exception_bytes = exc_bytes
        record(string.format("f%04d GEN EXCEPTION DETECTED â€” halting", frame))
        break
    end

    if flow_state == FLOW_REPLAY then
        -- Watch for stability gate; replay keeps feeding recorded pad until we
        -- see Mode5/room77 + Link stable. At that point switch to T38_STABILIZE
        -- and let normal stability/capture logic take over.
        if mode == 0x05 and room_id == TARGET_ROOM_ID then
            if not CAPTURE.reached_mode5 then
                CAPTURE.reached_mode5 = true
                CAPTURE.reached_mode5_frame = frame
                record(string.format("f%04d REPLAY reached Mode5 room $%02X", frame, room_id))
            end
            set_flow(FLOW_T38_STABILIZE, frame, "replay hit gameplay")
        end

    elseif flow_state == FLOW_BOOT_TO_FS1 then
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
                set_flow(FLOW_FS1_ENTER_REG, frame, "CurSaveSlot = 3")
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
            schedule_input("B", 1, 10)  -- Gen B â†’ NES A (pick letter; nes_io.asm:1698)
        end

    elseif flow_state == FLOW_MODEE_FINISH then
        if mode ~= 0x0E then
            set_flow(FLOW_WAIT_GAMEPLAY, frame, "left ModeE")
        else
            -- Mirror NES probe: Select moves cursor to End slot ($03), then Start commits.
            -- Genesis C button maps to NES Select (see nes_io.asm:1711-1717).
            if cur_slot ~= 0x03 then
                schedule_input("C", 1, 10)
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
            local target = 0x00
            if slot_a0 == 0 and slot_a1 ~= 0 then target = 0x01
            elseif slot_a0 == 0 and slot_a1 == 0 and slot_a2 ~= 0 then target = 0x02 end
            if cur_slot ~= target then
                schedule_input(target > cur_slot and "Down" or "Up", 1, 10)
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
            local obj_x = ram_u8(A_OBJ_X)
            local obj_y = ram_u8(A_OBJ_Y)
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
            local frame_ctr = ram_u8(A_FRAME_CTR)
            if CAPTURE.stable_count >= LINK_STABLE_FRAMES
               and (frame_ctr % 4) == 0 then
                CAPTURE.t0_frame = frame
                CAPTURE.baseline_x = obj_x
                CAPTURE.baseline_y = obj_y
                CAPTURE.baseline_dir = ram_u8(A_OBJ_DIR)
                CAPTURE.baseline_hscroll = ram_u8(A_CUR_HSCROLL)
                CAPTURE.baseline_vscroll = ram_u8(A_CUR_VSCROLL)
                CAPTURE.baseline_room = room_id
                record(string.format("f%04d T=0 baseline x=$%02X y=$%02X dir=$%02X hsc=$%02X vsc=$%02X room=$%02X frame_ctr=$%02X",
                    frame, obj_x, obj_y, CAPTURE.baseline_dir,
                    CAPTURE.baseline_hscroll, CAPTURE.baseline_vscroll, room_id, frame_ctr))
                -- T38: sync RNG to match NES probe's T0 seed so scrambles
                -- evolve identically. NES writes 40 41 42 43 44 45 46 47 to
                -- $18..$1F at its own T0; do the same on Gen via the NES-RAM
                -- mirror at $FF0018..$FF001F.
                for i = 0, 7 do
                    pcall(function()
                        memory.usememorydomain("68K RAM")
                        memory.writebyte(0x0018 + i, 0x40 + i)
                    end)
                end
                record("RNG_SEED: wrote 40 41 42 43 44 45 46 47 to $FF0018..$FF001F")
                set_flow(FLOW_T38_CAPTURE, frame, "T35 capture window open")
                CAPTURE.trace[#CAPTURE.trace + 1] = {
                    t = 0,
                    obj_x = obj_x, obj_xf = ram_u8(A_OBJ_XF),
                    obj_y = obj_y, obj_yf = ram_u8(A_OBJ_YF),
                    obj_dir = CAPTURE.baseline_dir,
                    held = ram_u8(A_HELD), prev_held = ram_u8(A_PREV_HELD),
                    mode = mode, sub = sub, room = room_id,
                    hscroll = CAPTURE.baseline_hscroll,
                    vscroll = CAPTURE.baseline_vscroll,
                    cur_col = ram_u8(A_CUR_COL),
                    cur_row = ram_u8(A_CUR_ROW),
                    ppumask = ram_u8(A_CUR_PPUMASK),
                    gen_scrl_x = ram_u8(A_PPU_SCRL_X),
                    gen_scrl_y = ram_u8(A_PPU_SCRL_Y),
                    gen_staged_mode = ram_u8(A_STAGED_SCROLL_MODE),
                    gen_staged_hint = ram_u8(A_STAGED_HINT_CTR),
                    gen_staged_base = ram_u16(A_STAGED_BASE_VSRAM),
                    gen_staged_event = ram_u16(A_STAGED_EVENT_VSRAM),
                    gen_active_base = ram_u16(A_ACTIVE_BASE_VSRAM),
                    gen_active_event = ram_u16(A_ACTIVE_EVENT_VSRAM),
                    gen_active_hint = ram_u8(A_ACTIVE_HINT_CTR),
                    isupd = ram_u8(A_ISUPDATING_MODE),
                    secret = ram_u8(A_SECRET_COLOR_CYCLE),
                    whirl = ram_u8(A_WHIRL_STATE),
                    objstate = ram_u8(A_OBJSTATE),
                    movedir = ram_u8(A_MOVEDIR),
                    facedir = ram_u8(A_FACEDIR),
                    personstate = ram_u8(A_PERSONSTATE),
                    cavetype = ram_u8(A_CAVETYPE),
                    objtimer0 = ram_u8(A_OBJTIMER0),
                    autowalk = ram_u8(A_AUTOWALK),
                    obj_templ = ram_u8(A_OBJ_TEMPL),
                    lvl_block = ram_u8(A_LVL_BLOCK),
                    room_flags = ram_u8(A_ROOM_FLAGS),
                    cave_tmpl = ram_u8(A_CAVE_TMPL),
                    sram_68fe = ram_u8(A_SRAM_68FE),
                    sram_lvl = ram_u8(A_SRAM_68FE + ram_u8(A_LVL_BLOCK)),
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
        -- T39 render-classification: dump PNG + NT_CACHE + VRAM at 3 waypoints
        for _, shot in ipairs(T39_SHOTS) do
            if t == shot.t and not t39_done[shot.t] then
                t39_done[shot.t] = true
                pcall(function() client.screenshot(shot.png) end)
                t39_dump_nt(shot.nt, t)
                t39_dump_vdp(shot.vdp, t)
                record(string.format("f%04d T39_SHOT t=%d png=%s", frame, t, shot.png))
            end
        end
        -- T38: Link pose + enemy-slot snapshot. Dense sampling around the
        -- spawn moment (t=240..310) so we can see how/when all four slots
        -- become identical — spawn-time convergence vs post-spawn corruption.
        local snap = (t == 60 or t == 240 or t == 300 or t == 420
                      or t == 500 or t == 600 or t == 700)
        if t >= 240 and t <= 310 then snap = true end
        if snap then
            local rand = {}
            for i = 0, 7 do rand[i+1] = string.format("%02X", ram_u8(0xFF0018 + i)) end
            record(string.format("LINK t=%d x=$%02X y=$%02X dir=$%02X room=$%02X mode=$%02X sub=$%02X rand[0..7]=%s",
                t, ram_u8(A_OBJ_X), ram_u8(A_OBJ_Y),
                ram_u8(A_OBJ_DIR), room_id, mode, sub, table.concat(rand, " ")))
            snapshot_enemies("t="..t, t)
        end
        CAPTURE.trace[#CAPTURE.trace + 1] = {
            t = t,
            obj_x = ram_u8(A_OBJ_X), obj_xf = ram_u8(A_OBJ_XF),
            obj_y = ram_u8(A_OBJ_Y), obj_yf = ram_u8(A_OBJ_YF),
            obj_dir = ram_u8(A_OBJ_DIR),
            held = ram_u8(A_HELD), prev_held = ram_u8(A_PREV_HELD),
            mode = mode, sub = sub, room = room_id,
            hscroll = ram_u8(A_CUR_HSCROLL),
            vscroll = ram_u8(A_CUR_VSCROLL),
            cur_col = ram_u8(A_CUR_COL),
            cur_row = ram_u8(A_CUR_ROW),
            ppumask = ram_u8(A_CUR_PPUMASK),
            gen_scrl_x = ram_u8(A_PPU_SCRL_X),
            gen_scrl_y = ram_u8(A_PPU_SCRL_Y),
            gen_staged_mode = ram_u8(A_STAGED_SCROLL_MODE),
            gen_staged_hint = ram_u8(A_STAGED_HINT_CTR),
            gen_staged_base = ram_u16(A_STAGED_BASE_VSRAM),
            gen_staged_event = ram_u16(A_STAGED_EVENT_VSRAM),
            gen_active_base = ram_u16(A_ACTIVE_BASE_VSRAM),
            gen_active_event = ram_u16(A_ACTIVE_EVENT_VSRAM),
            gen_active_hint = ram_u8(A_ACTIVE_HINT_CTR),
            isupd = ram_u8(A_ISUPDATING_MODE),
            secret = ram_u8(A_SECRET_COLOR_CYCLE),
            whirl = ram_u8(A_WHIRL_STATE),
            objstate = ram_u8(A_OBJSTATE),
            movedir = ram_u8(A_MOVEDIR),
            facedir = ram_u8(A_FACEDIR),
            personstate = ram_u8(A_PERSONSTATE),
            cavetype = ram_u8(A_CAVETYPE),
            objtimer0 = ram_u8(A_OBJTIMER0),
            autowalk = ram_u8(A_AUTOWALK),
            obj_templ = ram_u8(A_OBJ_TEMPL),
            lvl_block = ram_u8(A_LVL_BLOCK),
            room_flags = ram_u8(A_ROOM_FLAGS),
            cave_tmpl = ram_u8(A_CAVE_TMPL),
            sram_68fe = ram_u8(A_SRAM_68FE),
            sram_lvl = ram_u8(A_SRAM_68FE + ram_u8(A_LVL_BLOCK)),
            inv_sword = ram_u8(A_INV_SWORD),  -- T38: sword inventory slot
        }
    end

    local pad
    if flow_state == FLOW_T38_CAPTURE then
        pad = SCENARIO.get_input_for_relative_frame(frame - CAPTURE.t0_frame)
    elseif flow_state == FLOW_REPLAY and REPLAY then
        pad = REPLAY:pad_for_frame(frame) or {}
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
record(string.format("GEN_EXCEPTION_FRAME=%s",
    CAPTURE.gen_exception_frame and tostring(CAPTURE.gen_exception_frame) or "null"))
if trace_len > 0 then
    local last = trace[trace_len]
    record(string.format("FINAL t=%d x=$%02X.%02X y=$%02X.%02X dir=$%02X room=$%02X mode=$%02X sub=$%02X hsc=$%02X scrmode=$%02X",
        last.t, last.obj_x, last.obj_xf, last.obj_y, last.obj_yf,
        last.obj_dir, last.room, last.mode, last.sub, last.hscroll, last.gen_staged_mode))
end

-- ---------------------------------------------------------------------------
-- JSON
-- ---------------------------------------------------------------------------
local function build_json()
    local cols = {
        t = {}, obj_x = {}, obj_xf = {}, obj_y = {}, obj_yf = {},
        obj_dir = {}, held = {}, prev_held = {},
        mode = {}, sub = {}, room = {},
        hscroll = {}, vscroll = {},
        cur_col = {}, cur_row = {}, ppumask = {},
        gen_scrl_x = {}, gen_scrl_y = {},
        gen_staged_mode = {}, gen_staged_hint = {},
        gen_staged_base = {}, gen_staged_event = {},
        gen_active_base = {}, gen_active_event = {}, gen_active_hint = {},
        isupd = {}, secret = {}, whirl = {},
        objstate = {}, movedir = {}, facedir = {},
        personstate = {}, cavetype = {}, objtimer0 = {}, autowalk = {},
        obj_templ = {}, lvl_block = {}, room_flags = {}, cave_tmpl = {},
        sram_68fe = {}, sram_lvl = {},
        inv_sword = {},
    }
    for i = 1, trace_len do
        local e = trace[i]
        cols.t[i]              = e.t
        cols.obj_x[i]          = e.obj_x
        cols.obj_xf[i]         = e.obj_xf
        cols.obj_y[i]          = e.obj_y
        cols.obj_yf[i]         = e.obj_yf
        cols.obj_dir[i]        = e.obj_dir
        cols.held[i]           = e.held
        cols.prev_held[i]      = e.prev_held or 0
        cols.mode[i]           = e.mode
        cols.sub[i]            = e.sub
        cols.room[i]           = e.room
        cols.hscroll[i]        = e.hscroll
        cols.vscroll[i]        = e.vscroll
        cols.cur_col[i]        = e.cur_col
        cols.cur_row[i]        = e.cur_row
        cols.ppumask[i]        = e.ppumask
        cols.gen_scrl_x[i]     = e.gen_scrl_x
        cols.gen_scrl_y[i]     = e.gen_scrl_y
        cols.gen_staged_mode[i]  = e.gen_staged_mode
        cols.gen_staged_hint[i]  = e.gen_staged_hint
        cols.gen_staged_base[i]  = e.gen_staged_base
        cols.gen_staged_event[i] = e.gen_staged_event
        cols.gen_active_base[i]  = e.gen_active_base
        cols.gen_active_event[i] = e.gen_active_event
        cols.gen_active_hint[i]  = e.gen_active_hint
        cols.isupd[i]          = e.isupd or 0
        cols.secret[i]         = e.secret or 0
        cols.whirl[i]          = e.whirl or 0
        cols.objstate[i]       = e.objstate or 0
        cols.movedir[i]        = e.movedir or 0
        cols.facedir[i]        = e.facedir or 0
        cols.personstate[i]    = e.personstate or 0
        cols.cavetype[i]       = e.cavetype or 0
        cols.objtimer0[i]      = e.objtimer0 or 0
        cols.autowalk[i]       = e.autowalk or 0
        cols.obj_templ[i]      = e.obj_templ or 0
        cols.lvl_block[i]      = e.lvl_block or 0
        cols.room_flags[i]     = e.room_flags or 0
        cols.cave_tmpl[i]      = e.cave_tmpl or 0
        cols.sram_68fe[i]      = e.sram_68fe or 0
        cols.sram_lvl[i]       = e.sram_lvl or 0
        cols.inv_sword[i]      = e.inv_sword or 0
    end
    local phase_parts = {}
    for i, p in ipairs(SCENARIO.phase_summary()) do
        phase_parts[i] = string.format(
            '{"name":"%s","button":%s,"start_t":%d,"end_t":%d}',
            p.name, p.button and ('"' .. p.button .. '"') or "null",
            p.start_t, p.end_t)
    end
    local exc_str = "null"
    if CAPTURE.gen_exception_bytes then
        exc_str = json_num_array(CAPTURE.gen_exception_bytes)
    end
    return table.concat({
        "{",
        '"system":"Genesis",',
        '"scenario_length":' .. SCENARIO.SCENARIO_LENGTH .. ",",
        '"reached_mode5":' .. (CAPTURE.reached_mode5 and "true" or "false") .. ",",
        '"reached_mode5_frame":' .. CAPTURE.reached_mode5_frame .. ",",
        '"t0_frame":' .. CAPTURE.t0_frame .. ",",
        '"target_room_id":' .. TARGET_ROOM_ID .. ",",
        '"gen_exception_frame":' ..
            (CAPTURE.gen_exception_frame and tostring(CAPTURE.gen_exception_frame) or "null") .. ",",
        '"gen_exception_bytes":' .. exc_str .. ",",
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
        '"t":'                .. json_num_array(cols.t)                .. ",",
        '"obj_x":'            .. json_num_array(cols.obj_x)            .. ",",
        '"obj_xf":'           .. json_num_array(cols.obj_xf)           .. ",",
        '"obj_y":'            .. json_num_array(cols.obj_y)            .. ",",
        '"obj_yf":'           .. json_num_array(cols.obj_yf)           .. ",",
        '"obj_dir":'          .. json_num_array(cols.obj_dir)          .. ",",
        '"held":'             .. json_num_array(cols.held)             .. ",",
        '"prev_held":'        .. json_num_array(cols.prev_held)        .. ",",
        '"mode":'             .. json_num_array(cols.mode)             .. ",",
        '"sub":'              .. json_num_array(cols.sub)              .. ",",
        '"room":'             .. json_num_array(cols.room)             .. ",",
        '"hscroll":'          .. json_num_array(cols.hscroll)          .. ",",
        '"vscroll":'          .. json_num_array(cols.vscroll)          .. ",",
        '"cur_col":'          .. json_num_array(cols.cur_col)          .. ",",
        '"cur_row":'          .. json_num_array(cols.cur_row)          .. ",",
        '"ppumask":'          .. json_num_array(cols.ppumask)          .. ",",
        '"gen_scrl_x":'       .. json_num_array(cols.gen_scrl_x)       .. ",",
        '"gen_scrl_y":'       .. json_num_array(cols.gen_scrl_y)       .. ",",
        '"gen_staged_mode":'  .. json_num_array(cols.gen_staged_mode)  .. ",",
        '"gen_staged_hint":'  .. json_num_array(cols.gen_staged_hint)  .. ",",
        '"gen_staged_base":'  .. json_num_array(cols.gen_staged_base)  .. ",",
        '"gen_staged_event":' .. json_num_array(cols.gen_staged_event) .. ",",
        '"gen_active_base":'  .. json_num_array(cols.gen_active_base)  .. ",",
        '"gen_active_event":' .. json_num_array(cols.gen_active_event) .. ",",
        '"gen_active_hint":'  .. json_num_array(cols.gen_active_hint) .. ",",
        '"isupd":'            .. json_num_array(cols.isupd)            .. ",",
        '"secret":'           .. json_num_array(cols.secret)           .. ",",
        '"whirl":'            .. json_num_array(cols.whirl) .. ",",
        '"objstate":'         .. json_num_array(cols.objstate) .. ",",
        '"movedir":'          .. json_num_array(cols.movedir) .. ",",
        '"facedir":'          .. json_num_array(cols.facedir) .. ",",
        '"personstate":'      .. json_num_array(cols.personstate) .. ",",
        '"cavetype":'         .. json_num_array(cols.cavetype) .. ",",
        '"objtimer0":'        .. json_num_array(cols.objtimer0) .. ",",
        '"autowalk":'         .. json_num_array(cols.autowalk) .. ",",
        '"obj_templ":'        .. json_num_array(cols.obj_templ) .. ",",
        '"lvl_block":'        .. json_num_array(cols.lvl_block) .. ",",
        '"room_flags":'       .. json_num_array(cols.room_flags) .. ",",
        '"cave_tmpl":'        .. json_num_array(cols.cave_tmpl) .. ",",
        '"sram_68fe":'        .. json_num_array(cols.sram_68fe) .. ",",
        '"sram_lvl":'         .. json_num_array(cols.sram_lvl) .. ",",
        '"inv_sword":'        .. json_num_array(cols.inv_sword),
        "}",
        "}",
    }, "\n")
end

local ok_capture = (trace_len == SCENARIO.SCENARIO_LENGTH)
                   and (CAPTURE.gen_exception_frame == nil)
local verdict = ok_capture and "T38_GEN_CAPTURE: OK" or "T38_GEN_CAPTURE: FAIL"
record(verdict)

write_file(OUT_TXT, table.concat(lines, "\n") .. "\n")
write_file(OUT_JSON, build_json())

pcall(function() client.exit() end)
pcall(function() client.pause() end)
