-- gen_state_watch.lua — continuously display + log game state.
-- Shows RoomId, CurLevel, GameMode, GameSub, tile-object-info, and text pointer.
-- Logs each LayoutRoomOrCaveOW + LayoutCaveAndAvanceSubmode call.

local OUT = "C:\\tmp\\_gen_state_watch.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"

local PC_LAYOUT_ENTRY     = 0x000447BA  -- LayoutRoomOrCaveOW
local PC_LAYOUT_CAVESUB   = 0x00044BC8  -- LayoutCaveAndAvanceSubmode
local PC_LAYOUT_OW        = 0x00044784  -- LayoutRoomOW
local PC_LAYOUT_ROOM      = 0x000445C6  -- LayOutRoom (dispatcher)
local PC_CHECKSHORTCUT    = 0x00044C06

local NES_RAM = 0xFF0000

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u32(a) memory.usememorydomain("M68K BUS"); return memory.read_u32_be(a) end

local lines = {}
local function P(s)
    lines[#lines+1] = s
    local fh = io.open(OUT, "w"); if fh then fh:write(table.concat(lines, "\n")); fh:write("\n"); fh:close() end
end

pcall(function() savestate.load(STATE_FILE) end)

local hit_layout = 0
local hit_cavesub = 0
local hit_layoutow = 0
local hit_layoutroom = 0
local hit_checkshortcut = 0
local last_rid = -1

local frame_n = 0

event.onmemoryexecute(function()
    hit_layout = hit_layout + 1
    P(string.format("[frame %d] LayoutRoomOrCaveOW: RoomId=$%02X CurLevel=$%02X GameMode=$%02X GameSub=$%02X layout_ptr=$%08X",
        frame_n, u8(NES_RAM+0xEB), u8(NES_RAM+0x10), u8(NES_RAM+0x12), u8(NES_RAM+0x13), u32(0xFF1102)))
end, PC_LAYOUT_ENTRY, "laye", "M68K BUS")

event.onmemoryexecute(function()
    hit_cavesub = hit_cavesub + 1
    P(string.format("[frame %d] LayoutCaveAndAvanceSubmode: RoomId=$%02X CurLevel=$%02X GameMode=$%02X GameSub=$%02X",
        frame_n, u8(NES_RAM+0xEB), u8(NES_RAM+0x10), u8(NES_RAM+0x12), u8(NES_RAM+0x13)))
end, PC_LAYOUT_CAVESUB, "cavs", "M68K BUS")

event.onmemoryexecute(function()
    hit_layoutow = hit_layoutow + 1
    P(string.format("[frame %d] LayoutRoomOW: RoomId=$%02X CurLevel=$%02X GameMode=$%02X GameSub=$%02X",
        frame_n, u8(NES_RAM+0xEB), u8(NES_RAM+0x10), u8(NES_RAM+0x12), u8(NES_RAM+0x13)))
end, PC_LAYOUT_OW, "owe", "M68K BUS")

event.onmemoryexecute(function()
    hit_layoutroom = hit_layoutroom + 1
    P(string.format("[frame %d] LayOutRoom: RoomId=$%02X CurLevel=$%02X GameMode=$%02X GameSub=$%02X",
        frame_n, u8(NES_RAM+0xEB), u8(NES_RAM+0x10), u8(NES_RAM+0x12), u8(NES_RAM+0x13)))
end, PC_LAYOUT_ROOM, "rm", "M68K BUS")

event.onmemoryexecute(function()
    hit_checkshortcut = hit_checkshortcut + 1
end, PC_CHECKSHORTCUT, "chk", "M68K BUS")

P("=== gen_state_watch started ===")

while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(NES_RAM+0xEB)
    local lvl = u8(NES_RAM+0x10)
    local mode = u8(NES_RAM+0x12)
    local sub = u8(NES_RAM+0x13)
    local tobjtype = u8(NES_RAM+0x52B)
    local tobjx = u8(NES_RAM+0x52C)
    local tobjy = u8(NES_RAM+0x52D)
    gui.text(10, 10, string.format("R$%02X L$%02X M$%02X S$%02X  TObj(t=$%02X x=$%02X y=$%02X)", rid, lvl, mode, sub, tobjtype, tobjx, tobjy))
    gui.text(10, 25, string.format("hits: layout=%d cavesub=%d OW=%d Rm=%d chk=%d", hit_layout, hit_cavesub, hit_layoutow, hit_layoutroom, hit_checkshortcut))
    if rid ~= last_rid then
        P(string.format("[frame %d] RoomId changed: $%02X -> $%02X  (lvl=$%02X mode=$%02X sub=$%02X)", frame_n, last_rid, rid, lvl, mode, sub))
        last_rid = rid
    end
end
