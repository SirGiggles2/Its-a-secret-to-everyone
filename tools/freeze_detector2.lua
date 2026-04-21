-- freeze_detector2.lua — finer-grained detector.
-- Samples CurObjIndex every emu frame; detects when it stops changing.
-- Hooks a wide net of functions to localize where the CPU is stuck.

local OUT = "C:\\tmp\\freeze_state2.txt"
local BOOT_TIMEOUT = 600
local STALL_THRESHOLD = 30       -- emu frames where both FC and CurObjIdx stuck
local TARGET_NAME_PROGRESS = 3
local TARGET_ROOM = 0x73

local BUS = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE     = BUS + 0x12
local GAME_SUB      = BUS + 0x13
local CUR_LEVEL     = BUS + 0x10
local CUR_SLOT      = BUS + 0x16
local NAME_OFS      = BUS + 0x0421
local ROOM_ID       = BUS + 0xEB
local CUR_OBJ_IDX   = BUS + 0x0340
local OBJ_TYPE      = BUS + 0x0350
local OBJ_X         = BUS + 0x0070
local OBJ_Y         = BUS + 0x0084
local OBJ_DIR       = BUS + 0x0098
local OBJ_STATE     = BUS + 0x00AC
local OBJ_POS_FRAC  = BUS + 0x03A8
local OBJ_GRID_OFS  = BUS + 0x0394
local OBJ_QSPD_FRAC = BUS + 0x03BC

local function u8(a)  memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

-- Wider symbol net. Update addresses from .lst after each build.
local HOTSPOTS = {
    MoveObject               = 0x4C8E4,
    Walker_Move              = 0x4C7BA,
    Walker_CheckTileCollision = 0x4C99A,
    UpdateMoblin             = 0x3A6FA,
    UpdateArrowOrBoomerang   = 0x4D1AA,
    TryNextDir               = 0x4CA26,
    AddQSpeed                = 0x30478,
    SubQSpeed                = 0x304E2,
    VBlankISR                = 0x00422,
    HBlankISR                = 0x0045E,
    RunGame                  = 0x4B2DA,
    InitObject               = 0x4E0D0,
    FindNextEdgeSpawnCell    = 0x4250C,
    MoveShot                 = 0x3058A,
    GetCollidableTile        = 0x4C9A0,   -- approximate; inside Walker_CheckTileCollision
    CheckTiles               = 0x4CAA0,   -- approximate
}

local hit_count = {}
local last_hit_name = "(none)"
local last_hit_total_emu = 0

for name, addr in pairs(HOTSPOTS) do
    hit_count[name] = 0
    pcall(function()
        event.onmemoryexecute(function()
            hit_count[name] = hit_count[name] + 1
            last_hit_name = name
        end, addr, "fd2_" .. name, "M68K BUS")
    end)
end

local function safe_set(pad)
    local ok = pcall(function() joypad.set(pad or {}, 1) end)
    if not ok then joypad.set(pad or {}) end
end
local input_state = { button = nil, hold_left = 0, release_left = 0, release_after = 8 }
local function schedule(button, hold, rel)
    if input_state.hold_left > 0 or input_state.release_left > 0 then return false end
    input_state.button = button
    input_state.hold_left = hold or 2
    input_state.release_after = rel or 10
    return true
end
local function current_pad()
    local pad = {}
    if input_state.hold_left > 0 and input_state.button then
        pad[input_state.button] = true
        pad["P1 " .. input_state.button] = true
        input_state.hold_left = input_state.hold_left - 1
        if input_state.hold_left == 0 then
            input_state.release_left = input_state.release_after
        end
    elseif input_state.release_left > 0 then
        input_state.release_left = input_state.release_left - 1
    end
    return pad
end

-- Deterministic menu sequence (per user): A×2, C×2, Start×2. Each press
-- is held for a few frames, then released. We just time-drive this; no
-- mode sniffing (which varies across builds).
local S_BOOT_WAIT=1; local S_MENU_SEQ=2; local S_WAIT_GAMEPLAY=3
local S_WALK=10; local S_WATCH=11; local S_DONE=12

local state = S_BOOT_WAIT
local menu_steps = {
    {btn="A",     hold=3, rel=8},
    {btn="A",     hold=3, rel=8},
    {btn="C",     hold=3, rel=8},
    {btn="C",     hold=3, rel=8},
    {btn="Start", hold=3, rel=30},
    {btn="Start", hold=3, rel=30},
}
local menu_step_idx = 1
local boot_wait_until = 180    -- wait 3 seconds at boot for attract
local last_fc = nil
local last_obj_idx = nil
local stale_frames = 0
local watch_emu_start = nil
-- Capture last 60 emu frames of per-frame history for post-mortem.
local history = {}
local HISTORY_LEN = 60

local function record_history(frame)
    history[#history + 1] = {
        emu_frame = frame,
        fc = u8(FRAME_COUNTER),
        obj_idx = u8(CUR_OBJ_IDX),
        mode = u8(GAME_MODE), sub = u8(GAME_SUB),
        last_hit = last_hit_name,
        total_hits = (function()
            local s = 0
            for _, n in pairs(hit_count) do s = s + n end
            return s
        end)(),
    }
    if #history > HISTORY_LEN then table.remove(history, 1) end
end

