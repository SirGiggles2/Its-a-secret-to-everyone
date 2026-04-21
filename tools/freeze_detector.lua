-- freeze_detector.lua — fresh-boot → walk to $73 → detect freeze → dump state.
--
-- A "freeze" is defined as FrameCounter ($FF0015) not advancing for 120
-- emulator frames in a row while the emulator itself is still running.
-- When detected, dumps a comprehensive RAM snapshot to
-- C:\tmp\freeze_state.txt so we can diagnose what's wedged:
--   - Game mode/sub/room
--   - All 12 object slots (type, X, Y, dir, state, pos_frac, grid_offset, q_speed)
--   - Critical timers ($004B, $0013 sub, $0011 is_updating)
--   - Walker/arrow-relevant RAM ($008E VBlankFlag, $0341 MainLoopFlag, etc.)
--   - Stack pointers (A5 software stack top)
--
-- Also samples PC-hotspots by setting up periodic snapshots of execution
-- hotspots via memoryexecute hooks on key functions — if one fires a
-- million times during freeze, that's the loop.

local OUT = "C:\\tmp\\freeze_state.txt"
local BOOT_TIMEOUT = 600
local FREEZE_THRESHOLD = 120     -- emulator frames with no FrameCounter change
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

local OBJ_TYPE      = BUS + 0x0350
local OBJ_X         = BUS + 0x0070
local OBJ_Y         = BUS + 0x0084
local OBJ_DIR       = BUS + 0x0098
local OBJ_STATE     = BUS + 0x00AC
local OBJ_POS_FRAC  = BUS + 0x03A8
local OBJ_GRID_OFS  = BUS + 0x0394
local OBJ_QSPD_FRAC = BUS + 0x03BC

local function u8(a)  memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u16(a) memory.usememorydomain("M68K BUS"); return memory.read_u16_be(a) end

-- Symbol addresses from builds/whatif.lst
local HOTSPOTS = {
    MoveObject          = 0x4C8E4,
    Walker_Move         = 0x4C7BA,
    Walker_CheckTile    = 0x4C99A,
    UpdateMoblin        = 0x3A6FA,
    UpdateArrow         = 0x4D1AA,
    TryNextDir          = 0x4CA26,
    AddQSpeed           = 0x30478,
    SubQSpeed           = 0x304E2,
    VBlankISR           = 0x00422,
    RunGame             = 0x4B2DA,
}

local hit_count = {}
for name, _ in pairs(HOTSPOTS) do hit_count[name] = 0 end

