-- probe_nes_uw_collision.lua — capture NES UW PlayAreaTiles for collision parity
-- Run in BizHawk with a NES ROM (zelda1.nes). Navigates to a dungeon room and
-- dumps PlayAreaTiles ($6530-$65FB) + ObjectFirstUnwalkableTile ($034A).
--
-- Output: C:\tmp\nes_uw_collision\L<n>_Q<q>_R<room>.json per room captured.
--
-- Usage: Load zelda1.nes, set level + quest by memory poke, then run this script.
-- The script outputs JSON files consumable by tools/parity/verify_uw_collision.py.
--
-- Memory domains: "System Bus" for NES. $034A = collision threshold, $6530 = tiles.

local OUT_DIR = "C:\\tmp\\nes_uw_collision\\"
local frame = 0
local captured = {}

local NES_PLAY_AREA   = 0x6530   -- PlayAreaTiles: 32 cols × 22 rows, col-major stride 22
local NES_THRESHOLD   = 0x034A   -- ObjectFirstUnwalkableTile
local NES_CUR_ROOM    = 0x00EB   -- CurRoomId
local NES_CUR_LEVEL   = 0x00EC   -- CurLevel (0=OW, 1-9=dungeon)
local NES_GAME_MODE   = 0x0012   -- GameMode

local COLS = 32
local ROWS = 22

local function r8(addr)
    return memory.read_u8(addr, "System Bus")
end
-- NES has 8-bit bus so only r8 needed here

local function capture_room(level, quest, room_id)
    local key = string.format("L%dQ%dR%02X", level, quest, room_id)
    if captured[key] then return end
    captured[key] = true

    -- Read 704 bytes of PlayAreaTiles (32 cols × 22 rows)
    local tiles = {}
    for col = 0, COLS - 1 do
        for row = 0, ROWS - 1 do
            local addr = NES_PLAY_AREA + col * ROWS + row
            tiles[#tiles + 1] = r8(addr)
        end
    end

    local threshold = r8(NES_THRESHOLD)
    local fname = OUT_DIR .. key .. ".json"

    -- Write JSON
    local t_str = table.concat(tiles, ",")
    local json = string.format(
        '{"level":%d,"quest":%d,"room_id":%d,"first_unwalkable":%d,"play_area_tiles":[%s]}\n',
        level, quest, room_id, threshold, t_str
    )
    local f = io.open(fname, "w")
    if f then
        f:write(json)
        f:close()
        gui.text(2, 50, "SAVED: " .. key)
    else
        gui.text(2, 50, "ERR: cannot write " .. fname)
    end
end

local function ensure_out_dir()
    -- Try to create output dir by writing a dummy file
    local f = io.open(OUT_DIR .. "marker.txt", "w")
    if f then f:write("ok\n"); f:close() end
end

ensure_out_dir()

event.onframeend(function()
    frame = frame + 1
    local level = r8(NES_CUR_LEVEL)
    local room  = r8(NES_CUR_ROOM)
    local mode  = r8(NES_GAME_MODE)
    local thresh= r8(NES_THRESHOLD)

    gui.text(2, 2,  string.format("f=%d lvl=%d room=%02X", frame, level, room))
    gui.text(2, 14, string.format("mode=%02X thresh=%02X", mode, thresh))
    gui.text(2, 26, string.format("captured: %d", table_count(captured)))

    -- Capture when in dungeon and room layout is stable (mode 4 = play mode)
    if level >= 1 and level <= 9 and mode == 4 then
        capture_room(level, 1, room)  -- quest hardcoded to 1 here; change for Q2
    end

    if frame % 300 == 0 then
        gui.text(2, 38, "Press A/B to navigate rooms")
    end
end)

function table_count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
