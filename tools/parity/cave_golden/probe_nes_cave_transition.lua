-- probe_nes_cave_transition.lua — NES Z1 cave-ENTRY-ANIMATION capture.
--
-- Sibling of probe_nes_cave_golden.lua. The golden probe captures the
-- SETTLED cave INTERIOR (it deliberately SKIPS the Link-descend by forcing
-- ObjCollidedTile=$70). THIS probe captures the TRANSITION itself:
-- GameMode $10 descend (Link sinks behind the arch, ObjY +1 every 4 frames,
-- 16 px / 64 frames) -> InitModeB cave-load submodes -> GameMode $0B/$0C
-- emerge (InitMode_WalkCave, ObjGridOffset $30 = 48 px UP @ 1 px/frame).
--
-- It captures EVERY frame from the descent trigger for CAPTURE_FRAMES, so
-- the per-frame ObjY trajectory, sprite (OAM) Y/X/attr/tile, walk-pose
-- anim cadence, behind-BG priority, palette, and EffectRequest are all
-- byte-recorded. Pairs with probe_gen_cave_transition.lua;
-- cave_transition_diff.py compares them after NES->Gen normalization.
--
-- WHY a band-force of $24: InitMode10 (Z_05.asm:1399) runs as GameMode $10
-- submode 0 and reads the tile under Link's hotspot via
-- GetCollidableTileStill (Z_07.asm:2110 -> PlayAreaTiles $6530). If that
-- tile == $24 it sets StairsTargetY = ObjY + $10 and the real descend runs;
-- otherwise it skips animation. We force a 3-col x full-height $24 band
-- around Link's column so the hotspot lands on $24 regardless of the exact
-- ObjX->cell mapping, then drive GameMode=$10 / GameSubmode=0. This is the
-- REAL InitMode10 path (StairsTargetY computed by the engine from live
-- ObjY) — not a synthetic descend.
--
-- ⚠ REQUIRES NesHawk (config.ini PreferredCores NES=NesHawk): the CHR
-- reference dump reads the "VRAM" domain (CHR-RAM), absent on quickerNES.
--
-- Globals (CAVE_ID/QUEST/OW_ROOM/OUT_DIR). The sweep runner writes a PLAIN-TEXT
-- cfg C:\tmp\_cave_cfg.txt = "<cave_hex> <ow_hex>" (e.g. "6B 06") which this
-- probe reads with io.open+match. NOT dofile — dofile is broken in this NLua
-- build (both --lua-prelude->dofile and probe->dofile produce no output), but
-- io.open works (it's how the probe writes its bundles). Launch the probe
-- DIRECTLY as --lua (the path proven for $6A).
do
    local cf = io.open("C:\\tmp\\_cave_cfg.txt", "r")
    if cf then
        local line = cf:read("*l") or ""; cf:close()
        local c, o = line:match("(%x+)%s+(%x+)")
        if c then CAVE_ID = tonumber(c, 16); OW_ROOM = tonumber(o, 16) end
    end
end

CAVE_ID = CAVE_ID or 0x6A
QUEST   = QUEST   or 1
OW_ROOM = OW_ROOM or 0x77
OUT_DIR = OUT_DIR or "C:\\tmp\\cave_golden"

local OUT = string.format("%s\\nes_%02X_trans", OUT_DIR, CAVE_ID)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

-- Descent(64) + cave-load submodes + emerge(48) + margin.
local CAPTURE_FRAMES = CAPTURE_FRAMES or 130
local CHR_REF_FRAME  = 32   -- frame to dump full CHR+CIRAM once (mid-descent)

-- ─── NES RAM cell map (reference/aldonunez/Variables.inc) ───────────
local CELL_CUR_LEVEL     = 0x0010
local CELL_GAME_MODE     = 0x0012
local CELL_GAME_SUBMODE  = 0x0013
local CELL_FRAME_COUNTER = 0x0015
local CELL_OBJ_X0        = 0x0070  -- ObjX[0] Link
local CELL_OBJ_Y0        = 0x0084  -- ObjY[0] Link
local CELL_OBJ_TYPE0     = 0x034E  -- ObjType[0] (parity w/ Gen ObjType+1 capture)
local CELL_OBJ_DIR0      = 0x0098  -- ObjDir[0]
local CELL_ROOM_ID       = 0x00EB
local CELL_OBJ_GRIDOFF0  = 0x0394  -- ObjGridOffset[0]
local CELL_OBJ_ANIMCTR0  = 0x03D0  -- ObjAnimCounter[0]
local CELL_OBJ_ANIMFRM0  = 0x03E4  -- ObjAnimFrame[0]
local CELL_FADE_CYCLE    = 0x051C  -- FadeCycle (visible mid-fade)
local CELL_STAIRS_TGT_Y  = 0x0412  -- StairsTargetY (CommonVars.inc:11)
local CELL_TARGET_MODE   = 0x005B  -- TargetMode
local CELL_UG_ENTRANCE   = 0x0065  -- UndergroundEntranceTile
local CELL_COLLIDED_TILE = 0x049E  -- ObjCollidedTile[0] (UpdateMode10Stairs gates
                                   -- the DESCENT animation on this == $24)
local CELL_UG_EXIT_TYPE  = 0x005A  -- UndergroundExitType
local CELL_EFFECT_REQ    = 0x0603  -- EffectRequest (stairs SFX $08)
local CELL_CUR_QUEST     = 0x062D
local CELL_PPUCTRL       = 0x00FF  -- CurPpuControl_2000 (8x16 + spr table)
local PLAY_AREA_TILES    = 0x6530  -- PlayAreaTiles base

-- ─── Domain readers (NesHawk) ───────────────────────────────────────
-- This NesHawk build exposes NO "RAM" domain. CPU RAM ($0000-$07FF) AND cart
-- WRAM ($6000-$7FFF, where PlayAreaTiles $6530 lives) are both reachable via
-- "System Bus" ($0000-$FFFF, size 65536) at the raw address. (The legacy
-- golden's "RAM" reads silently fell back here — same class of bug the Genesis
-- "68K RAM" hit.) Live-enumerated 2026-05-30.
local function R(o)   return memory.read_u8(o, "System Bus") end
local function W(o,v) memory.write_u8(o, v, "System Bus") end
local function OAM(o) return memory.read_u8(o, "OAM") end
local function PAL(o) return memory.read_u8(o, "PALRAM") end
local function CHR(o) return memory.read_u8(o, "VRAM") end          -- CHR-RAM
local function NT(o)  return memory.read_u8(o, "CIRAM (nametables)") end
local function idle(n) for _=1,n do emu.frameadvance() end end

local function LOG(s)
    local fh = io.open(OUT .. "\\dbg.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end

-- RULE V3.1: enumerate domains live; never assume a domain name exists.
-- A wrong/absent domain silently returns garbage (e.g. quickerNES has no
-- "VRAM" for CHR-RAM games) -> poisoned golden. Abort loud if any missing.
local function assert_domains(needed)
    local have = {}
    for _, d in ipairs(memory.getmemorydomainlist()) do have[d] = true end
    for _, name in ipairs(needed) do
        if not have[name] then
            LOG(string.format("FATAL: domain '%s' absent (wrong core?) — aborting", name))
            client.exit(); error("missing domain " .. name)
        end
    end
end

-- io.open wrapper: fail loud on a nil handle (disk full / perms) instead of
-- crashing on f:write to nil.
local function open_bin(path)
    local f = io.open(path, "wb")
    if not f then
        LOG("FATAL: cannot open " .. path .. " — aborting"); client.exit(); error("open " .. path)
    end
    return f
end

-- ─── Boot to gameplay via battery SRAM (core-agnostic) ──────────────
-- Identical to probe_nes_cave_golden.lua: poll-press Start until GameMode
-- enters play ($05..$07).
local function boot_to_gameplay()
    LOG(string.format("boot start: gm=$%02X rm=$%02X", R(CELL_GAME_MODE), R(CELL_ROOM_ID)))
    for f = 1, 1800 do
        local gm = R(CELL_GAME_MODE)
        if gm >= 0x05 and gm <= 0x07 then
            LOG(string.format("boot: play gm=$%02X rm=$%02X at f=%d", gm, R(CELL_ROOM_ID), f))
            idle(20); return true
        end
        if (f % 16) == 0 then joypad.set({Start=true}, 1) else joypad.set({}, 1) end
        emu.frameadvance()
    end
    LOG("boot FAIL: never reached play GameMode")
    return false
end

-- ─── Trigger the descent via the REAL CheckWarps gate (no GameMode poke) ──
-- RULE ZERO: poking GameMode=$10 gave a clean descent but a TRUNCATED emerge
-- (ObjGridOffset force-cleared $2A->$00 after 8 px; the real emerge walks the
-- full $30=48 px). To get the TRUE descent + cave-load + InitMode_WalkCave
-- emerge, satisfy CheckWarps (Z_05.asm:7213) so the GAME runs the whole
-- sequence itself with correct init:
--   CheckWarps fires HandleWarpOW iff (in play mode):
--     UndergroundExitType==0  AND  ObjGridOffset==0     (Link standing, $7217)
--     ObjX & $0F == 0          (X on 16-px grid, $7235)
--     ObjY & $0F == $0D        (Y at mult-$10 + $D, $7241)
--     CurLevel == 0            (OW, $7251 BEQ HandleWarpOW)
--     GetCollidableTileStill == warp tile  ($7247 -> ObjCollidedTile)
-- So: park a STANDING grid-aligned Link on an all-$24 grid and let play tick.
-- HandleWarpOW -> SetTargetMode -> GameMode=$10 with InitMode10 setting
-- StairsTargetY + EffectRequest itself. Anchor = first frame GameMode==$10.
local function start_descent()
    W(CELL_CUR_LEVEL, 0x00)
    W(CELL_ROOM_ID,   OW_ROOM)
    W(CELL_CUR_QUEST, QUEST)
    idle(4)
    -- Fill PlayAreaTiles $24 so GetCollidableTileStill returns $24 at Link's
    -- hotspot regardless of the exact ObjX->cell mapping.
    for col = 0, 15 do
        for row = 0, 0x15 do
            W(PLAY_AREA_TILES + col * 0x16 + row, 0x24)
        end
    end
    -- Park a STANDING, grid-aligned Link: X mult-of-$10, Y = (mult-$10)+$D,
    -- ObjGridOffset=0 + UndergroundExitType=0 so CheckWarps proceeds.
    W(CELL_OBJ_X0,       0x70)            -- $70 & $0F == 0
    W(CELL_OBJ_Y0,       0x8D)            -- $8D & $0F == $D
    W(CELL_OBJ_GRIDOFF0, 0x00)
    W(CELL_UG_EXIT_TYPE, 0x00)
    -- Let play-mode CheckWarps fire the warp on its own (NO GameMode poke).
    for _ = 1, 30 do
        emu.frameadvance()
        if R(CELL_GAME_MODE) == 0x10 then return emu.framecount() end
    end
    LOG(string.format("DESCENT FAIL: CheckWarps never fired (gm=$%02X x=$%02X y=$%02X grid=$%02X)",
                      R(CELL_GAME_MODE), R(CELL_OBJ_X0), R(CELL_OBJ_Y0), R(CELL_OBJ_GRIDOFF0)))
    return nil
end

-- ─── Bundle writer (NCTB = NES Cave Transition Bundle) ──────────────
-- Per-frame fNNN.bin layout:
--   "NCTB"(4) u8 frame_off
--   13 state bytes: GameMode,Submode,FrameCounter, ObjX,ObjY,ObjDir,
--                   ObjGridOffset,ObjAnimFrame,ObjAnimCounter,
--                   EffectRequest,FadeCycle,ppuctrl,ObjType[0]
--   OAM 256 ($0200 shadow) ; PALRAM 32 ($3F00)
-- Total per frame = 4+1+13+256+32 = 306 bytes.
-- Full CHR(8192)+CIRAM(2048) dumped ONCE to chr_ref.bin at CHR_REF_FRAME
-- (sprite/BG patterns are static across the window; no need per frame).
local function capture(frame_off)
    local f = open_bin(string.format("%s\\f%03d.bin", OUT, frame_off))
    f:write("NCTB")
    f:write(string.char(frame_off & 0xFF))
    f:write(string.char(R(CELL_GAME_MODE)))
    f:write(string.char(R(CELL_GAME_SUBMODE)))
    f:write(string.char(R(CELL_FRAME_COUNTER)))
    f:write(string.char(R(CELL_OBJ_X0)))
    f:write(string.char(R(CELL_OBJ_Y0)))
    f:write(string.char(R(CELL_OBJ_DIR0)))
    f:write(string.char(R(CELL_OBJ_GRIDOFF0)))
    f:write(string.char(R(CELL_OBJ_ANIMFRM0)))
    f:write(string.char(R(CELL_OBJ_ANIMCTR0)))
    f:write(string.char(R(CELL_EFFECT_REQ)))
    f:write(string.char(R(CELL_FADE_CYCLE)))
    f:write(string.char(R(CELL_PPUCTRL)))
    f:write(string.char(R(CELL_OBJ_TYPE0)))
    for i = 0, 255 do f:write(string.char(OAM(i))) end
    for i = 0, 31  do f:write(string.char(PAL(i))) end
    f:close()
end

local function capture_chr_ref()
    local f = open_bin(OUT .. "\\chr_ref.bin")
    f:write("NCHR")
    for i = 0, 8191 do f:write(string.char(CHR(i))) end
    for i = 0, 2047 do f:write(string.char(NT(i)))  end
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("NES cave TRANSITION: cave=$%02X quest=%d ow=$%02X",
                    CAVE_ID, QUEST, OW_ROOM))
assert_domains({"System Bus", "OAM", "PALRAM", "VRAM", "CIRAM (nametables)"})
if not boot_to_gameplay() then
    LOG("BOOT FAIL — no capture"); client.exit(); return
end

local anchor = start_descent()
if not anchor then
    LOG("DESCENT START FAIL — GameMode never reached $10"); client.exit(); return
end
LOG(string.format("descent anchored at framecount=%d (gm=$%02X obj_y=$%02X)",
                  anchor, R(CELL_GAME_MODE), R(CELL_OBJ_Y0)))

for off = 0, CAPTURE_FRAMES - 1 do
    capture(off)
    if off == CHR_REF_FRAME then capture_chr_ref() end
    emu.frameadvance()
end

LOG(string.format("done: %d frames -> %s", CAPTURE_FRAMES, OUT))
client.screenshot(OUT .. "\\shot.png")
client.exit()
