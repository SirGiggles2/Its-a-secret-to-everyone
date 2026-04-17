-- nes_room_capture.lua — combined turbo-Link + hotkey capture for NES.
--
-- While running:
--   * Hold DPAD → turbo Link (+6 px/frame, no-clip).
--   * Press SELECT (on your NES pad) → dump current room to
--     builds/reports/rooms/nes_room_XX.json (XX = RoomId hex).
--
-- Use it to walk to a room, press Select to capture, walk to next, etc.
-- Pair with tools/gen_room_capture.lua + tools/compare_one_room.py.

local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\rooms"
local STATE_FILE = OUT_DIR .. "\\_nes_state.State"

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
do
    local f = io.open(STATE_FILE, "rb")
    if f then
        f:close()
        local ok = pcall(function() savestate.load(STATE_FILE) end)
        if ok then gui.text(10, 50, "Loaded NES state") end
    end
end

local ROOM_ID       = 0x00EB
local OBJ_X         = 0x0070
local OBJ_Y         = 0x0084
local BUTTONS_PRESS = 0x00F8
local BUTTONS_HELD  = 0x00FA
local CUR_LEVEL     = 0x0010
local GAME_MODE     = 0x0012
local GAME_SUB      = 0x0013
local CIRAM_BASE    = 0x0100
local ATTR_BASE     = 0x03C0
local ROOM_ROWS     = 22
local ROOM_COLS     = 32
local PLAY_AREA_NT_TOP = 8
local BOOST         = 6
local X_MIN, X_MAX  = 0x0A, 0xE6
local Y_MIN, Y_MAX  = 0x40, 0xD0

local function u8(addr)
    memory.usememorydomain("System Bus"); return memory.read_u8(addr)
end
local function w8(addr, val)
    memory.usememorydomain("System Bus"); memory.write_u8(addr, val & 0xFF)
end
local function ciram_u8(addr)
    for _, d in ipairs({"CIRAM (nametables)", "CIRAM", "Nametable RAM"}) do
        local ok, v = pcall(function() memory.usememorydomain(d); return memory.read_u8(addr) end)
        if ok then return v end
    end
    return 0
end

-- Palette domain probe: enumerate BizHawk's actual domain list, use
-- ONLY a 32-byte palette-specific domain. Fall back to reading 0s if
-- the core doesn't expose one (comparator tolerates zeros).
local PAL_DOMAIN, PAL_BASE = nil, 0
do
    local ok_list, domains = pcall(memory.getmemorydomainlist)
    if ok_list and domains then
        for _, d in ipairs(domains) do
            local name = (type(d) == "table") and (d.Name or tostring(d)) or tostring(d)
            local lower = name:lower()
            if lower:find("palette") then
                local sz_ok, sz = pcall(memory.getmemorydomainsize, name)
                if sz_ok and sz and sz <= 64 then
                    PAL_DOMAIN = name; PAL_BASE = 0; break
                end
            end
        end
    end
end

local function dump_visible_rows()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local vals = {}
        local base = CIRAM_BASE + row * ROOM_COLS
        for col = 0, ROOM_COLS-1 do vals[#vals+1] = ciram_u8(base+col) end
        rows[#rows+1] = vals
    end
    return rows
end

local function dump_palette_rows()
    local rows = {}
    for row = 0, ROOM_ROWS-1 do
        local vals = {}
        for col = 0, ROOM_COLS-1 do
            local ntrow = PLAY_AREA_NT_TOP + row
            local ac, ar = col >> 2, ntrow >> 2
            local byte = ciram_u8(ATTR_BASE + ar*8 + ac)
            local qx, qy = (col>>1) & 1, (ntrow>>1) & 1
            local shift = (qy*2 + qx) * 2
            vals[#vals+1] = (byte >> shift) & 3
        end
        rows[#rows+1] = vals
    end
    return rows
end

local function dump_palette_ram()
    local vals = {}
    if not PAL_DOMAIN then for i=1,16 do vals[i]=0 end; return vals end
    memory.usememorydomain(PAL_DOMAIN)
    for i = 0, 15 do
        local ok, v = pcall(function() return memory.read_u8(PAL_BASE+i) end)
        vals[#vals+1] = ok and v or 0
    end
    return vals
end

local function json_array_1d(t)
    local s={}; for i=1,#t do s[#s+1]=tostring(t[i]) end; return "["..table.concat(s,",").."]"
end
local function json_array_2d(rs)
    local s={}; for i=1,#rs do s[#s+1]=json_array_1d(rs[i]) end; return "["..table.concat(s,",").."]"
end

local function capture()
    local rid = u8(ROOM_ID)
    local path = string.format("%s\\nes_room_%02X.json", OUT_DIR, rid)
    os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
    local fh = io.open(path, "w")
    if not fh then return end
    fh:write("{\n")
    fh:write('  "system": "nes",\n')
    fh:write('  "room_id": ', tostring(rid), ',\n')
    fh:write('  "visible_rows": ', json_array_2d(dump_visible_rows()), ',\n')
    fh:write('  "palette_rows": ', json_array_2d(dump_palette_rows()), ',\n')
    fh:write('  "palette_ram": ', json_array_1d(dump_palette_ram()), '\n')
    fh:write("}\n")
    fh:close()
    return rid, path
end

local function clear_block_flags()
    w8(0x000E, 0); w8(0x0053, 0); w8(0x0394, 0)
end

local last_select_held = false
local last_captured_frame = 0
local frame_n = 0

while true do
    emu.frameadvance()
    frame_n = frame_n + 1

    if u8(CUR_LEVEL) == 0 and u8(GAME_MODE) == 0x05 and u8(GAME_SUB) == 0 then
        -- turbo + no-clip
        clear_block_flags()
        local held = u8(BUTTONS_HELD) & 0x0F
        if held ~= 0 then
            if (held & 0x08) ~= 0 then local y=u8(OBJ_Y); if y>Y_MIN then w8(OBJ_Y, y-BOOST) end end
            if (held & 0x04) ~= 0 then local y=u8(OBJ_Y); if y<Y_MAX then w8(OBJ_Y, y+BOOST) end end
            if (held & 0x02) ~= 0 then local x=u8(OBJ_X); if x>X_MIN then w8(OBJ_X, x-BOOST) end end
            if (held & 0x01) ~= 0 then local x=u8(OBJ_X); if x<X_MAX then w8(OBJ_X, x+BOOST) end end
        end

        -- Capture hotkey: keyboard F12 (doesn't touch the game pad).
        local keys = input.get() or {}
        local key_now = keys.F9 == true and (keys.Shift == true or keys.LeftShift == true or keys.RightShift == true)
        if key_now and not last_select_held and (frame_n - last_captured_frame) > 30 then
            local rid, path = capture()
            pcall(function() savestate.save(STATE_FILE) end)
            last_captured_frame = frame_n
            gui.text(10, 30, string.format("Captured room $%02X + state", rid or 0))
        end
        last_select_held = key_now
    end

    gui.text(10, 10, string.format("NES room $%02X  (Select=capture)", u8(ROOM_ID)))
end
