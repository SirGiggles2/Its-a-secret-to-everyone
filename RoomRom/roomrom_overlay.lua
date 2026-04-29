-- RoomRom manual exploration overlay.
-- Starts at RoomRom's boot room 0x77 and mirrors its edge-triggered D-pad
-- navigation so the visible room ID stays in sync while testing.

local room_id = 0x77
local map_id = 0
local prev = {}

local function pressed(pad, name)
    return (pad[name] or pad["P1 " .. name]) and not (prev[name] or prev["P1 " .. name])
end

local function draw_room_id()
    local col = room_id % 16
    local row = math.floor(room_id / 16)
    gui.drawBox(0, 0, 96, 15, 0x000000FF, 0x000000D0)
    local map_name = (map_id == 1) and "REDUX" or "ORIG"
    gui.text(4, 3, string.format("%s ROOM %02X  %02d,%02d", map_name, room_id, col, row), "white", "black")
end

event.onframeend(function()
    local pad = joypad.get(1)
    local col = room_id % 16
    local row = math.floor(room_id / 16)

    if pressed(pad, "Left") and col > 0 then
        col = col - 1
    elseif pressed(pad, "Right") and col < 15 then
        col = col + 1
    elseif pressed(pad, "Up") and row > 0 then
        row = row - 1
    elseif pressed(pad, "Down") and row < 7 then
        row = row + 1
    end

    if pressed(pad, "C") then
        map_id = 1 - map_id
    end

    room_id = row * 16 + col
    draw_room_id()
    prev = pad
end)
