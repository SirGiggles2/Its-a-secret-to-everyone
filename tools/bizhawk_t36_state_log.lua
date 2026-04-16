-- bizhawk_t36_state_log.lua
-- Logs every mode/room/input transition while you play. Output pinpoints
-- exactly when the cave-enter mode triggers + Link's coord at that instant.

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

local OUT = repo_path("builds\\reports\\t36_state_log.txt")
local txt = io.open(OUT, "w")
local function log(s)
    if txt then pcall(function() txt:write(s .. "\n"); txt:flush() end) end
    print(s)
end

log("T36 state log. Just play — walk into cave, come out, close window.")

event.onexit(function() pcall(function() if txt then txt:close() end end) end)

local BUTTONS = {"Up","Down","Left","Right","A","B","Start","Select"}

local prev_mode, prev_room, prev_btns = -1, -1, ""
local frame = 0

while true do
    frame = frame + 1
    memory.usememorydomain("RAM")
    local mode = memory.read_u8(0x0012)
    local sub  = memory.read_u8(0x0013)
    local room = memory.read_u8(0x00EB)
    local x    = memory.read_u8(0x0070)
    local y    = memory.read_u8(0x0084)

    local inp = joypad.get(1) or {}
    local pressed = {}
    for _, b in ipairs(BUTTONS) do
        if inp[b] or inp["P1 " .. b] then pressed[#pressed + 1] = b end
    end
    local btns = table.concat(pressed, ",")

    if mode ~= prev_mode or room ~= prev_room or btns ~= prev_btns then
        log(string.format(
            "f%05d mode=$%02X sub=$%02X room=$%02X link=($%02X,$%02X) btns=[%s]",
            frame, mode, sub, room, x, y, btns))
        prev_mode = mode; prev_room = room; prev_btns = btns
    end

    emu.frameadvance()
end
