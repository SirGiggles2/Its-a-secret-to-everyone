-- gen_trace_75_post.lua — trace POST-decoder writes to the playmap.
-- Hooks CheckShortcut, ChangePlayMapSquareOW, WriteSquareOW, WriteSquareOW_P35.
-- Dumps playmap snapshot when LayoutRoomOrCaveOW exits, and logs every later write.

local OUT = "C:\\tmp\\_gen_trace_75_post.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"

local PC_LAYOUT_ENTRY = 0x000447BA
local PC_CHECKSHORTCUT = 0x00044C06
local PC_CHANGEPLAYMAP = 0x00044CDA
local PC_WRITESQ       = 0x00044A42
local PC_WRITESQ_P35   = 0x000449E0

local NES_RAM = 0xFF0000
local WORKBUF_BASE = 0xFF6530

local function u8(a)  memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end
local function u16(a) memory.usememorydomain("M68K BUS"); return memory.read_u16_be(a) end
local function u32(a) memory.usememorydomain("M68K BUS"); return memory.read_u32_be(a) end

local lines = {}
local function flush()
    local fh = io.open(OUT, "w")
    if fh then fh:write(table.concat(lines, "\n")); fh:write("\n"); fh:close() end
end
local function P(s) lines[#lines+1] = s; flush() end

local armed = false
local layout_done = false
local post_writes = 0

pcall(function() savestate.load(STATE_FILE) end)

local function read_playmap()
    local rows = {}
    for row=0,21 do
        local r={}
        for col=0,31 do r[#r+1]=u8(WORKBUF_BASE + row + col*22) end
        rows[#rows+1] = r
    end
    return rows
end

local function dump_playmap(label)
    local rows = read_playmap()
    P("=== " .. label .. " ===")
    for r=0,21 do
        local s = string.format("r%02d:", r)
        for c=0,31 do s = s .. string.format(" %3d", rows[r+1][c+1]) end
        P(s)
    end
end

local saved_playmap = nil
local function capture_playmap_snapshot()
    saved_playmap = read_playmap()
end

local function diff_playmap(label)
    if not saved_playmap then return end
    local cur = read_playmap()
    local diffs = {}
    for r=1,22 do
        for c=1,32 do
            if saved_playmap[r][c] ~= cur[r][c] then
                diffs[#diffs+1] = string.format("(col=%d,row=%d): %d->%d", c-1, r-1, saved_playmap[r][c], cur[r][c])
            end
        end
    end
    if #diffs > 0 then
        P(label .. " changed " .. #diffs .. " tiles: " .. table.concat(diffs, "  "))
        saved_playmap = cur
    end
end

local function on_layout_entry()
    if u8(NES_RAM + 0xEB) ~= 0x75 then return end
    if armed then return end
    armed = true
    layout_done = false
    P("=== LayoutRoomOrCaveOW($75) entry — arming post-decoder probes ===")
end

-- We don't have a reliable LayoutRoomOrCaveOW exit PC, so we rely on the NEXT
-- caller-level hook (CheckShortcut) as "decoder done".
local function on_checkshortcut()
    if not armed then return end
    if not layout_done then
        layout_done = true
        P("\n>>> Decoder done. Dumping playmap before CheckShortcut <<<")
        dump_playmap("PLAYMAP AFTER DECODER")
        capture_playmap_snapshot()
    end
    P(string.format("\n--- CheckShortcut called ($00:01=$%02X:%02X, D3 state unknown) ---", u8(NES_RAM), u8(NES_RAM+1)))
end

local function on_changeplaymap()
    if not armed or not layout_done then return end
    P(string.format("\n--- ChangePlayMapSquareOW called ($00:01=$%02X:%02X) ---", u8(NES_RAM), u8(NES_RAM+1)))
end

local function on_writesq()
    if not armed or not layout_done then return end
    local sq_idx = u8(NES_RAM + 0x0D)
    local ptr_lo = u8(NES_RAM + 0)
    local ptr_hi = u8(NES_RAM + 1)
    local y_off_approx = u8(NES_RAM + 0x0E)  -- D3 might come from various places; log zp
    post_writes = post_writes + 1
    P(string.format("  WriteSquareOW #%d: sq_idx=$%02X ptr=$%02X%02X  nes_zp_0E=$%02X",
        post_writes, sq_idx, ptr_hi, ptr_lo, y_off_approx))
    -- Dump playmap changes after this write (allow next frame to settle not needed since it's synchronous)
end

local function on_writesq_p35()
    if not armed or not layout_done then return end
    local sq_idx = u8(NES_RAM + 0x0D)
    local wb = u32(0xFF110A)
    post_writes = post_writes + 1
    P(string.format("  WriteSquareOW_P35 #%d: sq_idx=$%02X wb=$%08X",
        post_writes, sq_idx, wb))
end

event.onmemoryexecute(on_layout_entry, PC_LAYOUT_ENTRY, "laye", "M68K BUS")
event.onmemoryexecute(on_checkshortcut, PC_CHECKSHORTCUT, "chks", "M68K BUS")
event.onmemoryexecute(on_changeplaymap, PC_CHANGEPLAYMAP, "chgp", "M68K BUS")
event.onmemoryexecute(on_writesq, PC_WRITESQ, "wsq", "M68K BUS")
event.onmemoryexecute(on_writesq_p35, PC_WRITESQ_P35, "wsq35", "M68K BUS")

-- Every 30 frames after arming, check for playmap diffs vs snapshot
local frame_n = 0
while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(NES_RAM + 0xEB)
    gui.text(10, 10, string.format("room=$%02X armed=%s done=%s writes=%d", rid, tostring(armed), tostring(layout_done), post_writes))
    if armed and layout_done and (frame_n % 30 == 0) then
        diff_playmap(string.format("frame %d diff", frame_n))
    end
end
