-- gen_ntcache_tour2.lua — autopilot with verified joypad pressing.
-- From saved state at room $76, hold LEFT to walk to $75, dump NT_CACHE.

local OUT = "C:\\tmp\\_gen_ntcache_tour2.txt"
local STATE_FILE = "C:\\tmp\\_gen_state.State"
pcall(function() savestate.load(STATE_FILE) end)

local NES_RAM       = 0xFF0000
local ROOM_ID       = NES_RAM + 0xEB
local GAME_MODE     = NES_RAM + 0x12
local GAME_SUB      = NES_RAM + 0x13
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

local A_ORD = string.byte('A')
local function glyph(b)
    if b >= 0 and b <= 9 then return tostring(b) end
    if b >= 10 and b <= 35 then return string.char(A_ORD + (b-10)) end
    if b == 36 then return ' ' end
    if b == 42 then return "'" end
    return '.'
end

local function dump_ntcache(label)
    P("=== " .. label .. " ===")
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
        -- Flag rows with 4+ letter glyphs
        local letter_count = 0
        for c = 0, 31 do
            local v = u8(NT_CACHE_BASE + nt_row*32 + c)
            if v >= 10 and v <= 35 then letter_count = letter_count + 1 end
        end
        if letter_count >= 4 then P(text_s) end
    end
    P("")
end

-- Probe joypad button names available
local function probe_buttons()
    local j = joypad.get(1)
    if j then
        local names = {}
        for k, _ in pairs(j) do names[#names+1] = k end
        P("joypad.get(1) keys: " .. table.concat(names, ", "))
    else
        P("joypad.get(1) returned nil")
    end
end

local frame_n = 0
local last_room = u8(ROOM_ID)
local dumped = {}
local joy_probed = false

P(string.format("=== tour2 start — initial room=$%02X ===", last_room))

while true do
    emu.frameadvance()
    frame_n = frame_n + 1
    local rid = u8(ROOM_ID)
    local mode = u8(GAME_MODE)
    local sub = u8(GAME_SUB)
    local bp = u8(BUTTONS_PRESS)

    if not joy_probed and frame_n > 2 then
        probe_buttons()
        joy_probed = true
    end

    gui.text(10, 10, string.format("room=$%02X mode=$%02X sub=$%02X bp=$%02X frame=%d", rid, mode, sub, bp, frame_n))

    if rid ~= last_room then
        P(string.format("[frame %d] room changed: $%02X -> $%02X (mode=$%02X sub=$%02X)", frame_n, last_room, rid, mode, sub))
        last_room = rid
    end

    -- Dump NT_CACHE when stable (45 frames of play mode in a fresh room)
    if mode == 0x05 and rid ~= 0xFF and not dumped[rid] then
        local key = "_wait_"..rid
        if not dumped[key] then dumped[key] = frame_n end
        if frame_n - dumped[key] > 45 then
            dump_ntcache(string.format("room $%02X @ frame %d", rid, frame_n))
            dumped[rid] = true
        end
    end

    -- Hold LEFT from frame 100 onwards. Try multiple button naming conventions.
    local joy = {}
    if frame_n >= 100 then
        joy["P1 Left"] = true  -- Genesis BizHawk convention with player prefix
        joy["Left"] = true      -- Fallback plain name
    end
    joypad.set(joy, 1)

    if frame_n % 60 == 0 then
        P(string.format("[frame %d] holding Left, bp=$%02X room=$%02X", frame_n, bp, rid))
    end

    if frame_n >= 1800 then
        P("[autopilot done at frame 1800]")
        break
    end
end

P("=== tour2 end ===")
