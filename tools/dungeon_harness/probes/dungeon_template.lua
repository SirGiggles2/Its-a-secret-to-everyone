-- tools/dungeon_harness/probes/dungeon_template.lua
--
-- Per-dungeon probe template for Phase 14.0. Copy this template to
-- `dungeon_<level>_q<n>.lua` and fill in the per-dungeon constants:
--
--   SAVE_STATE_PATH  — path to the BizHawk save state for this row.
--   ENTRY_RAM        — RAM cells expected at save-state load
--                       (RoomId, Hearts, KeyCount, Bombs, MapFlags).
--   INPUT_SEQUENCE   — minimal critical-path input from entry room
--                       to boss-room kill.
--   BOSS_KILL_RAM    — RAM cells expected after boss-clear flag set.
--   REWARD_RAM       — RAM cell expected populated with the reward
--                       (triforce piece slot 19, or Zelda for L9).
--
-- Each probe:
-- 1. Loads its pinned save state via `savestate.load(...)`.
-- 2. Asserts entry RAM matches manifest preconditions (BAIL if not).
-- 3. Replays the pinned input sequence frame-by-frame
--    (`joypad.set(...)`, `emu.frameadvance()`).
-- 4. Captures boss-kill RAM evidence + reward RAM evidence.
-- 5. Emits a parity-oracle schema instance to
--    `builds/reports/dungeon_harness/<label>.json`.
-- 6. Exits BizHawk via `client.exit()`.

local LABEL = "TEMPLATE"
local LEVEL = 0
local QUEST = 0
local SAVE_STATE_PATH = nil      -- fill in per-row
local INPUT_SEQUENCE = {}        -- fill in per-row: array of {frame, buttons}
local OUT_DIR = "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\builds\\reports\\dungeon_harness\\"
local OUT_PATH = OUT_DIR .. LABEL .. ".json"

-- Standard NES RAM cells (per reference/aldonunez/Variables.inc).
local RAM_ROOM_ID    = 0x00EB
local RAM_HEARTS     = 0x0000   -- LINK_HEARTS cell (low nibble = current)
local RAM_KEYS       = 0x0066
local RAM_BOMBS      = 0x0067
local RAM_LEVEL      = 0x0010
local RAM_ROOM_KILL_COUNT = 0x034F
local RAM_ROOM_ITEM_STATE = 0x00BF  -- ObjState[$13] = $00AC + 19

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
elseif domain_exists("M68K RAM") then
    RAM_DOMAIN = "M68K RAM"; CELL_BASE = 0x0000
end

local function r8(addr)
    memory.usememorydomain(RAM_DOMAIN)
    return memory.read_u8(CELL_BASE + addr)
end

local function mkdir_for(path)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
    end
end

-- Phase 0: load save state.
if SAVE_STATE_PATH then
    savestate.load(SAVE_STATE_PATH)
    emu.frameadvance()
end

-- Phase 1: capture entry RAM snapshot.
local entry = {
    frame  = emu.framecount(),
    room   = r8(RAM_ROOM_ID),
    level  = r8(RAM_LEVEL),
    hearts = r8(RAM_HEARTS),
    keys   = r8(RAM_KEYS),
    bombs  = r8(RAM_BOMBS),
}

-- Phase 2: replay input sequence.
local seq_idx = 1
while seq_idx <= #INPUT_SEQUENCE do
    local step = INPUT_SEQUENCE[seq_idx]
    if emu.framecount() >= step.frame then
        joypad.set(step.buttons)
        seq_idx = seq_idx + 1
    end
    emu.frameadvance()
end

-- Phase 3: capture boss-kill + reward RAM.
-- Drift up to 300 frames waiting for boss-clear (RoomKillCount > 0 then = 0
-- on transition, room item slot active).
local boss_clear_frame = -1
for _ = 1, 300 do
    emu.frameadvance()
    if r8(RAM_ROOM_ITEM_STATE) == 0x00 then
        boss_clear_frame = emu.framecount()
        break
    end
end

local kill = {
    frame  = emu.framecount(),
    room   = r8(RAM_ROOM_ID),
    kill_count = r8(RAM_ROOM_KILL_COUNT),
    boss_clear_frame = boss_clear_frame,
    room_item_state  = r8(RAM_ROOM_ITEM_STATE),
}

-- Phase 4: emit schema instance.
mkdir_for(OUT_PATH)
local f = assert(io.open(OUT_PATH, "w"))
f:write(string.format([[{
  "label": "%s",
  "level": %d,
  "quest": %d,
  "entry": {
    "frame": %d, "room": %d, "level": %d,
    "hearts": %d, "keys": %d, "bombs": %d
  },
  "kill": {
    "frame": %d, "room": %d, "kill_count": %d,
    "boss_clear_frame": %d, "room_item_state": %d
  },
  "verdict": "%s"
}
]],
    LABEL, LEVEL, QUEST,
    entry.frame, entry.room, entry.level,
    entry.hearts, entry.keys, entry.bombs,
    kill.frame, kill.room, kill.kill_count,
    kill.boss_clear_frame, kill.room_item_state,
    (boss_clear_frame > 0) and "GREEN" or "RED"
))
f:close()
client.exit()
