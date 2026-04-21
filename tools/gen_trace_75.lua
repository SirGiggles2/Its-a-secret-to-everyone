-- gen_trace_75.lua — trace LayoutRoomOrCaveOW execution on Gen for room $75.
-- Hooks the per-column and per-row entry points, dumps decoder state.
-- Writes incrementally to OUT. Does NOT call client.exit — user closes BizHawk.

local OUT = "C:\\tmp\\_gen_trace_75.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"

local PC_LAYOUT_ENTRY = 0x000447BA  -- LayoutRoomOrCaveOW
local PC_LOOPCOL      = 0x00044808  -- _L_z05_LayoutRoomOrCaveOW_LoopColumnOW
local PC_LOOPSQ       = 0x0004486E  -- _L_z05_LayoutRoomOrCaveOW_LoopSquareOW

local NES_RAM = 0xFF0000

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u32(a) memory.usememorydomain("M68K BUS"); return memory.read_u32_be(a) end

local lines = {}
local function flush()
    local fh = io.open(OUT, "w")
    if fh then fh:write(table.concat(lines, "\n")); fh:write("\n"); fh:close() end
end
local function P(s) lines[#lines+1] = s; flush() end

local capturing = false
local col_count = 0
local room_captured = 0

pcall(function() savestate.load(STATE_FILE) end)

local function on_layout_entry()
    local rid = u8(NES_RAM + 0xEB)
    -- Capture every LayoutRoomOrCaveOW call; track room ID changes.
    if capturing then
        P(string.format("\n=== RE-ENTRY RoomId=$%02X (prev cols=%d) ===", rid, col_count))
    else
        P(string.format("=== LayoutRoomOrCaveOW entry, RoomId=$%02X ===", rid))
    end
    capturing = true
    col_count = 0
    room_captured = rid
end

local function on_loopcol()
    if not capturing then return end
    local col = u8(NES_RAM + 0x06)
    local layout_ptr = u32(0xFF1102)
    local heap_ptr = u32(0xFF1106)
    local flag = u8(NES_RAM + 0x0C)
    local wb_ptr = u32(0xFF110A)
    local desc = 0
    if layout_ptr >= 0x100 and layout_ptr < 0x01000000 then
        local ok, v = pcall(u8, layout_ptr + col)
        if ok then desc = v end
    end
    P(string.format("COL %02d: layout=$%08X heap=$%08X wb=$%08X flag=$%02X desc=$%02X (hi=%X lo=%X)",
        col, layout_ptr, heap_ptr, wb_ptr, flag, desc, (desc>>4)&0xF, desc&0xF))
    col_count = col_count + 1
end

local function on_loopsq()
    if not capturing then return end
    local col = u8(NES_RAM + 0x06)
    local row = u8(NES_RAM + 0x07)
    local heap_ptr = u32(0xFF1106)
    local byte = 0
    if heap_ptr >= 0x100 and heap_ptr < 0x01000000 then
        local ok, v = pcall(u8, heap_ptr)
        if ok then byte = v end
    end
    local flag = u8(NES_RAM + 0x0C)
    local wb_ptr = u32(0xFF110A)
    P(string.format("  row %02d: heap=$%08X byte=$%02X (mt=$%02X bit6=%d bit7=%d) flag=$%02X wb=$%08X",
        row, heap_ptr, byte, byte&0x3F, (byte>>6)&1, (byte>>7)&1, flag, wb_ptr))
end

event.onmemoryexecute(on_layout_entry, PC_LAYOUT_ENTRY, "layoutentry", "M68K BUS")
event.onmemoryexecute(on_loopcol, PC_LOOPCOL, "loopcol", "M68K BUS")
event.onmemoryexecute(on_loopsq, PC_LOOPSQ, "loopsq", "M68K BUS")

while true do
    emu.frameadvance()
    local rid = u8(NES_RAM + 0xEB)
    gui.text(10, 10, string.format("room=$%02X cap=%s col=%d captured=$%02X", rid, tostring(capturing), col_count, room_captured))
    gui.text(10, 25, "Walk to room $75; trace writes to C:\\tmp\\_gen_trace_75.txt")
end
