local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\VDP rebirth tools and asms\\WHAT IF\\builds\\reports\\"
local OUT_PATH = OUT_DIR .. "bizhawk_phase3_click_locator.txt"

local CURRENT_ROOM_ID = 0xFF003C
local LINK_PLACEHOLDER_X = 0xFF0048
local LINK_PLACEHOLDER_Y = 0xFF004A
local ROOM_TRANSITION_ACTIVE = 0xFF004C
local ROOM_TRANSITION_DIRECTION = 0xFF004E
local ROOM_TRANSITION_OFFSET = 0xFF0050
local ROOM_CONTEXT_MODE = 0xFF0056

local ROOM_TRANSITION_RIGHT = 1
local ROOM_TRANSITION_LEFT = 2
local ROOM_TRANSITION_DOWN = 3
local ROOM_TRANSITION_UP = 4

os.execute('if not exist "' .. OUT_DIR .. '" mkdir "' .. OUT_DIR .. '"')
local log_file = assert(io.open(OUT_PATH, "w"))

local function log(msg)
    log_file:write(msg .. "\n")
    log_file:flush()
    print(msg)
end

local function read_u16(addr)
    memory.usememorydomain("M68K BUS")
    return memory.read_u16_be(addr)
end

local function get_mouse_state()
    local ok, mouse = pcall(input.getmouse)
    if ok and type(mouse) == "table" then
        local x = mouse.X or mouse.x
        local y = mouse.Y or mouse.y
        local left = mouse.Left or mouse.left or false
        return x, y, left
    end

    local state = input.get()
    local x = state.xmouse or state.XMouse
    local y = state.ymouse or state.YMouse
    local left = state.leftclick or state.LeftClick or false
    return x, y, left
end

local function apply_transition_adjust(mx, my, direction, offset)
    local rx = mx
    local ry = my

    if direction == ROOM_TRANSITION_RIGHT then
        rx = rx + offset
    elseif direction == ROOM_TRANSITION_LEFT then
        rx = rx - offset
    elseif direction == ROOM_TRANSITION_DOWN then
        ry = ry + offset
    elseif direction == ROOM_TRANSITION_UP then
        ry = ry - offset
    end

    return rx, ry
end

local function main()
    log("WHAT IF Phase 3 click locator started")
    log("Left-click to capture a target. Close BizHawk to stop.")

    local last_left = false
    local sample = 0

    while true do
        local room = read_u16(CURRENT_ROOM_ID)
        local link_x = read_u16(LINK_PLACEHOLDER_X)
        local link_y = read_u16(LINK_PLACEHOLDER_Y)
        local mode = read_u16(ROOM_CONTEXT_MODE)
        local t_active = read_u16(ROOM_TRANSITION_ACTIVE)
        local t_dir = read_u16(ROOM_TRANSITION_DIRECTION)
        local t_off = read_u16(ROOM_TRANSITION_OFFSET)

        local mx, my, left = get_mouse_state()

        gui.text(4, 4, string.format("room=%04X mode=%d link=(%d,%d)", room, mode, link_x, link_y), "white", "black")
        gui.text(4, 16, string.format("transition active=%d dir=%d off=%d", t_active, t_dir, t_off), "white", "black")

        if mx ~= nil and my ~= nil then
            local rx = mx
            local ry = my
            if t_active ~= 0 then
                rx, ry = apply_transition_adjust(mx, my, t_dir, t_off)
            end

            gui.text(4, 28, string.format("mouse screen=(%d,%d) room_adj=(%d,%d)", mx, my, rx, ry), "yellow", "black")

            if left and (not last_left) then
                sample = sample + 1
                log(string.format(
                    "sample=%d room=%04X mode=%d transition(active=%d dir=%d off=%d) click_screen=(%d,%d) click_room_adj=(%d,%d) link=(%d,%d)",
                    sample, room, mode, t_active, t_dir, t_off, mx, my, rx, ry, link_x, link_y
                ))
            end
        else
            gui.text(4, 28, "mouse unavailable (click inside game window)", "red", "black")
        end

        last_left = left or false
        emu.frameadvance()
    end
end

local ok, err = pcall(main)
if not ok then
    log("WHAT IF Phase 3 click locator stopped: " .. tostring(err))
end

log_file:close()
