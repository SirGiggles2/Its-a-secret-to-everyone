-- probe_nes_dungeon_golden.lua — NES Zelda 1 per-dungeon-room golden capture.
--
-- Sibling of probe_nes_cave_golden.lua, for UW (dungeon) rooms. Captures the
-- BYTE-EXACT ground truth for one (level, room): OAM + PALRAM + CHR + CIRAM
-- at fixed frame phases. The Genesis side (probe_gen_dungeon_golden.lua)
-- captures the same phases; cave_byte_diff.py compares after normalization.
--
-- NES ENTRY SEQUENCE (probed, not guessed — RULE ZERO):
--   HandleWarpOW (Z_05.asm:7313) @LoadLevel: when a dungeon-entrance tile is
--   touched and LevelBlockAttrsB[RoomId]&$FC < $40, it sets
--   CurLevel = selector>>2, then TargetMode = $02 (load level). The mode
--   machine enters GameMode $02 (InitMode2/UpdateMode2Load, Z_06.asm) which
--   loads the level data + CHR + LevelInfo palettes, then mode $03 Unfurl
--   (InitMode3_Sub1, Z_07.asm:1409) sets RoomId = LevelInfo_StartRoomId for
--   any UW level (CurLevel != 0) and cues the level palette transfer, then
--   modes $04/$05 enter play. So forcing CurLevel=LEVEL + GameMode=$02 and
--   idling reproduces the real entry: L1 CHR + LevelInfo palette loaded,
--   RoomId auto-set to the level's start room ($73 for L1). No tile/attr
--   forcing needed — the level number drives the whole load.
--
-- ⚠ REQUIRES NesHawk (config.ini PreferredCores NES=NesHawk) — same as the
-- cave probe: the CHR/PALRAM capture reads the "VRAM" domain that exists on
-- NesHawk but NOT quickerNES (CHR-RAM game). Pin the core or capture blanks.
--
-- Globals supplied by prelude:
--   LEVEL   : 1..9  (CurLevel)
--   QUEST   : 1 or 2 (CurQuest cell — Q2 swaps room layouts via PatchQ2Rooms)
--   UW_ROOM : expected start room id for proof (L1Q1 = 0x73)
--   OUT_DIR : output folder (default C:\tmp\cave_golden)

LEVEL   = LEVEL   or 1
QUEST   = QUEST   or 1
UW_ROOM = UW_ROOM or 0x73
OUT_DIR = OUT_DIR or "C:\\tmp\\cave_golden"

local OUT = string.format("%s\\nes_L%dQ%d_R%02X", OUT_DIR, LEVEL, QUEST, UW_ROOM)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

local FRAMES = {0, 8, 16, 24, 60, 120}

-- ─── NES RAM cell map (reference/aldonunez/Variables.inc) ───────────
local CELL_CUR_LEVEL    = 0x0010
local CELL_GAME_MODE    = 0x0012
local CELL_GAME_SUBMODE = 0x0013
local CELL_LINK_STATE   = 0x00AC  -- ObjState[0]
local CELL_ROOM_ID      = 0x00EB
local CELL_FRAME_COUNTER= 0x0015
local CELL_LINK_DIR     = 0x0098  -- ObjDir[0]
local CELL_CUR_QUEST    = 0x062D
local CELL_OBJ_X0       = 0x0070  -- ObjX[0] (Link)
local CELL_OBJ_Y0       = 0x0084  -- ObjY[0] (Link)
local CELL_TARGET_MODE   = 0x005B  -- TargetMode (SetTargetMode writes here)
local CELL_COLLIDED_TILE = 0x049E  -- ObjCollidedTile[0]
local CELL_UG_ENTRANCE   = 0x0065  -- UndergroundEntranceTile

