-- probe_status.lua — logs emulator progress every 60 emu frames so we
-- can see whether Link is reaching rooms as expected.
dofile("C:\\tmp\\boot_sequence.lua")

local OUT = "C:\\tmp\\probe_status.txt"
local TARGET_ROOM = 0x73
local BUS = 0xFF0000
local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local fh = assert(io.open(OUT, "w"))
fh:write("emu_frame mode/sub/room/lvl objX/objY qSpdFrac status\n")

local reached_73_at = nil
for frame = 1, 20000 do
    local status = boot_sequence.drive(frame, TARGET_ROOM)
    emu.frameadvance()

    if frame % 60 == 0 or u8(BUS + 0xEB) == TARGET_ROOM then
        local mode = u8(BUS + 0x12)
        local sub  = u8(BUS + 0x13)
        local rid  = u8(BUS + 0xEB)
        local lvl  = u8(BUS + 0x10)
        fh:write(string.format("%d %02X/%02X/%02X/%02X %02X,%02X %02X %s\n",
            frame, mode, sub, rid, lvl,
            u8(BUS + 0x70), u8(BUS + 0x84),
            u8(BUS + 0x3BC),
            status))
        fh:flush()
        if rid == TARGET_ROOM and not reached_73_at then
            reached_73_at = frame
            fh:write(string.format("# reached $73 at emu frame %d\n", frame))
            fh:flush()
        end
        if reached_73_at and frame - reached_73_at > 300 then
            fh:write(string.format("# 300 frames past $73 arrival, exiting\n"))
            break
        end
    end

    gui.text(10, 10, string.format("s=%s f=%d rm=$%02X", status, frame, u8(BUS + 0xEB)))
end

fh:close()
client.exit()