local function dump_freeze(reason, frame)
    local fh = assert(io.open(OUT, "w"))
    fh:write(string.format("=== FREEZE (%s) at emu_frame=%d ===\n", reason, frame))
    fh:write(string.format("FrameCounter=$%02X stale_frames=%d\n", u8(FRAME_COUNTER), stale_frames))
    fh:write(string.format("CurObjIndex=$%02X  Mode=$%02X  Sub=$%02X  Room=$%02X\n",
        u8(CUR_OBJ_IDX), u8(GAME_MODE), u8(GAME_SUB), u8(ROOM_ID)))
    fh:write(string.format("IsUpdatingMode=$%02X  Direction($000F)=$%02X  MonsterEdgeTimer=$%02X\n",
        u8(BUS + 0x11), u8(BUS + 0xF), u8(BUS + 0x4B)))

    fh:write("\n--- Per-emu-frame history (last 60 frames, newest last) ---\n")
    fh:write(string.format("  %-8s %-6s %-4s %-6s %-4s %-22s %s\n",
        "emu", "fc", "idx", "mode/s", "lvl", "last_hit", "total_hits"))
    for _, h in ipairs(history) do
        fh:write(string.format("  %-8d %-6s %-4s %-6s %-4s %-22s %d\n",
            h.emu_frame, string.format("$%02X", h.fc), string.format("$%02X", h.obj_idx),
            string.format("$%02X/%02X", h.mode, h.sub), "", h.last_hit, h.total_hits))
    end

    fh:write("\n--- Object slots (at freeze) ---\n")
    for i = 0, 11 do
        local t = u8(OBJ_TYPE + i)
        if t ~= 0 then
            fh:write(string.format(
                "  slot %2d: type=$%02X x=$%02X y=$%02X dir=$%02X state=$%02X posFrac=$%02X gridOff=$%02X qSpdFrac=$%02X\n",
                i, t,
                u8(OBJ_X + i), u8(OBJ_Y + i), u8(OBJ_DIR + i),
                u8(OBJ_STATE + i), u8(OBJ_POS_FRAC + i), u8(OBJ_GRID_OFS + i), u8(OBJ_QSPD_FRAC + i)))
        end
    end

    fh:write("\n--- Cumulative hotspot hits at freeze ---\n")
    local sorted = {}
    for name, n in pairs(hit_count) do sorted[#sorted+1] = {name=name, n=n} end
    table.sort(sorted, function(a, b) return a.n > b.n end)
    for _, e in ipairs(sorted) do
        fh:write(string.format("  %-24s %10d hits\n", e.name, e.n))
    end
    fh:close()
end

for frame = 1, 30000 do
    local pad = current_pad()
    safe_set(pad)
    emu.frameadvance()

    local mode = u8(GAME_MODE)
    local sub  = u8(GAME_SUB)
    local lvl  = u8(CUR_LEVEL)
    local rid  = u8(ROOM_ID)
    local slot = u8(CUR_SLOT)
    local nofs = u8(NAME_OFS)
    local fc   = u8(FRAME_COUNTER)
    local objidx = u8(CUR_OBJ_IDX)

    gui.text(10, 10, string.format("s=%d m=$%02X rm=$%02X fc=$%02X stale=%d last=%s",
        state, mode, rid, fc, stale_frames, last_hit_name))

    if state == S_BOOT_WAIT then
        if frame >= boot_wait_until then state = S_MENU_SEQ end
    elseif state == S_MENU_SEQ then
        if mode == 0x05 and lvl == 0 then
            state = S_WALK
        elseif menu_step_idx <= #menu_steps then
            local step = menu_steps[menu_step_idx]
            if schedule(step.btn, step.hold, step.rel) then
                menu_step_idx = menu_step_idx + 1
            end
        else
            state = S_WAIT_GAMEPLAY
        end
    elseif state == S_WAIT_GAMEPLAY then
        if mode == 0x05 and lvl == 0 then
            state = S_WALK
        elseif frame > BOOT_TIMEOUT * 2 then
            print("gameplay never reached")
            break
        else
            -- Nudge with an extra Start every 60 frames in case something got stuck.
            if (frame % 60) == 0 then schedule("Start", 3, 30) end
        end
    elseif state == S_WALK then
        if mode ~= 0x05 then
            -- wait
        elseif rid == TARGET_ROOM then
            state = S_WATCH
            last_fc = fc
            last_obj_idx = objidx
            watch_emu_start = frame
            for name, _ in pairs(hit_count) do hit_count[name] = 0 end
            last_hit_name = "(reset)"
            history = {}
        else
            safe_set({ Left = true, ["P1 Left"] = true })
        end
    elseif state == S_WATCH then
        record_history(frame)

        if fc == last_fc and objidx == last_obj_idx then
            stale_frames = stale_frames + 1
        else
            stale_frames = 0
            last_fc = fc
            last_obj_idx = objidx
        end

        if stale_frames >= STALL_THRESHOLD then
            dump_freeze(string.format("FC+obj_idx stuck for %d frames", stale_frames), frame)
            state = S_DONE
            watch_emu_start = frame
        end

        if frame - watch_emu_start > 1800 then
            dump_freeze("no freeze within 1800 frames", frame)
            state = S_DONE
            watch_emu_start = frame
        end
    elseif state == S_DONE then
        if frame - watch_emu_start > 60 then client.exit() end
    end
end

client.exit()
