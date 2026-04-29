-- nes_turbo_link.lua - no-clip + fast room traversal for vanilla NES Zelda.
--
-- Usage:
--   EmuHawk.exe --lua=tools\nes_turbo_link.lua "Legend of Zelda, The (USA).nes"
--
-- Hold the D-pad. Link is moved directly in RAM, wall-block flags are cleared,
-- and when he reaches a screen edge this script forces Zelda's normal adjacent
-- room transition. This avoids getting stuck on terrain while preserving room
-- loads, palettes, enemies, and scrolling.

local ROOM_ID       = 0x00EB
local OBJ_X         = 0x0070 -- Link is slot 0.
local OBJ_Y         = 0x0084
local OBJ_DIR       = 0x0098
local BUTTONS_HELD  = 0x00FA
local CUR_LEVEL     = 0x0010
local IS_UPDATING   = 0x0011
local GAME_MODE     = 0x0012
local GAME_SUB      = 0x0013
local ROOM_TRANS    = 0x004C
local STOPPED_WALL  = 0x0053
local WHIRL_PREV    = 0x00EA
local TRANS_DIR     = 0x00E7
local WHIRL_STATE   = 0x0522
local GRID_OFFSET   = 0x0394
local BLOCK_STEP    = 0x000E
local PAUSE_FLAG    = 0x00E0
local IN_SUB_MENU   = 0x00E1
local BUTTONS_PRESS = 0x00F8

local BOOST = tonumber(os.getenv("CODEX_NES_NOCLIP_BOOST") or "8") or 8

-- Keep away from underflow/overflow, but let the edge trigger happen before
-- clamping. These are Link's usual overworld play-area limits.
local X_MIN, X_MAX = 0x08, 0xE8
local Y_MIN, Y_MAX = 0x38, 0xD8

-- Trigger adjacent-room transitions a little before the hard clamp so holding
-- a direction at any walkable or blocked edge reliably advances rooms.
local EDGE_LEFT   = 0x12
local EDGE_RIGHT  = 0xDE
local EDGE_UP     = 0x42
local EDGE_DOWN   = 0xCE

local transition_cooldown = 0
local last_room = -1

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr)
end

local function w8(addr, value)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr, value & 0xFF)
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function clear_block_flags()
    w8(BLOCK_STEP, 0)
    w8(STOPPED_WALL, 0)
    w8(GRID_OFFSET, 0)
end

local function is_overworld_idle()
    return u8(CUR_LEVEL) == 0x00
       and u8(GAME_MODE) == 0x05
       and u8(GAME_SUB) == 0x00
       and u8(ROOM_TRANS) == 0x00
end

local function room_col(room)
    return room & 0x0F
end

local function room_row(room)
    return (room >> 4) & 0x0F
end

local function can_move_room(room, dir)
    if dir == "left" then return room_col(room) > 0 end
    if dir == "right" then return room_col(room) < 15 end
    if dir == "up" then return room_row(room) > 0 end
    if dir == "down" then return room_row(room) < 7 end
    return false
end

local function transition_bits(dir)
    if dir == "right" then return 0x01, 0x01 end
    if dir == "left"  then return 0x02, 0x02 end
    if dir == "down"  then return 0x04, 0x04 end
    if dir == "up"    then return 0x08, 0x08 end
    return 0x00, 0x00
end

local function force_adjacent_room(dir)
    local room = u8(ROOM_ID)
    if not can_move_room(room, dir) then
        return false
    end

    local trans_bit, obj_dir = transition_bits(dir)
    w8(WHIRL_PREV, room)
    w8(WHIRL_STATE, 1)
    w8(TRANS_DIR, trans_bit)
    w8(OBJ_DIR, obj_dir)
    w8(IS_UPDATING, 1)
    w8(GAME_MODE, 7)
    w8(GAME_SUB, 0)
    transition_cooldown = 45
    return true
end

local function apply_noclip()
    clear_block_flags()

    -- If Select pauses while testing, immediately unpause.
    w8(PAUSE_FLAG, 0)
    w8(IN_SUB_MENU, 0)
    if (u8(BUTTONS_PRESS) & 0x20) ~= 0 then
        w8(BUTTONS_PRESS, 0)
    end

    if transition_cooldown > 0 then
        transition_cooldown = transition_cooldown - 1
        return
    end

    local held = u8(BUTTONS_HELD) & 0x0F
    if held == 0 then
        return
    end

    local x = u8(OBJ_X)
    local y = u8(OBJ_Y)
    local moved_x = x
    local moved_y = y

    if (held & 0x08) ~= 0 then moved_y = moved_y - BOOST end -- Up
    if (held & 0x04) ~= 0 then moved_y = moved_y + BOOST end -- Down
    if (held & 0x02) ~= 0 then moved_x = moved_x - BOOST end -- Left
    if (held & 0x01) ~= 0 then moved_x = moved_x + BOOST end -- Right

    w8(OBJ_X, clamp(moved_x, X_MIN, X_MAX))
    w8(OBJ_Y, clamp(moved_y, Y_MIN, Y_MAX))

    -- Prefer horizontal when the user holds a diagonal, matching Zelda's
    -- one-direction-at-a-time screen transitions.
    if (held & 0x02) ~= 0 and moved_x <= EDGE_LEFT then
        force_adjacent_room("left")
    elseif (held & 0x01) ~= 0 and moved_x >= EDGE_RIGHT then
        force_adjacent_room("right")
    elseif (held & 0x08) ~= 0 and moved_y <= EDGE_UP then
        force_adjacent_room("up")
    elseif (held & 0x04) ~= 0 and moved_y >= EDGE_DOWN then
        force_adjacent_room("down")
    end
end

while true do
    emu.frameadvance()

    local room = u8(ROOM_ID)
    if room ~= last_room then
        transition_cooldown = 12
        last_room = room
    end

    if is_overworld_idle() then
        apply_noclip()
    end

    gui.text(8, 8, string.format(
        "NES no-clip  room $%02X  x=$%02X y=$%02X  boost=%d",
        u8(ROOM_ID), u8(OBJ_X), u8(OBJ_Y), BOOST
    ))
end
