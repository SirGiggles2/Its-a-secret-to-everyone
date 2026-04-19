-- parity_capture_74.lua — fresh boot, walk (TURBO) to $74, stop,
-- capture 180 logical ticks of object state for parity comparison.
dofile("C:\\tmp\\boot_sequence.lua")

local TAG = os.getenv("PARITY_TAG") or "unknown"
local OUT = "C:\\tmp\\parity_log_" .. TAG .. ".txt"
local TARGET_ROOM = 0x74
local TICKS = 180

local BUS = 0xFF0000
local FRAME_COUNTER = BUS + 0x15
local GAME_MODE = BUS + 0x12
local GAME_SUB = BUS + 0x13
local CUR_LEVEL = BUS + 0x10
local ROOM_ID = BUS + 0xEB

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local function dump(base)
    local t = {}; for i = 0, 11 do t[#t+1] = string.format("%02X", u8(base + i)) end
    return table.concat(t, ",")
end

local fh = assert(io.open(OUT, "w"))
fh:write(string.format("# tag=%s target=$%02X ticks=%d\n", TAG, TARGET_ROOM, TICKS))
fh:write("# tick emu fc room mode sub types xs ys dirs states pos_frac grid_ofs qspd_frac\n")

local state = "booting"
local arrived_frame = nil
local last_fc = nil
local captured = 0

for frame = 1, 30000 do
    local status = boot_sequence.drive(frame, TARGET_ROOM)
    emu.frameadvance()

    local mode = u8(GAME_MODE)
    local rid  = u8(ROOM_ID)
    local fc   = u8(FRAME_COUNTER)

    gui.text(10, 10, string.format("tag=%s st=%s f=%d rm=$%02X captured=%d/%d",
        TAG, status, frame, rid, captured, TICKS))

    if status == "arrived" then
        if not arrived_frame then
            arrived_frame = frame
            last_fc = fc
        end
        if fc ~= last_fc then
            last_fc = fc
            captured = captured + 1
            fh:write(string.format("%d %d %02X %02X %02X %02X %s %s %s %s %s %s %s %s\n",
                captured, frame, fc,
                u8(ROOM_ID), u8(GAME_MODE), u8(GAME_SUB),
                dump(BUS + 0x0350), dump(BUS + 0x0070), dump(BUS + 0x0084),
                dump(BUS + 0x0098), dump(BUS + 0x00AC),
                dump(BUS + 0x03A8), dump(BUS + 0x0394), dump(BUS + 0x03BC)))
            if captured >= TICKS then
                fh:write("# done\n")
                break
            end
        end
    end
end

fh:close()
client.exit()