-- ─── Domain readers (identical to the cave probe) ───────────────────
local function R(o)    return memory.read_u8(o, "RAM") end
local function W(o,v)  memory.write_u8(o, v, "RAM") end
local function OAM(o)  return memory.read_u8(o, "OAM") end
local function PAL(o)  return memory.read_u8(o, "PALRAM") end
local function CHR(o)  return memory.read_u8(o, "VRAM") end   -- CHR-RAM = "VRAM" on NesHawk
local function NT(o)   return memory.read_u8(o, "CIRAM (nametables)") end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function LOG(s)
    local fh = io.open("C:/tmp/nes_dun_dbg.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end

-- ─── Boot to gameplay (power-on + battery SRAM) — same as cave probe ─
local function boot_to_gameplay()
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

local function SB(a)   return memory.read_u8(a, "System Bus") end  -- $6BAD = cart WRAM
local function SBW(a,v) memory.write_u8(a, v, "System Bus") end

-- ─── load_level(): bring in LEVEL's CHR + LevelInfo palette + data (ONCE) ─
-- Replicates HandleWarpOW @LoadLevel (Z_05.asm:7358) EXACTLY, the same way
-- the cave probe replicates @cave: directly poking GameMode=$02 does NOT
-- enter mode 2's init (the mode machine ignores a bare GameMode write —
-- proven: poke $02 left rm=$77 OW). The real path is the mode-$10 stairs
-- transition: @LoadLevel sets CurLevel + TargetMode=$02, SetTargetMode (7284)
-- writes GameMode=$10. UpdateMode10Stairs_Full (Z_05.asm:2308) with
-- ObjCollidedTile=$70 (stairs, not $24) skips the Link-descend and flips
-- GameMode -> $02 via EndGameMode (resets submode so mode 2 init runs). Mode 2
-- loads CHR+data; mode 3 Unfurl runs. (The SRAM save is an OW save so the
-- load resolves the start room back to the save's OW room — enter_room() then
-- forces the actual UW room. We only need the level's CHR/palette/data here.)
local function load_level()
    W(CELL_CUR_QUEST, QUEST)
    W(CELL_CUR_LEVEL, LEVEL)
    idle(4)
    W(CELL_COLLIDED_TILE, 0x70)
    W(CELL_UG_ENTRANCE,   0x70)
    W(CELL_TARGET_MODE,   0x02)
    W(CELL_GAME_MODE,     0x10)
    for _ = 1, 240 do
        idle(1)
        local gm = R(CELL_GAME_MODE)
        if gm >= 0x05 and gm <= 0x07 and R(CELL_CUR_LEVEL) == LEVEL then break end
    end
    LOG(string.format("load_level L%d: gm=$%02X lvl=%d rm=$%02X startroom=$%02X",
        LEVEL, R(CELL_GAME_MODE), R(CELL_CUR_LEVEL), R(CELL_ROOM_ID), SB(0x6BAD)))
end

-- ─── enter_room(room): force + re-decode a specific UW room ─────────
-- Level already loaded. Force RoomId + LevelInfo_StartRoomId ($6BAD, memory
-- feedback_redux_automap_room_reset: write $6BAD before $EB) then re-decode
-- via mode 4 (InitMode_EnterRoom, Z_05.asm:1543 — decodes + lays out the
-- room) so CIRAM/OAM reflect this room. Returns true once gm=play & rm=room.
local function enter_room(room)
    SBW(0x6BAD, room)                    -- LevelInfo_StartRoomId
    W(CELL_ROOM_ID, room)
    W(CELL_GAME_SUBMODE, 0x00)
    W(CELL_GAME_MODE, 0x04)              -- InitMode4/EnterRoom: decode `room`
    local ok = false
    for _ = 1, 200 do
        idle(1)
        local gm = R(CELL_GAME_MODE)
        if gm >= 0x05 and gm <= 0x07 and R(CELL_ROOM_ID) == room then ok = true; break end
    end
    idle(60)                             -- settle room render + CHR/palette upload
    W(CELL_LINK_STATE, 0x40)             -- halt Link for a clean static frame
    idle(8)
    W(CELL_FRAME_COUNTER, 0x00)          -- determinism: frame_phase N == FrameCounter N
    return ok and R(CELL_ROOM_ID) == room
end

-- ─── Bundle writer (NCGD layout, shared with the cave golden) ───────
-- 8-byte header: "NCGD" + frame_phase + room + game_mode + CurLevel, then
-- OAM(256) + PALRAM(32) + CHR(8192) + ppuctrl(1) + CIRAM(2048). Same byte
-- offsets as the cave NCGD so cave_byte_diff.py reads it as-is.
local function capture(out, room, frame_phase)
    local path = string.format("%s\\f%03d.bin", out, frame_phase)
    local f = io.open(path, "wb")
    f:write("NCGD")
    f:write(string.char(frame_phase & 0xFF))
    f:write(string.char(room & 0xFF))
    f:write(string.char(R(CELL_GAME_MODE)))
    f:write(string.char(R(CELL_CUR_LEVEL)))
    for i = 0, 255  do f:write(string.char(OAM(i))) end
    for i = 0, 31   do f:write(string.char(PAL(i))) end
    for i = 0, 8191 do f:write(string.char(CHR(i))) end
    f:write(string.char(R(0x00FF)))   -- CurPpuControl_2000 (sprite mode)
    for i = 0, 2047 do f:write(string.char(NT(i))) end   -- CIRAM nametables
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
-- ROOMS (optional global): list of room ids to sweep in one launch (the
-- level is loaded once, each room re-decoded). Defaults to {UW_ROOM}.
local rooms = ROOMS or { UW_ROOM }
print(string.format("NES dungeon golden: L%dQ%d rooms=%d", LEVEL, QUEST, #rooms))
if not boot_to_gameplay() then
    print("BOOT FAIL — aborting, no golden written"); client.exit(); return
end
load_level()

for _, room in ipairs(rooms) do
    local out = string.format("%s\\nes_L%dQ%d_R%02X", OUT_DIR, LEVEL, QUEST, room)
    os.execute('if not exist "' .. out .. '" mkdir "' .. out .. '"')
    if not enter_room(room) then
        LOG(string.format("!!! L%d room $%02X NOT REACHED (gm=$%02X rm=$%02X) — skipped",
            LEVEL, room, R(CELL_GAME_MODE), R(CELL_ROOM_ID)))
    else
        LOG(string.format("OK: L%d room $%02X (gm=$%02X)", LEVEL, room, R(CELL_GAME_MODE)))
        local prev = 0
        for _, target in ipairs(FRAMES) do
            idle(target - prev); prev = target
            capture(out, room, target)
        end
        client.screenshot(out .. "\\shot.png")
    end
end
print("done: NES L" .. LEVEL .. "Q" .. QUEST)
client.exit()
