-- Passive human-input recorder for Debug.md.
-- It does not drive the game. It only reads the live controller state,
-- overlays a small REC marker, and writes JSONL records for replay/debugging.

local DEFAULT_OUT_PATH =
    "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\human_input_recording\\" ..
    os.date("input_%Y%m%d_%H%M%S.jsonl")

local OUT_PATH = os.getenv("HUMAN_INPUT_RECORD_OUT") or DEFAULT_OUT_PATH

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

local function domain_exists(name)
    for _, domain in ipairs(memory.getmemorydomainlist()) do
        if domain == name then return true end
    end
    return false
end

local DOMAIN = "M68K BUS"
local PROBE_BASE = 0x00FF7000
local RAM_BASE = 0x00FF8000
if domain_exists("68K RAM") then
    DOMAIN = "68K RAM"
    PROBE_BASE = 0x7000
    RAM_BASE = 0x8000
elseif domain_exists("M68K RAM") then
    DOMAIN = "M68K RAM"
    PROBE_BASE = 0x7000
    RAM_BASE = 0x8000
end

local function r8(addr)
    memory.usememorydomain(DOMAIN)
    return memory.read_u8(addr) or 0
end

local function r16(addr)
    return r8(addr) * 256 + r8(addr + 1)
end

local BUTTONS = {
    "Up", "Down", "Left", "Right", "A", "B", "C", "Start", "X", "Y", "Z", "Mode",
}

local function poll()
    local ok, state = pcall(function() return joypad.getimmediate() end)
    if ok and state then return state end
    return joypad.get(1) or {}
end

local function pressed_buttons(state)
    local out = {}
    for _, b in ipairs(BUTTONS) do
        if state[b] or state["P1 " .. b] then
            out[#out + 1] = b
        end
    end
    return out
end

local function jstr(s)
    return '"' .. tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function jarray(items)
    local parts = {}
    for _, item in ipairs(items) do parts[#parts + 1] = jstr(item) end
    return "[" .. table.concat(parts, ",") .. "]"
end

mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
f:write('{"event":"start","domain":' .. jstr(DOMAIN) .. ',"path":' .. jstr(OUT_PATH) .. '}\n')
f:flush()

local last_line = nil
while true do
    local frame = emu.framecount()
    local state = poll()
    local buttons = pressed_buttons(state)
    local line = string.format(
        '{"frame":%d,"buttons":%s,"probe_magic":%d,"debug_state":%d,"title_phase":%d,"roomrom_scene":%d,"room_id":%d,"link_x":%d,"link_y":%d}',
        frame,
        jarray(buttons),
        (r8(PROBE_BASE + 0) == 0xA4 and r8(PROBE_BASE + 1) == 0x4A) and 1 or 0,
        r8(PROBE_BASE + 13),
        r8(RAM_BASE + 0x07F0),
        r8(PROBE_BASE + 14),
        r8(PROBE_BASE + 15),
        r16(PROBE_BASE + 16),
        r16(PROBE_BASE + 18)
    )
    if #buttons > 0 or (frame % 30) == 0 or line ~= last_line then
        f:write(line .. "\n")
        f:flush()
        last_line = line
    end
    gui.text(4, 4, "REC human input -> " .. OUT_PATH)
    emu.frameadvance()
end
