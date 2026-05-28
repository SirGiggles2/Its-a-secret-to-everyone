-- probe_nes_cave_golden.lua — NES Zelda 1 per-cave golden capture.
--
-- Captures the BYTE-EXACT ground truth for one cave_id across an
-- animation window: OAM (sprite table) + PALRAM (palette) + CHR
-- (pattern tables) at fixed frame phases. The Genesis side
-- (probe_gen_cave_golden.lua) captures the same phases; cave_byte_diff.py
-- compares them after NES->Gen normalization.
--
-- WHY multi-frame: the bonfire (ObjType $40 StandingFire) animates on a
-- 2-tile cycle ($5C <-> $9E). A single-frame capture cannot prove the
-- animation cadence matches NES. Frames {0,8,16,24,60,120} straddle the
-- ~10-frame NES toggle so any cadence drift shows as a tile-id mismatch
-- at a specific phase.
--
-- Core: NesHawk memory domains (verified live in
-- tools/parity/probe_nes_full_room_dump.lua): "OAM" (256B), "PALRAM"
-- (32B), "CHR" (8KB pattern), "RAM" (2KB CPU).
--
-- Globals supplied by prelude (run_nes_golden.py writes them):
--   CAVE_ID : 0x6A..0x7D
--   QUEST   : 1 or 2 (cave interiors are quest-independent per debate
--             058, but pass it for the CurQuest cell so InitCaveContinue
--             reads the right LBA_E set)
--   OUT_DIR : output folder (default C:\tmp\cave_golden)

CAVE_ID = CAVE_ID or 0x6A
QUEST   = QUEST   or 1
OUT_DIR = OUT_DIR or "C:\\tmp\\cave_golden"

local OUT = string.format("%s\\nes_%02X", OUT_DIR, CAVE_ID)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

-- Frame phases (relative to capture-start with FrameCounter forced to 0).
local FRAMES = {0, 8, 16, 24, 60, 120}

-- ─── NES RAM cell map (reference/aldonunez/Variables.inc) ───────────
local CELL_CUR_LEVEL    = 0x0010
local CELL_GAME_MODE    = 0x0012
local CELL_GAME_SUBMODE = 0x0013  -- InitModeB submode state machine (0..8)
local CELL_LINK_STATE   = 0x00AC  -- ObjState[0]
local CELL_PERSON_STATE = 0x00AD  -- CavePersonState
local CELL_ROOM_ID      = 0x00EB
local CELL_FRAME_COUNTER= 0x0015
local CELL_LINK_DIR     = 0x0098  -- ObjDir[0]
local CELL_OBJTYPE_1    = 0x0350  -- ObjType+1 (cave NPC slot)
local CELL_OBJX_1       = 0x0071  -- ObjX+1
local CELL_OBJY_1       = 0x0085  -- ObjY+1
local CELL_CUR_QUEST    = 0x062D

-- ─── Domain readers ─────────────────────────────────────────────────
local function R(o)    return memory.read_u8(o, "RAM") end
local function W(o,v)  memory.write_u8(o, v, "RAM") end
local function OAM(o)  return memory.read_u8(o, "OAM") end
local function PAL(o)  return memory.read_u8(o, "PALRAM") end
local function CHR(o)  return memory.read_u8(o, "CHR") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
    for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
    joypad.set({}, 1)
    for _=1,settle do emu.frameadvance() end
end

-- ─── Boot to gameplay (file-select dance, proven in
--      probe_nes_full_room_dump.lua:65-74) ─────────────────────────
local function boot_to_gameplay()
    idle(360); press("Start", 4, 60)
    press("Down",4,20); press("Down",4,20); press("Down",4,20)
    press("Start",4,60); press("Start",4,60)
    for _=1,5 do press("Down",4,8) end
    for _=1,5 do press("Right",4,8) end
    press("Start",4,60)
    for _=1,5 do press("Up",4,12) end
    press("Start",4,180); idle(180)
end