for name, addr in pairs(HOTSPOTS) do
    pcall(function()
        event.onmemoryexecute(function() hit_count[name] = hit_count[name] + 1 end,
                              addr, "freeze_" .. name, "M68K BUS")
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

-- Flow states
local S_BOOT = 1; local S_SELECT_REG = 2; local S_ENTER_REG = 3
local S_TYPE_NAME = 4; local S_CYCLE_END = 5; local S_CONFIRM_END = 6
local S_WAIT_FS1 = 7; local S_TO_SLOT0 = 8; local S_START_GAME = 9
local S_WALK = 10; local S_WATCH = 11; local S_DONE = 12

local state = S_BOOT
local name_progress = 0
local last_name_ofs = nil
local last_fc = nil
local stale_emu_frames = 0
local freeze_detected = false
local watch_emu_start = nil
local hot_snapshots = {}

local function dump_freeze(reason, frame)
    local fh = assert(io.open(OUT, "w"))
    fh:write(string.format("=== FREEZE DETECTED (%s) at emu_frame=%d ===\n", reason, frame))
    fh:write(string.format("FrameCounter=$%02X (stale for %d emu frames)\n", u8(FRAME_COUNTER), stale_emu_frames))
    fh:write(string.format("Mode=$%02X  Sub=$%02X  Level=$%02X  Room=$%02X  CurSlot=$%02X\n",
        u8(GAME_MODE), u8(GAME_SUB), u8(CUR_LEVEL), u8(ROOM_ID), u8(CUR_SLOT)))
    fh:write(string.format("IsUpdatingMode($0011)=$%02X  MainLoopFlag($0341)=$%02X  VBlankFlag($008E)=$%02X\n",
        u8(BUS + 0x0011), u8(BUS + 0x0341), u8(BUS + 0x008E)))
    fh:write(string.format("MonsterEdgeTimer($004B)=$%02X  WarpDir($00E7)=$%02X  Direction($000F)=$%02X\n",
        u8(BUS + 0x004B), u8(BUS + 0x00E7), u8(BUS + 0x000F)))
    fh:write(string.format("CurObjIndex($0340)=$%02X\n", u8(BUS + 0x0340)))
    fh:write("\n--- Object slots ---\n")
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
    fh:write("\n--- Hotspot hit counts (cumulative during watch window) ---\n")
    local sorted = {}
    for name, n in pairs(hit_count) do sorted[#sorted+1] = {name=name, n=n} end
    table.sort(sorted, function(a, b) return a.n > b.n end)
    for _, e in ipairs(sorted) do
        fh:write(string.format("  %-22s %10d hits\n", e.name, e.n))
    end
    fh:write("\n--- Hot-fn delta during last few emu frames (when freeze started) ---\n")
    for i, snap in ipairs(hot_snapshots) do
        fh:write(string.format("  snap %d (emu_frame=%d):\n", i, snap.emu_frame))
        for name, n in pairs(snap.counts) do
            fh:write(string.format("    %-22s %10d hits\n", name, n))
        end
    end
    fh:close()
    print("DUMPED freeze state -> " .. OUT)
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

    gui.text(10, 10, string.format("s=%d m=$%02X rm=$%02X fc=$%02X stale=%d %s",
        state, mode, rid, fc, stale_emu_frames, freeze_detected and "[FROZEN]" or ""))

    if state == S_BOOT then
        if mode == 0x01 then state = S_SELECT_REG; last_name_ofs = nofs
        elseif frame > BOOT_TIMEOUT then print("boot timeout"); break
        else schedule("Start", 2, 5) end
    elseif state == S_SELECT_REG then
        if mode ~= 0x01 then state = S_WAIT_FS1
        elseif slot == 0x03 then state = S_ENTER_REG
        else schedule("Down", 1, 12) end
    elseif state == S_ENTER_REG then
        if mode == 0x0E then state = S_TYPE_NAME; last_name_ofs = nofs
        elseif mode == 0x01 then schedule("Start", 2, 14) end
    elseif state == S_TYPE_NAME then
        if mode ~= 0x0E then state = S_WAIT_FS1
        else
            if nofs ~= last_name_ofs then
                name_progress = name_progress + 1; last_name_ofs = nofs
            end
            if name_progress >= TARGET_NAME_PROGRESS then state = S_CYCLE_END
            else schedule("A", 1, 10) end
        end
    elseif state == S_CYCLE_END then
        if mode ~= 0x0E then state = S_WAIT_FS1
        elseif slot == 0x03 then state = S_CONFIRM_END
        else schedule("Select", 1, 12) end
    elseif state == S_CONFIRM_END then
        if mode ~= 0x0E then state = S_WAIT_FS1
        else schedule("Start", 2, 14) end
    elseif state == S_WAIT_FS1 then
        if mode == 0x01 then state = S_TO_SLOT0 end
    elseif state == S_TO_SLOT0 then
        if mode ~= 0x01 then state = S_WAIT_FS1
        elseif slot == 0x00 then state = S_START_GAME
        else schedule("Up", 1, 12) end
    elseif state == S_START_GAME then
        if mode == 0x05 and lvl == 0 then state = S_WALK
        elseif mode == 0x01 then schedule("Start", 2, 14) end
    elseif state == S_WALK then
        if mode ~= 0x05 then
            -- wait
        elseif rid == TARGET_ROOM then
            state = S_WATCH
            last_fc = fc
            watch_emu_start = frame
            -- reset hit counts for clean watch-window measurement
            for name, _ in pairs(hit_count) do hit_count[name] = 0 end
        else
            safe_set({ Left = true, ["P1 Left"] = true })
        end
    elseif state == S_WATCH then
        if fc == last_fc then
            stale_emu_frames = stale_emu_frames + 1
        else
            stale_emu_frames = 0
            last_fc = fc
        end

        -- Snapshot hot counts every 20 emu frames so we can see what's
        -- ramping up right before the freeze.
        if frame % 20 == 0 then
            local snap = { emu_frame = frame, counts = {} }
            for name, n in pairs(hit_count) do snap.counts[name] = n end
            hot_snapshots[#hot_snapshots+1] = snap
            -- Keep only the last 10 snapshots
            if #hot_snapshots > 10 then
                table.remove(hot_snapshots, 1)
            end
        end

        if stale_emu_frames >= FREEZE_THRESHOLD and not freeze_detected then
            freeze_detected = true
            dump_freeze("FrameCounter stuck", frame)
            state = S_DONE
            watch_emu_start = frame
        end

        -- Timeout if no freeze in 30 seconds of gameplay
        if frame - watch_emu_start > 1800 and not freeze_detected then
            dump_freeze("no freeze after 1800 emu frames", frame)
            state = S_DONE
            watch_emu_start = frame
        end
    elseif state == S_DONE then
        if frame - watch_emu_start > 120 then client.exit() end
    end
end

client.exit()
