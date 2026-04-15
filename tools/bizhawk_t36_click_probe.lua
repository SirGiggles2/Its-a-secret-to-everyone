-- bizhawk_t36_click_probe.lua
-- Click anywhere on the emulated screen; probe logs pixel coords, 16x16
-- tile (col,row), and current Link coords / mode / room. Use it to point
-- at the cave stair in room $77 and read back the exact RAM coord we need
-- to target in the scenario.
--
-- Output: builds/reports/t36_clicks.txt

dofile((function()
    local env_root = os.getenv("CODEX_BIZHAWK_ROOT")
    if env_root and env_root ~= "" then
        env_root = env_root:gsub("/", "\\")
        return env_root .. "\\tools\\probe_root.lua"
    end
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then source = source:sub(2) end
    source = source:gsub("/", "\\")
    local tools_dir = source:match("^(.*)\\[^\\]+$")
    return tools_dir .. "\\probe_root.lua"
end)())

local OUT = repo_path("builds\\reports\\t36_clicks.txt")
local txt = io.open(OUT, "w")
local function log(s)
    if txt then pcall(function() txt:write(s .. "\n"); txt:flush() end) end
    print(s)
end

log("T36 click probe. LEFT-CLICK on screen to log coords. Close BizHawk to save.")

event.onexit(function() pcall(function() if txt then txt:close() end end) end)

local ADDR_MODE    = 0x0012
local ADDR_ROOM_ID = 0x00EB
local ADDR_OBJ_X   = 0x0070
local ADDR_OBJ_Y   = 0x0084

local prev_down = false
local click_idx = 0

while true do
    local m = input.getmouse()
    local down = m and m.Left
    if down and not prev_down then
        click_idx = click_idx + 1
        local px, py = m.X or 0, m.Y or 0
        local col, row = math.floor(px / 16), math.floor(py / 16)
        memory.usememorydomain("RAM")
        local mode = memory.read_u8(ADDR_MODE)
        local room = memory.read_u8(ADDR_ROOM_ID)
        local lx   = memory.read_u8(ADDR_OBJ_X)
        local ly   = memory.read_u8(ADDR_OBJ_Y)
        log(string.format(
            "CLICK %d  px=(%d,%d)  tile=(col=%d,row=%d) = ($%02X,$%02X)  "
            .. "link=($%02X,$%02X) mode=$%02X room=$%02X",
            click_idx, px, py, col, row, col, row, lx, ly, mode, room))
        -- Overlay crosshair on clicked tile (16x16 box)
        gui.drawBox(col * 16, row * 16, col * 16 + 16, row * 16 + 16, 0xFFFF00FF, 0x4000FF00)
    end
    prev_down = down
    emu.frameadvance()
end