-- ─── Force into cave mode for CAVE_ID ───────────────────────────────
-- REVIEW PASS 1 finding: InitModeB (Z_05.asm:3506) is a SUBMODE state
-- machine — `LDA GameSubmode / JSR TableJump`. Submodes 0..8 run in
-- sequence over multiple frames: sub3 LayoutCave, sub7
-- InitModeB_EnterCave_Bank5 (calls InitCave → SetUpCommonCaveObjects +
-- InitCaveContinue LBA_E copy), sub8 InitMode_WalkCave (gameplay).
-- Writing GameMode=$0B with a STALE GameSubmode skips init entirely.
-- Correct entry: set RoomId + ObjType+1 (so InitCave reads the right
-- cave) FIRST, then GameMode=$0B + GameSubmode=$00, then idle enough
-- frames for sub0→8 to complete (InitCave fires at sub7).
local function force_state_cave()
    -- Step 1: OW to populate SRAM LBA_E ($6A7E wares/prices source).
    W(CELL_CUR_LEVEL, 0x00)
    W(CELL_GAME_SUBMODE, 0x00)
    W(CELL_ROOM_ID,   0x77)
    W(CELL_GAME_MODE, 0x06)   -- Mode 6 = LoadLevel -> Play
    idle(90)
    if memory.read_u8(0x6A7E, "RAM") == 0xFF then idle(120) end

    -- Step 2: seed cave identity BEFORE Mode B runs (InitCave at sub7
    -- reads ObjType+1 + RoomId).
    W(CELL_CUR_QUEST, QUEST)
    W(CELL_ROOM_ID,   CAVE_ID)
    W(CELL_OBJTYPE_1, CAVE_ID)           -- ObjType+1 = cave_id
    W(CELL_LINK_DIR,  0x08)              -- face up

    -- Step 3: kick Mode B from submode 0; let the 0→8 machine run.
    local cave_mode = (CAVE_ID >= 0x7B) and 0x0C or 0x0B
    W(CELL_GAME_SUBMODE, 0x00)
    W(CELL_GAME_MODE, cave_mode)
    idle(90)                             -- sub0..8 incl InitCave + layout

    -- Step 4: confirm we reached WalkCave (submode 8 / gameplay). If the
    -- machine stalled, idle more.
    for _ = 1, 6 do
        if R(CELL_GAME_MODE) == cave_mode and R(CELL_GAME_SUBMODE) >= 0x08 then
            break
        end
        idle(30)
    end

    -- Step 5: re-assert Link halt + NPC slot pos for a clean static frame.
    W(CELL_PERSON_STATE, 0x00)
    W(CELL_LINK_STATE,   0x40)           -- halt Link
    W(CELL_OBJX_1,       0x78)
    W(CELL_OBJY_1,       0x80)
    idle(8)

    -- Determinism: zero FrameCounter so frame_phase N == FrameCounter N.
    -- NES NMI does INC FrameCounter every frame (Z_07.asm:519), so after
    -- this reset the subsequent idle(8)/idle(16)... advance it 8/16/...
    -- deterministically — matching the Genesis mirror reset.
    W(CELL_FRAME_COUNTER, 0x00)
end

-- ─── Bundle writer (NCGD = NES Cave GolDen) ─────────────────────────
-- Layout per frame file fNNN.bin:
--   "NCGD" magic (4)
--   u8 frame_phase
--   u8 cave_id
--   u8 game_mode      (sanity: should be $0B or $0C)
--   u8 person_state
--   OAM   256 bytes   ($0200 shadow OAM)
--   PALRAM 32 bytes   ($3F00..$3F1F)
--   CHR   8192 bytes  (pattern tables $0000..$1FFF: BG + SPR banks)
-- Total = 4 + 4 + 256 + 32 + 8192 = 8488 bytes.
local function capture(frame_phase)
    local path = string.format("%s\\f%03d.bin", OUT, frame_phase)
    local f = io.open(path, "wb")
    f:write("NCGD")
    f:write(string.char(frame_phase & 0xFF))
    f:write(string.char(CAVE_ID & 0xFF))
    f:write(string.char(R(CELL_GAME_MODE)))
    f:write(string.char(R(CELL_PERSON_STATE)))
    for i = 0, 255  do f:write(string.char(OAM(i))) end
    for i = 0, 31   do f:write(string.char(PAL(i))) end
    for i = 0, 8191 do f:write(string.char(CHR(i))) end
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("NES cave golden: cave_id=$%02X quest=%d", CAVE_ID, QUEST))
boot_to_gameplay()
force_state_cave()

local prev = 0
for _, target in ipairs(FRAMES) do
    idle(target - prev)
    prev = target
    capture(target)
end
client.screenshot(OUT .. "\\shot.png")
print("done: " .. OUT)
client.exit()
