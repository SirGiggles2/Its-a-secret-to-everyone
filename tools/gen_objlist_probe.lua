-- gen_objlist_probe.lua — verify what's at the addresses ObjListAddrs points to
-- when PlaceList runs. Autopilot LEFT, dump ObjList memory regions around
-- room $75 entry.

local OUT = "C:\\tmp\\_gen_objlist_probe.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM = 0xFF0000

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u16(a) memory.usememorydomain("M68K BUS"); return memory.read_u16_be(a) end

local lines = {}
local function P(s)
    lines[#lines+1] = s
    local fh = io.open(OUT, "w"); if fh then fh:write(table.concat(lines, "\n")); fh:write("\n"); fh:close() end
end

-- Hook PlaceList start
local PC_PLACELIST = 0x00000000  -- placeholder, will find below
-- From z_05.asm line 2205: _L_z05_InitMode_EnterRoom_PlaceList
-- We'll scan and use PC of monster list ID load
local PC_INIT_CAVE = 0x0002D644

-- Instead, hook a simpler anchor: just hook any InitCave + log extensive state.
event.onmemoryexecute(function()
    local bank = u8(0xFF007A)  -- MMC1_PRG cache addr (if there) -- actually _current_window_bank
    P(string.format("=== InitCave fired ==="))
    P(string.format("  RoomId=$%02X GameMode=$%02X GameSub=$%02X", u8(NES_RAM+0xEB), u8(NES_RAM+0x12), u8(NES_RAM+0x13)))
    P(string.format("  ObjTypes $0350..$035B:"))
    local s = "    "
    for i=0,11 do s = s .. string.format(" %02X", u8(NES_RAM+0x0350+i)) end
    P(s)
    P(string.format("  ObjTypeFocus $0000=$%02X  $0001=$%02X  $0002=$%02X  $0003=$%02X  $0004=$%02X  $0005=$%02X",
        u8(NES_RAM+0x0000), u8(NES_RAM+0x0001), u8(NES_RAM+0x0002), u8(NES_RAM+0x0003), u8(NES_RAM+0x0004), u8(NES_RAM+0x0005)))
    P(string.format("  Ptr_by_$04_$05: if [$04,$05]=$%02X%02X then ($FF8F86 bank-win)=$%02X", u8(NES_RAM+5), u8(NES_RAM+4), u8(0xFF8F86)))
    P(string.format("  Bank window $FF8F86..$FF8F8B: %02X %02X %02X %02X %02X %02X",
        u8(0xFF8F86), u8(0xFF8F87), u8(0xFF8F88), u8(0xFF8F89), u8(0xFF8F8A), u8(0xFF8F8B)))
    P(string.format("  Bank window first 16 bytes $FF8000..: %02X %02X %02X %02X %02X %02X %02X %02X",
        u8(0xFF8000), u8(0xFF8001), u8(0xFF8002), u8(0xFF8003), u8(0xFF8004), u8(0xFF8005), u8(0xFF8006), u8(0xFF8007)))
    P(string.format("  _current_window_bank ($FF00xx): checking common addrs..."))
    for _, a in ipairs({0xFF007A, 0xFF00F0, 0xFF00F1, 0xFF1000, 0xFF1001}) do
        P(string.format("    $%06X=$%02X", a, u8(a)))
    end
end, PC_INIT_CAVE, "ic", "M68K BUS")

-- Also hook room entry
event.onmemoryexecute(function()
    P(string.format("[LayoutRoomOrCaveOW] RoomId=$%02X mode=$%02X", u8(NES_RAM+0xEB), u8(NES_RAM+0x12)))
end, 0x000447BA, "laye", "M68K BUS")

local frame_n = 0
P("=== gen_objlist_probe start ===")
while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local joy = {}
    if frame_n >= 60 then joy["Left"] = true end
    joypad.set(joy, 1)
    gui.text(10, 10, string.format("frame=%d room=$%02X", frame_n, u8(NES_RAM+0xEB)))
    if frame_n >= 500 then
        P("[end]")
        break
    end
end
