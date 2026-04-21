-- gen_spawn_probe.lua — hook AssignObjSpawnPositions LoopSpawnSpot and log
-- exactly what byte is read for each iteration.

local OUT = "C:\\tmp\\_gen_spawn_probe.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM = 0xFF0000
local PC_LOOP = 0x00041858  -- _L_z05_AssignObjSpawnPositions_LoopSpawnSpot
local PC_ASSIGN = 0x000417F6  -- AssignObjSpawnPositions entry

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u32(a) memory.usememorydomain("M68K BUS"); return memory.read_u32_be(a) end

local lines = {}
local function P(s) lines[#lines+1]=s; local fh=io.open(OUT,"w"); if fh then fh:write(table.concat(lines,"\n"));fh:write("\n");fh:close() end end

local frame_n = 0
local iteration = 0

event.onmemoryexecute(function()
    local types = ""
    for i=0,7 do types = types .. string.format(" %02X", u8(NES_RAM+0x0350+i)) end
    P(string.format("[frame %d] AssignObjSpawnPositions entry: RoomId=$%02X Dir=$%02X ObjCnt=$%02X 0524=$%02X $0002=$%02X $04CD=$%02X",
        frame_n, u8(NES_RAM+0xEB), u8(NES_RAM+0x0098), u8(NES_RAM+0x034E), u8(NES_RAM+0x0524), u8(NES_RAM+0x0002), u8(NES_RAM+0x04CD)))
    P("  obj types $0350..$0357: " .. types)
    -- Initial X/Y
    local xs, ys = "", ""
    for i=0,7 do xs = xs .. string.format(" %02X", u8(NES_RAM+0x0070+i)) end
    for i=0,7 do ys = ys .. string.format(" %02X", u8(NES_RAM+0x0084+i)) end
    P("  initial X $0070..:" .. xs)
    P("  initial Y $0084..:" .. ys)
    iteration = 0
end, PC_ASSIGN, "ap", "M68K BUS")

-- Hook AssignSpecialPositions to see if that branch was taken
local PC_SPECIAL = 0x000418B2  -- _L_z05_AssignObjSpawnPositions_AssignSpecialPositions
event.onmemoryexecute(function()
    P(string.format("[frame %d] ! AssignSpecialPositions (special branch) room=$%02X mode=$%02X",
        frame_n, u8(NES_RAM+0xEB), u8(NES_RAM+0x12)))
end, PC_SPECIAL, "sp", "M68K BUS")

event.onmemoryexecute(function()
    iteration = iteration + 1
    -- At this PC, the loop is starting. [$06,$07] = spawn list ptr. D3 = position index.
    local ptr_lo = u8(NES_RAM+0x06)
    local ptr_hi = u8(NES_RAM+0x07)
    local ptr = (ptr_hi << 8) | ptr_lo
    local gen_ptr = 0xFF0000 + ptr
    local d3 = u8(NES_RAM+0x0524)  -- not D3 directly but last saved
    -- Try to dump the first 12 bytes at ptr
    local bytes = {}
    for i = 0, 11 do bytes[#bytes+1] = string.format("%02X", u8(gen_ptr + i)) end
    P(string.format("  iter %d: list_ptr=$%04X (gen=$%08X)  bytes: %s",
        iteration, ptr, gen_ptr, table.concat(bytes, " ")))
    if iteration >= 15 then P("[iteration cap reached]") end
end, PC_LOOP, "lsp", "M68K BUS")

P("=== gen_spawn_probe start ===")
local last_room = -1
local reached_frame = nil
while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(NES_RAM+0xEB)
    gui.text(10,10,string.format("room=$%02X iter=%d frame=%d",rid,iteration,frame_n))
    if rid ~= last_room then
        P(string.format("[frame %d] room: $%02X -> $%02X",frame_n,last_room,rid))
        last_room = rid
    end
    local joy = {}
    if rid ~= 0x73 and frame_n >= 40 then joy["Left"] = true end
    joypad.set(joy,1)
    if rid == 0x73 then
        if not reached_frame then reached_frame = frame_n end
        if frame_n - reached_frame > 300 then break end
    end
end
P("[done]")
