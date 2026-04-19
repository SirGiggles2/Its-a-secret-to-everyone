-- position_log.lua — capture object positions at $73 for 360 logical ticks.
--
-- Phase 0 /mathproblem parity gate: prove the native MoveObject rewrite
-- produces byte-identical object state to the transpiled version. Run
-- this probe against Gen-pre-P48 and Gen-post-P48 from matching
-- savestates; diff with compare_position_logs.py.
--
-- Keys captures by LOGICAL game tick (FrameCounter at $FF0015), NOT
-- emulator frame. If the slower build advances fewer logical ticks per
-- real second, raw emulator-frame compare diverges by construction.
--
-- Output: C:\tmp\position_log_<tag>.txt where <tag> is from env var
-- POSITION_LOG_TAG (default "gen"). Each line is one logical tick with
-- all 12 object slots' X/Y/Dir/PosFrac/GridOffset in hex.
--
-- Usage: savestate must be at room $73, mode 5, sub 0. Probe waits for
-- first FrameCounter tick, then captures 360 consecutive logical ticks.

local TAG = os.getenv("POSITION_LOG_TAG") or "gen"
local OUT = "C:\\tmp\\position_log_" .. TAG .. ".txt"
local TICKS_TO_CAPTURE = 360

local BUS = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE     = BUS + 0x12
local GAME_SUB      = BUS + 0x13
local ROOM_ID       = BUS + 0xEB
local OBJ_TYPE      = BUS + 0x0350
local OBJ_X         = BUS + 0x0070
local OBJ_Y         = BUS + 0x0084
local OBJ_DIR       = BUS + 0x0098
local OBJ_POS_FRAC  = BUS + 0x03A8   -- ObjPosFrac
local OBJ_GRID_OFS  = BUS + 0x0394   -- ObjGridOffset
local OBJ_QSPD_FRAC = BUS + 0x03BC   -- ObjQSpeedFrac (read for sanity)

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local function capture_slots(base)
    local parts = {}
    for i = 0, 11 do parts[#parts+1] = string.format("%02X", u8(base + i)) end
    return table.concat(parts, ",")
end

local fh = assert(io.open(OUT, "w"))
fh:write(string.format("# position_log tag=%s ticks=%d room target=$73\n", TAG, TICKS_TO_CAPTURE))
fh:write("# columns: logical_tick,emu_frame,room,mode,sub,types,xs,ys,dirs,pos_frac,grid_ofs\n")

-- Wait for room $73 + mode 5 + sub 0 (savestate should be here already)
local waited = 0
while true do
    emu.frameadvance()
    waited = waited + 1
    if u8(ROOM_ID) == 0x73 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then break end
    if waited > 120 then
        fh:write(string.format("# ERROR: savestate not at room $73 after 120 frames (room=$%02X mode=$%02X sub=$%02X)\n",
            u8(ROOM_ID), u8(GAME_MODE), u8(GAME_SUB)))
        fh:close()
        client.exit()
        return
    end
end

-- Capture TICKS_TO_CAPTURE distinct logical ticks.
local prev_fc = u8(FRAME_COUNTER)
local captured = 0
local emu_frame = 0
while captured < TICKS_TO_CAPTURE do
    emu.frameadvance()
    emu_frame = emu_frame + 1
    local fc = u8(FRAME_COUNTER)
    if fc ~= prev_fc then
        prev_fc = fc
        captured = captured + 1
        fh:write(string.format("%d,%d,%02X,%02X,%02X,%s,%s,%s,%s,%s,%s\n",
            captured, emu_frame,
            u8(ROOM_ID), u8(GAME_MODE), u8(GAME_SUB),
            capture_slots(OBJ_TYPE),
            capture_slots(OBJ_X),
            capture_slots(OBJ_Y),
            capture_slots(OBJ_DIR),
            capture_slots(OBJ_POS_FRAC),
            capture_slots(OBJ_GRID_OFS)))
    end
    gui.text(10, 10, string.format("tag=%s  captured=%d/%d  emu=%d", TAG, captured, TICKS_TO_CAPTURE, emu_frame))
    if emu_frame > 2000 then
        fh:write(string.format("# WARNING: ran 2000 emu frames, only captured %d logical ticks\n", captured))
        break
    end
end

fh:close()
client.exit()
