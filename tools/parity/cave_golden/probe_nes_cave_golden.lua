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
OW_ROOM = OW_ROOM or 0x77   -- OW room hosting this cave (savestate is in $77)
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
local CELL_TARGET_MODE   = 0x005B  -- TargetMode (SetTargetMode writes here)
local CELL_COLLIDED_TILE = 0x049E  -- ObjCollidedTile[0]
local CELL_UG_ENTRANCE   = 0x0065  -- UndergroundEntranceTile
local CELL_OBJ_X0        = 0x0070  -- ObjX[0] (Link)
local CELL_OBJ_Y0        = 0x0084  -- ObjY[0] (Link)

-- ─── Domain readers ─────────────────────────────────────────────────
local function R(o)    return memory.read_u8(o, "RAM") end
local function W(o,v)  memory.write_u8(o, v, "RAM") end
local function OAM(o)  return memory.read_u8(o, "OAM") end
local function PAL(o)  return memory.read_u8(o, "PALRAM") end
-- Zelda is CHR-RAM (board SNROM/MMC1, ch=0). NesHawk has NO "CHR" domain
-- for CHR-RAM games — the 8 KB pattern tables ($0000-$1FFF) are the "VRAM"
-- domain (size 8192, confirmed by live memory.getmemorydomainlist()).
local function CHR(o)  return memory.read_u8(o, "VRAM") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b, hold, settle)
    for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
    joypad.set({}, 1)
    for _=1,settle do emu.frameadvance() end
end

-- ─── Boot to gameplay (NesHawk overworld savestate) ────────────────
-- The file-select dance is unreliable on this ROM's SRAM (it overshoots
-- into REGISTER-YOUR-NAME and never reaches play). Instead load a
-- pre-made NesHawk savestate parked in overworld gameplay; force_state_cave
-- then LoadLevel-warps to the cave. State path is space-free so BizHawk's
-- loader doesn't choke. Must be a NesHawk state (savestates are
-- core-specific); config PreferredCores NES=NesHawk guarantees the core.
local SAVESTATE = "C:\\tmp\\z1_ow.State"
local function boot_to_gameplay()
    savestate.load(SAVESTATE)
    idle(8)
    -- Sanity: a real gameplay state has GameMode in the play range
    -- ($05 play, $06 LoadLevel transient, $07 scroll). A menu/title state
    -- sits at $00..$04. Print so the run log shows what we loaded.
    print(string.format("post-load gm=$%02X sub=$%02X rm=$%02X linkx=$%02X",
        R(CELL_GAME_MODE), R(CELL_GAME_SUBMODE), R(CELL_ROOM_ID), R(0x0070)))
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
    -- FAKE the real OW->cave trigger (HandleWarpOW, Z_05.asm:7250) exactly
    -- as stepping on a $24 cave tile does. The game's path is:
    --   GetCollidableTileStill -> ObjCollidedTile==$24 -> HandleWarpOW ->
    --   SetTargetMode (@7284): STA TargetMode ; LDA #$10 ; STA GameMode.
    -- GameMode $10 is the cave-ENTER TRANSITION (UpdateMode10Stairs_Full,
    -- Z_05.asm:2308): runs Link's descend + the REAL cave load/fade, THEN
    -- flips GameMode to the cave mode ($0B regular / $0C shortcut). The
    -- cave id is derived from LevelBlockAttrsB[RoomId], so RoomId must stay
    -- the OW room ($77 for cave $6A). Poking GameMode=$0B directly SKIPS
    -- mode $10 -> glitched non-cave screen (prior captures' failure).
    local cave_mode = (CAVE_ID >= 0x7B) and 0x0C or 0x0B
    -- Settle in the OW room that hosts this cave (savestate already is).
    W(CELL_CUR_LEVEL, 0x00)
    W(CELL_ROOM_ID,   OW_ROOM)
    W(CELL_CUR_QUEST, QUEST)
    idle(4)
    -- Inject trigger preconditions + drive SetTargetMode -> GameMode $10.
    -- ObjCollidedTile = $70 (stairs), NOT $24: mode $10 then SKIPS the
    -- Link-descend animation (Z_05.asm:2310-2311 "BNE :+ end the mode
    -- without animating Link") and flips straight to TargetMode. With $24
    -- it INCs ObjY until ObjY==StairsTargetY, which our injected (stale)
    -- StairsTargetY never reaches -> stuck at GameMode $10 forever.
    W(CELL_COLLIDED_TILE, 0x70)          -- ObjCollidedTile[0] = stairs
    W(CELL_UG_ENTRANCE,   0x24)          -- UndergroundEntranceTile = cave
    W(CELL_TARGET_MODE,   cave_mode)     -- TargetMode = $0B/$0C
    W(CELL_GAME_MODE,     0x10)          -- mode $10 -> flips to cave mode
    -- mode $10 flips to cave_mode; InitModeB submode 0..8 loads the cave.
    -- Poll until WalkCave (submode >= 8) = settled, walkable cave.
    for _ = 1, 90 do
        idle(4)
        if R(CELL_GAME_MODE) == cave_mode and R(CELL_GAME_SUBMODE) >= 0x08 then break end
    end
    idle(30)                             -- settle bonfire/person post-load
    -- Re-assert Link halt + NPC slot pos for a clean static frame.
    W(CELL_PERSON_STATE, 0x00)
    W(CELL_LINK_STATE,   0x40)           -- halt Link
    W(CELL_OBJX_1,       0x78)
    W(CELL_OBJY_1,       0x80)
    idle(8)
    -- Determinism: zero FrameCounter so frame_phase N == FrameCounter N.
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

-- PROOF we are actually inside the cave (not a stale screen with a poked
-- GameMode). submode $08 = InitMode_WalkCave = cave rendered + walkable
-- (Z_05.asm:3506 InitModeB submode machine). Fail LOUD otherwise.
do
    local gm, sub = R(CELL_GAME_MODE), R(CELL_GAME_SUBMODE)
    print(string.format("post-force gm=$%02X sub=$%02X rm=$%02X objtype1=$%02X person=$%02X linkstate=$%02X",
        gm, sub, R(CELL_ROOM_ID), R(CELL_OBJTYPE_1), R(CELL_PERSON_STATE), R(CELL_LINK_STATE)))
    if not ((gm == 0x0B or gm == 0x0C) and sub >= 0x08) then
        print("!!! CAVE NOT REACHED — gm/sub wrong; bundle is NOT a cave capture !!!")
    else
        print("OK: inside cave (WalkCave submode reached)")
    end
end

local prev = 0
for _, target in ipairs(FRAMES) do
    idle(target - prev)
    prev = target
    capture(target)
end
client.screenshot(OUT .. "\\shot.png")
print("done: " .. OUT)
client.exit()
