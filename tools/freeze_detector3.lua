-- freeze_detector3.lua — like freeze_detector2 but uses the recorded
-- canonical boot sequence (loaded via dofile) to replay user inputs
-- deterministically rather than sniffing game modes.

dofile("C:\\tmp\\boot_sequence.lua")

local OUT = "C:\\tmp\\freeze_state3.txt"
local STALL_THRESHOLD = 30
local TARGET_ROOM = 0x73

local BUS = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE     = BUS + 0x12
local GAME_SUB      = BUS + 0x13
local CUR_LEVEL     = BUS + 0x10
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

-- Symbol addresses from .lst (read via a tiny helper at launch to stay fresh).
local function read_symbols_from_lst()
    local want = {
        MoveObject = true, Walker_Move = true, Walker_CheckTileCollision = true,
        UpdateMoblin = true, UpdateArrowOrBoomerang = true, TryNextDir = true,
        AddQSpeedToPositionFraction = true, SubQSpeedFromPositionFraction = true,
        VBlankISR = true, HBlankISR = true, RunGame = true,
        InitObject = true, FindNextEdgeSpawnCell = true,
        MoveShot = true, GetCollidableTile = true,
    }
    local lst = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\whatif.lst"
    local addrs = {}
    local f = io.open(lst, "r")
    if not f then return addrs end
    for line in f:lines() do
        local name, hex = line:match("^(%S+)%s+A:(%x+)%s*$")
        if name and hex and want[name] then
            addrs[name] = tonumber(hex, 16)
        end
    end
    f:close()
    return addrs
end

local SYM = read_symbols_from_lst()
print("loaded " .. (function() local n=0; for _ in pairs(SYM) do n=n+1 end; return n end)() .. " symbols")

local hit_count = {}
local last_hit_name = "(none)"
for name, addr in pairs(SYM) do
    hit_count[name] = 0
    pcall(function()
        event.onmemoryexecute(function()
            hit_count[name] = hit_count[name] + 1
            last_hit_name = name
        end, addr, "fd3_" .. name, "M68K BUS")
    end)
end

local last_fc = nil
local last_obj_idx = nil
local stale_frames = 0
local watch_emu_start = nil
local history = {}
local HISTORY_LEN = 60

local function record_history(frame)
    history[#history + 1] = {
        emu_frame = frame,
        fc = u8(FRAME_COUNTER),
        obj_idx = u8(CUR_OBJ_IDX),
        mode = u8(GAME_MODE), sub = u8(GAME_SUB),
        last_hit = last_hit_name,
        total_hits = (function() local s=0; for _,n in pairs(hit_count) do s=s+n end; return s end)(),
    }
    if #history > HISTORY_LEN then table.remove(history, 1) end
end

local done = false
local function dump_freeze(reason, frame)
    local fh = assert(io.open(OUT, "w"))
    fh:write(string.format("=== FREEZE (%s) at emu_frame=%d ===\n", reason, frame))
    fh:write(string.format("FC=$%02X stale_frames=%d  CurObjIndex=$%02X  Mode=$%02X/%02X  Room=$%02X  Level=$%02X\n",
        u8(FRAME_COUNTER), stale_frames, u8(CUR_OBJ_IDX), u8(GAME_MODE), u8(GAME_SUB),
        u8(ROOM_ID), u8(CUR_LEVEL)))
    fh:write(string.format("IsUpdatingMode=$%02X  Direction=$%02X  MonsterEdgeTimer=$%02X\n",
        u8(BUS + 0x11), u8(BUS + 0xF), u8(BUS + 0x4B)))

    fh:write("\n--- Per-frame history (newest last) ---\n")
    for _, h in ipairs(history) do
        fh:write(string.format("  emu=%d fc=$%02X idx=$%02X mode=$%02X/%02X last=%s total=%d\n",
            h.emu_frame, h.fc, h.obj_idx, h.mode, h.sub, h.last_hit, h.total_hits))
    end

    fh:write("\n--- Objects at freeze ---\n")
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

    fh:write("\n--- Hotspot cumulative hits ---\n")
    local sorted = {}
    for name, n in pairs(hit_count) do sorted[#sorted+1] = {name=name, n=n} end
    table.sort(sorted, function(a, b) return a.n > b.n end)
    for _, e in ipairs(sorted) do
        fh:write(string.format("  %-28s %10d\n", e.name, e.n))
    end
    fh:close()
    done = true
end

local watch_started = false

for frame = 1, 30000 do
    local status = boot_sequence.drive(frame, TARGET_ROOM)
    emu.frameadvance()

    local mode = u8(GAME_MODE)
    local rid  = u8(ROOM_ID)
    local fc   = u8(FRAME_COUNTER)
    local idx  = u8(CUR_OBJ_IDX)

    gui.text(10, 10, string.format("status=%-9s f=%d m=$%02X rm=$%02X fc=$%02X stale=%d",
        status, frame, mode, rid, fc, stale_frames))

    if status == "arrived" and not watch_started then
        watch_started = true
        watch_emu_start = frame
        last_fc = fc
        last_obj_idx = idx
        for name, _ in pairs(hit_count) do hit_count[name] = 0 end
        last_hit_name = "(reset)"
        history = {}
    end

    if watch_started and not done then
        record_history(frame)
        if fc == last_fc and idx == last_obj_idx then
            stale_frames = stale_frames + 1
        else
            stale_frames = 0
            last_fc = fc
            last_obj_idx = idx
        end
        if stale_frames >= STALL_THRESHOLD then
            dump_freeze(string.format("FC+idx stuck %d frames", stale_frames), frame)
        end
        if frame - watch_emu_start > 1800 then
            dump_freeze("no freeze within 1800 emu frames", frame)
        end
    end

    if done and frame - watch_emu_start > 60 then client.exit() end
end

client.exit()
