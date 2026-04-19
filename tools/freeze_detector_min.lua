-- freeze_detector_min.lua — minimal: replay canonical boot, watch
-- FrameCounter at $73, dump state on stall. No memoryexecute hooks.

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

local last_fc = nil
local last_obj_idx = nil
local stale_frames = 0
local watch_emu_start = nil
local done = false
local watch_started = false

local function dump_freeze(reason, frame)
    local fh = assert(io.open(OUT, "w"))
    fh:write(string.format("=== FREEZE (%s) at emu_frame=%d ===\n", reason, frame))
    fh:write(string.format("FC=$%02X stale=%d CurObjIdx=$%02X Mode=$%02X/%02X Room=$%02X Lvl=$%02X\n",
        u8(FRAME_COUNTER), stale_frames, u8(CUR_OBJ_IDX), u8(GAME_MODE), u8(GAME_SUB),
        u8(ROOM_ID), u8(CUR_LEVEL)))
    fh:write(string.format("IsUpd=$%02X Dir=$%02X MonsterEdgeTimer=$%02X\n",
        u8(BUS + 0x11), u8(BUS + 0xF), u8(BUS + 0x4B)))
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
    fh:close()
    done = true
end

-- Wrap the main loop in pcall so any exception is dumped to the log.
local function mainloop()
for frame = 1, 30000 do
    local status = boot_sequence.drive(frame, TARGET_ROOM)
    emu.frameadvance()

    local mode = u8(GAME_MODE)
    local rid  = u8(ROOM_ID)
    local fc   = u8(FRAME_COUNTER)
    local idx  = u8(CUR_OBJ_IDX)

    gui.text(10, 10, string.format("st=%s f=%d m=$%02X rm=$%02X fc=$%02X stale=%d",
        status, frame, mode, rid, fc, stale_frames))

    if status == "arrived" and not watch_started then
        watch_started = true
        watch_emu_start = frame
        last_fc = fc
        last_obj_idx = idx
    end

    if watch_started and not done then
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
end  -- end mainloop()

local ok, err = pcall(mainloop)
if not ok then
    local fh = io.open(OUT, "w")
    if fh then
        fh:write("=== LUA EXCEPTION ===\n")
        fh:write(tostring(err) .. "\n")
        fh:close()
    end
    print("LUA ERROR: " .. tostring(err))
end
client.exit()
