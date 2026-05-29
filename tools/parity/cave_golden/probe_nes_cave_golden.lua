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
-- BG nametable (cave walls, the old-man text, AND the HUD all live here as
-- BG tiles, NOT sprites). Domain "CIRAM (nametables)" = 2048 bytes (2 NTs),
-- confirmed by live memory.getmemorydomainlist().
local function NT(o)   return memory.read_u8(o, "CIRAM (nametables)") end
local function idle(n) for _=1,n do emu.frameadvance() end end
-- File log (console is lost when EmuHawk auto-exits). Appends to a per-run
-- diagnostic so a failed boot/force can be triaged after the fact.
local function LOG(s)
    local fh = io.open("C:/tmp/nes_dbg.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end
local function press(b, hold, settle)
    for _=1,hold do joypad.set({[b]=true}, 1); emu.frameadvance() end
    joypad.set({}, 1)
    for _=1,settle do emu.frameadvance() end
end

-- ─── Boot to gameplay (power-on + battery SRAM, CORE-AGNOSTIC) ──────
-- The old approach loaded a pre-made savestate (z1_ow.State). Savestates
-- are CORE-specific and the NES core changed (NesHawk -> quickerNES), so
-- savestate.load aborts with a mismatch dialog -> empty capture. Long-term
-- fix: drop the savestate entirely. Boot from power-on with the ROM's
-- battery SRAM (loz_real.SaveRAM = a registered overworld file), then
-- poll-press Start until GameMode reaches the play range. SRAM is raw
-- battery RAM = core-agnostic, so this survives any core/config change.
-- force_state_cave then LoadLevel-warps to the target cave (RoomId-forced).
local function boot_to_gameplay()
    -- Poll-press Start: advances title -> file-select -> in-game. File 1 is
    -- registered (SRAM), so Start on it enters play; no register-name dance.
    -- Stop pressing the instant GameMode hits play ($05..$07) so we never
    -- pause the subscreen with a stray Start.
    LOG(string.format("boot start: gm=$%02X rm=$%02X", R(CELL_GAME_MODE), R(CELL_ROOM_ID)))
    for f = 1, 1800 do
        local gm = R(CELL_GAME_MODE)
        if gm >= 0x05 and gm <= 0x07 then
            LOG(string.format("boot: play gm=$%02X rm=$%02X at f=%d", gm, R(CELL_ROOM_ID), f))
            idle(20); return true
        end
        if (f % 200) == 0 then
            LOG(string.format("boot poll f=%d gm=$%02X rm=$%02X", f, gm, R(CELL_ROOM_ID)))
        end
        if (f % 16) == 0 then joypad.set({Start=true}, 1)
        else                  joypad.set({}, 1) end
        emu.frameadvance()
    end
    LOG("boot FAIL: never reached play GameMode (SRAM file empty / wrong slot?)")
    return false
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
    -- Poll until the cave OBJECT is set up: gm==cave_mode AND ObjType+1 ==
    -- CAVE_ID. InitCave (submode 7) writes ObjType+1, AFTER LayoutCave
    -- (submode 3) renders the BG -> objtype1==CAVE_ID implies submodes 0..7
    -- all ran. (The old `submode >= 8` check only held for the frozen
    -- savestate; via SRAM-boot+force the submode machine runs to completion
    -- and resets to 0 for active WalkCave play, so >=8 never re-observes.)
    for _ = 1, 120 do
        idle(4)
        if R(CELL_GAME_MODE) == cave_mode and R(CELL_OBJTYPE_1) == CAVE_ID then break end
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
--   u8 ppuctrl        (CurPpuControl_2000 $00FF: bit5=8x16 sprites,
--                      bit3=sprite pattern table — needed to decode OAM)
--   CIRAM 2048 bytes  (nametables: BG cave walls + person text + HUD tiles
--                      + attribute tables — none of which are sprites)
-- Total = 4 + 4 + 256 + 32 + 8192 + 1 + 2048 = 10537 bytes.
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
    f:write(string.char(R(0x00FF)))   -- CurPpuControl_2000 (sprite mode)
    for i = 0, 2047 do f:write(string.char(NT(i))) end   -- CIRAM nametables
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("NES cave golden: cave_id=$%02X quest=%d", CAVE_ID, QUEST))
if not boot_to_gameplay() then
    print("BOOT FAIL — aborting, no golden written"); client.exit(); return
end
force_state_cave()

-- PROOF we are actually inside the cave (not a stale screen with a poked
-- GameMode). submode $08 = InitMode_WalkCave = cave rendered + walkable
-- (Z_05.asm:3506 InitModeB submode machine). Fail LOUD otherwise.
do
    local gm, sub = R(CELL_GAME_MODE), R(CELL_GAME_SUBMODE)
    LOG(string.format("post-force gm=$%02X sub=$%02X rm=$%02X objtype1=$%02X person=$%02X linkstate=$%02X",
        gm, sub, R(CELL_ROOM_ID), R(CELL_OBJTYPE_1), R(CELL_PERSON_STATE), R(CELL_LINK_STATE)))
    -- True "cave loaded" proof (debate D1): correct cave mode AND the cave's
    -- own object id is set (InitCave ran for THIS cave). Submode is don't-care
    -- post-init. objtype1 mismatch = wrong/empty cave -> fail loud.
    if not ((gm == 0x0B or gm == 0x0C) and R(CELL_OBJTYPE_1) == CAVE_ID) then
        LOG("!!! CAVE NOT REACHED — gm/objtype1 wrong; aborting, no golden written !!!")
        client.exit(); return
    end
    LOG("OK: inside cave (objtype1==CAVE_ID, InitCave ran)")
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
