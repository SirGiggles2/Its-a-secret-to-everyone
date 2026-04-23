-- bizhawk_record_inputs.lua
-- Records per-frame joypad state while the user plays. Written for the
-- Genesis core but works on any core: it logs whichever button keys
-- joypad.getimmediate() reports as true.
--
-- Output: builds/reports/recorded_inputs.txt
--   Format (one line per frame with any held button):
--     FRAME:BUTTON1|BUTTON2|...
--   Frames with no buttons held are omitted.
--
-- Usage:
--   1. Launch EmuHawk with this lua loaded.
--   2. Play through to the desired state (e.g. gameplay after name entry).
--   3. Close EmuHawk (Ctrl-C or window-close). File is flushed each frame.

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
    if not tools_dir then
        error("unable to resolve tools directory from '" .. source .. "'")
    end
    return tools_dir .. "\\probe_root.lua"
end)())

local OUT_PATH = repo_path("builds\\reports\\recorded_inputs.txt")
local MAX_FRAMES = 60 * 60 * 10  -- 10 minutes at 60 fps safety cap

local fh = io.open(OUT_PATH, "w")
if not fh then error("cannot open '" .. OUT_PATH .. "' for write") end
fh:write("# bizhawk_record_inputs.lua — per-frame joypad capture\n")
fh:write(string.format("# started=%s\n", os.date("%Y-%m-%dT%H:%M:%S")))
fh:flush()

local function serialize(state)
    local parts = {}
    for k, v in pairs(state or {}) do
        if v then
            -- Strip "P1 " prefix so output is core-agnostic.
            local name = k
            if name:sub(1, 3) == "P1 " then name = name:sub(4) end
            parts[#parts + 1] = name
        end
    end
    if #parts == 0 then return nil end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function poll()
    -- getimmediate captures raw hardware pad (what the user is physically
    -- holding). Falls back to joypad.get for older cores.
    local ok, state = pcall(function() return joypad.getimmediate() end)
    if ok and state then return state end
    return joypad.get(1)
end

local prev = nil
local held_count = 0
for frame = 1, MAX_FRAMES do
    local state = poll()
    local line = serialize(state)
    if line ~= nil then
        fh:write(string.format("%d:%s\n", frame, line))
        fh:flush()
        held_count = held_count + 1
    end
    prev = line
    gui.text(4, 4, string.format("REC f%d  held_frames=%d", frame, held_count))
    emu.frameadvance()
end

fh:write(string.format("# stopped=%s frames=%d held_frames=%d\n",
    os.date("%Y-%m-%dT%H:%M:%S"), MAX_FRAMES, held_count))
fh:close()
