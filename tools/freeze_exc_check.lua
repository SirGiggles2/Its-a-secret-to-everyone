-- freeze_exc_check.lua — replay to $73, wait for freeze, then read
-- the exception log at $FF0900-$FF0943.
dofile("C:\\tmp\\boot_sequence.lua")

local OUT = "C:\\tmp\\exc_log.txt"
local TARGET_ROOM = 0x73
local STALL = 30

local BUS = 0xFF0000
local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u16(a) memory.usememorydomain("M68K BUS"); return memory.read_u16_be(a) end
local function u32(a) memory.usememorydomain("M68K BUS"); return memory.read_u32_be(a) end

local FRAME_COUNTER = BUS + 0x15
local ROOM_ID = BUS + 0xEB
local CUR_OBJ_IDX = BUS + 0x0340
local EXC_TYPE = BUS + 0x0900
local EXC_SR   = BUS + 0x0902
local EXC_PC   = BUS + 0x0904
local EXC_REGS = BUS + 0x0908

local last_fc = nil
local last_idx = nil
local stale = 0
local arrived = false
local arrived_frame = 0
local dumped = false

for frame = 1, 20000 do
    local status = boot_sequence.drive(frame, TARGET_ROOM)
    emu.frameadvance()
    local rid = u8(ROOM_ID)
    local fc = u8(FRAME_COUNTER)
    local idx = u8(CUR_OBJ_IDX)
    gui.text(10, 10, string.format("f=%d rm=$%02X fc=$%02X stale=%d exc=$%02X",
        frame, rid, fc, stale, u8(EXC_TYPE)))

    if status == "arrived" and not arrived then
        arrived = true
        arrived_frame = frame
        last_fc = fc
        last_idx = idx
    end

    if arrived and not dumped then
        if fc == last_fc and idx == last_idx then
            stale = stale + 1
        else
            stale = 0
            last_fc = fc
            last_idx = idx
        end
        if stale >= STALL then
            local fh = assert(io.open(OUT, "w"))
            fh:write(string.format("=== STALL at f=%d fc=$%02X ===\n", frame, fc))
            fh:write(string.format("EXC_TYPE ($FF0900) = $%02X  (0=default, 2=bus, 3=addr)\n",
                u8(EXC_TYPE)))
            fh:write(string.format("EXC_SR   ($FF0902) = $%04X\n", u16(EXC_SR)))
            fh:write(string.format("EXC_PC   ($FF0904) = $%08X\n", u32(EXC_PC)))
            fh:write("\n--- saved registers ---\n")
            for i = 0, 7 do
                fh:write(string.format("D%d = $%08X\n", i, u32(EXC_REGS + i*4)))
            end
            for i = 0, 6 do
                fh:write(string.format("A%d = $%08X\n", i, u32(EXC_REGS + 32 + i*4)))
            end
            fh:write(string.format("\n--- BUS/ADDR extended frame ---\n"))
            fh:write(string.format("STATUS ($FF0944)  = $%04X\n", u16(BUS + 0x944)))
            fh:write(string.format("ACCESS ($FF0946)  = $%08X  (faulting address)\n", u32(BUS + 0x946)))
            fh:write(string.format("INSTR  ($FF094A)  = $%04X  (opcode at fault)\n", u16(BUS + 0x94A)))
            fh:close()
            dumped = true
            break
        end
        if frame - arrived_frame > 1800 then
            local fh = assert(io.open(OUT, "w"))
            fh:write("no freeze within 1800 frames\n")
            fh:close()
            dumped = true
            break
        end
    end
end

client.exit()
