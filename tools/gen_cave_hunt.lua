-- gen_cave_hunt.lua — autopilot LEFT, track InitCave + InitObject firings + person text state.

local OUT = "C:\\tmp\\_gen_cave_hunt.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM = 0xFF0000
local ROOM_ID = NES_RAM + 0xEB
local GAME_MODE = NES_RAM + 0x12

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u16(a) memory.usememorydomain("M68K BUS"); return memory.read_u16_be(a) end

local lines = {}
local function P(s)
    lines[#lines+1] = s
    local fh = io.open(OUT, "w"); if fh then fh:write(table.concat(lines, "\n")); fh:write("\n"); fh:close() end
end

local PC_INIT_CAVE   = 0x0002D644
local PC_INIT_OBJECT = 0x0004E0F0
local PC_LAYOUT_OW   = 0x00044784

local frame_n = 0
local last_room = -1

event.onmemoryexecute(function()
    local obj_type = u8(NES_RAM + 0x0350)
    P(string.format("[frame %d] InitCave: room=$%02X obj_type=$%02X mode=$%02X",
        frame_n, u8(ROOM_ID), obj_type, u8(GAME_MODE)))
end, PC_INIT_CAVE, "ic", "M68K BUS")

event.onmemoryexecute(function()
    -- InitObject runs per object. Log obj type at $0000,A4 at entry.
    local obj_type = u8(NES_RAM + 0x0000)
    if obj_type >= 0x6A or frame_n < 500 then
        P(string.format("[frame %d] InitObject: room=$%02X obj_type=$%02X mode=$%02X $0350=$%02X $0415=$%02X",
            frame_n, u8(ROOM_ID), obj_type, u8(GAME_MODE), u8(NES_RAM+0x0350), u8(NES_RAM+0x0415)))
    end
end, PC_INIT_OBJECT, "io", "M68K BUS")

event.onmemoryexecute(function()
    P(string.format("[frame %d] LayoutRoomOW: room=$%02X RoomAttrsC_byte=$%02X (from $FF697E+)",
        frame_n, u8(ROOM_ID), u8(0xFF697E + u8(ROOM_ID))))
end, PC_LAYOUT_OW, "lo", "M68K BUS")

P("=== gen_cave_hunt start ===")

while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(ROOM_ID)
    local mode = u8(GAME_MODE)
    gui.text(10, 10, string.format("room=$%02X mode=$%02X frame=%d", rid, mode, frame_n))
    if rid ~= last_room then
        P(string.format("[frame %d] room changed: $%02X -> $%02X (mode=$%02X) ObjType[0]=$%02X ObjType[1]=$%02X ObjType[2]=$%02X",
            frame_n, last_room, rid, mode,
            u8(NES_RAM+0x0350), u8(NES_RAM+0x0351), u8(NES_RAM+0x0352)))
        last_room = rid
    end
    local joy = {}
    if frame_n >= 60 then joy["Left"] = true; joy["P1 Left"] = true end
    joypad.set(joy, 1)
    if frame_n >= 500 then
        -- Dump RoomAttrsC byte for the current room, and relevant counters
        P(string.format("[frame %d final] room=$%02X mode=$%02X RoomAttrsC_sram=$%02X [0002]=$%02X [034E_obj_cnt]=$%02X [0350]=$%02X [0415_pts]=$%02X",
            frame_n, rid, mode,
            u8(0xFF697E + rid),
            u8(NES_RAM+0x0002),
            u8(NES_RAM+0x034E),
            u8(NES_RAM+0x0350),
            u8(NES_RAM+0x0415)))
        break
    end
end

P("=== end ===")
