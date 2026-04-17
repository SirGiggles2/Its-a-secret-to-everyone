-- nes_turbo_link.lua — TURBO_LINK cheat for vanilla NES Zelda.
-- Same effect as the Genesis port's TURBO_LINK + no-clip patches, but
-- applied at the Lua layer so no ROM modification is needed.
--
--   - +4 px/frame per held DPAD direction while in overworld idle.
--   - Collision skipped: Link can walk through any tile (walls, water,
--     rocks, trees, enemies' blockers).
--   - Screen-edge detection preserved: boost is clamped in the last
--     few pixels near each edge so the normal scroll transition latches.
--
-- Usage:
--   EmuHawk.exe --lua=tools\nes_turbo_link.lua "Legend of Zelda, The (USA).nes"

local ROOM    = 0x00EB
local OBJ_X   = 0x0070   -- Link is slot 0
local OBJ_Y   = 0x0084
local BUTTONS_HELD = 0x00FA   -- ButtonsDown
local CUR_LEVEL = 0x0010
local GAME_MODE = 0x0012
local GAME_SUB  = 0x0013

local BOOST     = 6
local X_MIN     = 0x0A
local X_MAX     = 0xE6
local Y_MIN     = 0x40
local Y_MAX     = 0xD0

local function u8(addr)
    memory.usememorydomain("System Bus")
    return memory.read_u8(addr)
end
local function w8(addr, val)
    memory.usememorydomain("System Bus")
    memory.write_u8(addr, val & 0xFF)
end

-- Track blocked-by-tile state. When Link's move was blocked by tile
-- collision, the game's "GoWalkableDir" / tile check sets flags that
-- keep ObjX/ObjY from advancing. We bypass that by directly writing
-- ObjX/ObjY from ButtonsDown each frame, gated on OW + idle.

-- Clear the game's "blocked / stopped by wall" flags each frame so
-- the NES walker never believes Link is against a wall.
-- $000E = alternate-direction search step (FF = blocked).
-- $0053 = StoppedByWall marker (set when Link hits a tile).
-- Keeping these at 0 prevents Walker from clamping his position.
local function clear_block_flags()
    w8(0x000E, 0)
    w8(0x0053, 0)
    w8(0x0394, 0)   -- GridOffset (keeps walker from "settling")
end

-- Main loop: every frame after the game logic runs, clear blocks
-- and apply boost. event.onframeend isn't always available across
-- BizHawk versions either, so we just do it all inline after
-- frameadvance — same net effect.
while true do
    emu.frameadvance()

    if u8(CUR_LEVEL) == 0x00
       and u8(GAME_MODE) == 0x05
       and u8(GAME_SUB) == 0x00 then
        clear_block_flags()
        local held = u8(BUTTONS_HELD) & 0x0F
        if held ~= 0 then
            if (held & 0x08) ~= 0 then
                local y = u8(OBJ_Y)
                if y > Y_MIN then w8(OBJ_Y, y - BOOST) end
            end
            if (held & 0x04) ~= 0 then
                local y = u8(OBJ_Y)
                if y < Y_MAX then w8(OBJ_Y, y + BOOST) end
            end
            if (held & 0x02) ~= 0 then
                local x = u8(OBJ_X)
                if x > X_MIN then w8(OBJ_X, x - BOOST) end
            end
            if (held & 0x01) ~= 0 then
                local x = u8(OBJ_X)
                if x < X_MAX then w8(OBJ_X, x + BOOST) end
            end
        end
    end
end
