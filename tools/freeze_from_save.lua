-- freeze_from_save.lua — load savestate slot 2 (F2) and watch for freeze.
-- Much faster iteration than walking fresh-boot → $73 every time.

local OUT = "C:\\tmp\\freeze_state3.txt"
local STALL = 30
local TICKS_TO_WATCH = 600   -- ~10 seconds of game logic

local BUS = 0xFF0000
local function u8(a)  memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u16(a) memory.usememorydomain("M68K BUS"); return memory.read_u16_be(a) end
local function u32(a) memory.usememorydomain("M68K BUS"); return memory.read_u32_be(a) end

local FRAME_COUNTER = BUS + 0x15
local ROOM_ID = BUS + 0xEB
local CUR_OBJ_IDX = BUS + 0x0340
local GAME_MODE = BUS + 0x12
local GAME_SUB = BUS + 0x13
local EXC_TYPE = BUS + 0x0900

-- Try slot 2 first, fall back to slot 1 if slot 2 fails. Settle 120 frames.
local ok2 = pcall(function() savestate.loadslot(2) end)
if not ok2 then
    pcall(function() savestate.loadslot(1) end)
end
for _ = 1, 120 do emu.frameadvance() end

local watch_start = emu.framecount()
local last_fc = u8(FRAME_COUNTER)
local last_idx = u8(CUR_OBJ_IDX)
local stale = 0
local dumped = false

for _ = 1, 30000 do
    emu.frameadvance()
    local frame = emu.framecount()
    local fc = u8(FRAME_COUNTER)
    local idx = u8(CUR_OBJ_IDX)
    local rid = u8(ROOM_ID)
    local exc = u8(EXC_TYPE)

    gui.text(10, 10, string.format("f=%d rm=$%02X fc=$%02X stale=%d exc=$%02X",
        frame, rid, fc, stale, exc))

    if fc == last_fc and idx == last_idx then
        stale = stale + 1
    else
        stale = 0
        last_fc = fc
        last_idx = idx
    end

    if stale >= STALL and not dumped then
        local fh = assert(io.open(OUT, "w"))
        fh:write(string.format("=== STALL at frame=%d fc=$%02X ===\n", frame, fc))
        fh:write(string.format("EXC_TYPE=$%02X EXC_SR=$%04X EXC_PC=$%08X\n",
            exc, u16(BUS + 0x902), u32(BUS + 0x904)))
        fh:write(string.format("Mode=$%02X/%02X Room=$%02X IsUpd=$%02X Dir=$%02X MonsterEdgeTimer=$%02X\n",
            u8(GAME_MODE), u8(GAME_SUB), rid, u8(BUS + 0x11), u8(BUS + 0xF), u8(BUS + 0x4B)))
        if exc ~= 0 then
            fh:write(string.format("ACCESS=$%08X INSTR=$%04X\n", u32(BUS + 0x946), u16(BUS + 0x94A)))
            for i = 0, 7 do fh:write(string.format("D%d=$%08X ", i, u32(BUS + 0x908 + i*4))) end
            fh:write("\n")
            for i = 0, 6 do fh:write(string.format("A%d=$%08X ", i, u32(BUS + 0x908 + 32 + i*4))) end
            fh:write("\n")
        end
        fh:write("\n--- _m68k_tablejump ring buffer (last 16 calls) ---\n")
        fh:write(string.format("Ring cursor ($FF095C) = %d\n", u8(BUS + 0x95C)))
        for i = 0, 15 do
            local ret = u32(BUS + 0x960 + i*8)
            local d0  = u32(BUS + 0x960 + i*8 + 4)
            fh:write(string.format("  [%2d] return=$%08X D0=$%08X\n", i, ret, d0))
        end
        fh:write("\n--- Objects ---\n")
        for i = 0, 11 do
            local t = u8(BUS + 0x0350 + i)
            if t ~= 0 then
                fh:write(string.format("  slot %2d: type=$%02X x=$%02X y=$%02X dir=$%02X state=$%02X pFrac=$%02X gOff=$%02X qSpd=$%02X\n",
                    i, t, u8(BUS + 0x70 + i), u8(BUS + 0x84 + i), u8(BUS + 0x98 + i),
                    u8(BUS + 0xAC + i), u8(BUS + 0x3A8 + i), u8(BUS + 0x394 + i), u8(BUS + 0x3BC + i)))
            end
        end
        fh:close()
        dumped = true
        break
    end

    if frame - watch_start > TICKS_TO_WATCH then
        local fh = assert(io.open(OUT, "w"))
        fh:write(string.format("NO FREEZE within %d frames\n", TICKS_TO_WATCH))
        fh:write(string.format("fc=$%02X rm=$%02X\n", fc, rid))
        fh:close()
        dumped = true
        break
    end
end

client.exit()
