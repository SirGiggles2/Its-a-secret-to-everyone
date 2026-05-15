-- Phase 14 simplified dungeon probe template.
--
-- This is the "load-only verify" variant of dungeon_template.lua. It
-- proves the save state loads cleanly + RAM matches entry preconditions
-- but does NOT run boss-kill input. Use this template until per-dungeon
-- INPUT_SEQUENCE arrays are authored (see master plan Task 14.0).
--
-- Per-dungeon usage:
-- 1. Copy this template to dungeon_<L>_q<N>.lua
-- 2. Fill LABEL, LEVEL, QUEST, SAVE_STATE_PATH, EXPECTED_ROOM, EXPECTED_LEVEL
-- 3. Run via tools/dungeon_harness/run_all.py once save state lands

local LABEL = "L7Q2"
local LEVEL = 7
local QUEST = 2
local SAVE_STATE_PATH = "L7Q2.State"
local EXPECTED_ROOM   = 0x52  -- expected NES RoomId at entry
local EXPECTED_LEVEL  = 7     -- expected NES CurLevel at entry

local OUT_DIR  = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\dungeon_harness\\"
local OUT_PATH = OUT_DIR .. LABEL .. ".json"

local RAM_ROOM_ID    = 0x00EB
local RAM_LEVEL      = 0x0010
local RAM_HEARTS     = 0x0000

local function domain_exists(name)
    for _, d in ipairs(memory.getmemorydomainlist()) do
        if d == name then return true end
    end
    return false
end

local RAM_DOMAIN = "M68K BUS"
local CELL_BASE = 0x00FF0000
if domain_exists("68K RAM") then
    RAM_DOMAIN = "68K RAM"; CELL_BASE = 0x0000
end

local function r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(CELL_BASE + addr)
end

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"') end
end

-- Phase 1: load save state.
if SAVE_STATE_PATH then
    savestate.load(SAVE_STATE_PATH)
    emu.frameadvance()
end

-- Phase 2: capture entry RAM.
local entry = {
    frame  = emu.framecount(),
    room   = r8(RAM_ROOM_ID),
    level  = r8(RAM_LEVEL),
    hearts = r8(RAM_HEARTS),
}

-- Phase 3: verify entry preconditions.
local verdict = "GREEN"
local mismatches = {}
if entry.level ~= EXPECTED_LEVEL then
    verdict = "RED"
    mismatches[#mismatches+1] = string.format("level: expected %d got %d", EXPECTED_LEVEL, entry.level)
end
if entry.room ~= EXPECTED_ROOM then
    verdict = "RED"
    mismatches[#mismatches+1] = string.format("room: expected 0x%02X got 0x%02X", EXPECTED_ROOM, entry.room)
end

-- Phase 4: emit schema instance.
mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
f:write(string.format([[{
  "label": "%s",
  "level": %d,
  "quest": %d,
  "mode": "simplified-load-only",
  "entry": { "frame": %d, "room": %d, "level": %d, "hearts": %d },
  "expected": { "room": %d, "level": %d },
  "verdict": "%s",
  "mismatches": [%s]
}
]],
    LABEL, LEVEL, QUEST,
    entry.frame, entry.room, entry.level, entry.hearts,
    EXPECTED_ROOM, EXPECTED_LEVEL,
    verdict,
    #mismatches > 0 and ('"' .. table.concat(mismatches, '","') .. '"') or ""
))
f:close()
client.exit()
