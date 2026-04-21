-- gen_ntcache_tour.lua — autopilot: walk Link to $77, $76, $75 and dump
-- NT_CACHE play area at each step. Reveals where "IT'S DANGEROUS TO GO"
-- cave text first appears and persists.

local OUT = "C:\\tmp\\_gen_ntcache_tour.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM       = 0xFF0000
local ROOM_ID       = NES_RAM + 0xEB
local GAME_MODE     = NES_RAM + 0x12
local BUTTONS_PRESS = NES_RAM + 0xF8
local NT_CACHE_BASE = 0xFF0840
local PLAYMAP_BASE  = 0xFF6530
local PLANE_A_TOP   = 8

local function u8(a) memory.usememorydomain("M68K BUS"); return memory.read_u8(a) end

local lines = {}
local function P(s)
    lines[#lines+1] = s
    local fh = io.open(OUT, "w"); if fh then fh:write(table.concat(lines, "\n")); fh:write("\n"); fh:close() end
end

-- NES Zelda font map: 0-9 = digits, 10-35 = A-Z, 36 = space, 42 = '
local A_ORD = string.byte('A')
local function glyph(b)
    if b >= 0 and b <= 9 then return tostring(b) end
    if b >= 10 and b <= 35 then return string.char(A_ORD + (b-10)) end
    if b == 36 then return ' ' end
    if b == 42 then return "'" end
    if b == 44 then return '.' end
    return '.'
end

local function dump_ntcache(label)
    P("=== " .. label .. " (RoomId=$" .. string.format("%02X", u8(ROOM_ID)) .. ") ===")
    -- Dump play area rows 0-21 (nametable rows 8-29)
    for pr = 0, 21 do
        local nt_row = PLANE_A_TOP + pr
        local s = string.format("r%02d[nt%02d]:", pr, nt_row)
        local text_s = "  text:"
        for c = 0, 31 do
            local v = u8(NT_CACHE_BASE + nt_row*32 + c)
            s = s .. string.format(" %3d", v)
            text_s = text_s .. glyph(v)
        end
        P(s)
        if text_s:match("[A-Z][A-Z]") then P(text_s) end
    end
    -- Also dump playmap row 5 for comparison
    P("  playmap_row5:")
    local s = "    "
    for c = 0, 31 do s = s .. string.format(" %3d", u8(PLAYMAP_BASE + 5 + c*22)) end
    P(s)
    P("")
end

-- Also hook LayoutRoomOrCaveOW to tag decoder runs
local PC_LAYOUT_ENTRY = 0x000447BA
event.onmemoryexecute(function()
    P(string.format("[decoder] LayoutRoomOrCaveOW: RoomId=$%02X GameMode=$%02X GameSub=$%02X",
        u8(ROOM_ID), u8(GAME_MODE), u8(NES_RAM + 0x13)))
end, PC_LAYOUT_ENTRY, "laye", "M68K BUS")

local frame_n = 0
local state = "wait_boot"
local last_room = -1
local dumped = {}

P("=== gen_ntcache_tour start ===")

while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(ROOM_ID)
    local mode = u8(GAME_MODE)

    gui.text(10, 10, string.format("room=$%02X mode=$%02X state=%s frame=%d", rid, mode, state, frame_n))

    -- Detect room change and dump when stable
    if rid ~= last_room then
        P(string.format("[frame %d] room changed: $%02X -> $%02X (mode=$%02X)", frame_n, last_room, rid, mode))
        last_room = rid
    end

    -- Once in play mode ($05), take a snapshot of each new room we visit
    if mode == 0x05 and rid ~= 0xFF and not dumped[rid] then
        -- Wait ~45 frames of stable play mode to ensure scroll has settled
        if not dumped["_wait_"..rid] then
            dumped["_wait_"..rid] = frame_n
        end
        if frame_n - dumped["_wait_"..rid] > 45 then
            dump_ntcache(string.format("room $%02X @ frame %d", rid, frame_n))
            dumped[rid] = true
        end
    end

    -- Autopilot: hold LEFT from frame 400 onwards to push Link westward.
    -- NES buttons: A=$80, B=$40, Select=$20, Start=$10, Up=$08, Down=$04, Left=$02, Right=$01
    local joy = {}
    if frame_n >= 180 and frame_n < 380 then
        -- Start+A to bypass title/file select if needed
        if frame_n % 30 < 3 then joy["Start"] = true end
    elseif frame_n >= 400 and frame_n < 2400 then
        joy["Left"] = true
    end
    joypad.set(joy, 1)

    if frame_n >= 2500 then
        P("[autopilot done]")
        break
    end
end

P("=== tour end ===")
