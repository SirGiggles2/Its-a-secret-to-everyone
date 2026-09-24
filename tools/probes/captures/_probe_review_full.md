You are reviewing TWO BizHawk Lua probes for a Zelda 1 NES→Sega Genesis byte-parity port, BEFORE they are run (mandatory per project RULE V2). These probes capture the cave-ENTRY ANIMATION (Link descends into a cave, scene swaps, Link emerges) for a byte-exact NES-vs-Genesis diff. A silent probe bug (wrong domain, wrong address, mid-animation anchor, off-by-one) poisons every downstream golden. Find every such bug.

The files are on disk — read them if you have file access:
- tools/parity/cave_golden/probe_nes_cave_transition.lua
- tools/parity/cave_golden/probe_gen_cave_transition.lua
Full source is also pasted below.

## Verified ground truth (already confirmed against reference/aldonunez/*.asm + Variables.inc)
- NES RAM cells: GameMode=$12, GameSubmode=$13, FrameCounter=$15, ObjX[0]=$70, ObjY[0]=$84, ObjDir[0]=$98, ObjGridOffset[0]=$394, ObjAnimCounter[0]=$3D0, ObjAnimFrame[0]=$3E4, FadeCycle=$51C, EffectRequest=$603, UndergroundEntranceTile=$65, UndergroundExitType=$5A, TargetMode=$5B, CurPpuControl_2000=$FF, PlayAreaTiles=$6530, RoomId=$EB, CurLevel=$10, CurQuest=$62D.
- InitMode10 (Z_05.asm:1399) runs as GameMode $10 submode 0: JSR GetCollidableTileStill; CMP #$24; if equal sets EffectRequest=$08 and StairsTargetY=ObjY+$10; else SKIPS. GetCollidableTileStill (Z_07.asm:2110) reads the tile under Link's hotspot from PlayAreaTiles ($6530), col-major (col*0x16+row, 22 rows).
- Descent: every 4 frames (FrameCounter&3==0) INC ObjY, 16 px / 64 frames. Behind-BG bit $20 set on OAM slots $12/$13 only; upper slots $10/$11 ride at Y=$F8. Walk pose advances every 6 frames (ObjAnimCounter rollover at $06). Emerge: ObjGridOffset=$30 (48 px) at 1 px/frame.
- NES domains (NesHawk): "RAM","OAM","PALRAM","VRAM"(=CHR-RAM 8KB),"CIRAM (nametables)".
- Genesis domains (genplus-gx): "68K RAM" (NES mirror at $8000+addr), "VRAM" (SAT@$F800 — mutation-proven in probe_gen_cave_golden.lua), "CRAM", "VSRAM". players[0].x=68KRAM $1564 (BE short), .y=$1566, s_scene low byte=$0281, in_gameplay=$0274, room=$0041.

## Specific things to check (be concrete; severity BLOCKER/MAJOR/MINOR/NIT, with the fix)
1. ADDRESS CORRECTNESS: every memory.read_u8/write_u8 offset + domain. Wrong domain or addr = garbage golden. Is FadeCycle=$51C / EffectRequest=$603 / ObjGridOffset=$394 / ObjAnimFrame=$3E4 / ObjAnimCounter=$3D0 read correctly on BOTH sides (NES "RAM" vs Gen "68K RAM" $8000+addr)?
2. NES BAND-FORCE: probe_nes computes col=(ObjX>>3)&0x1F and writes $24 into PlayAreaTiles cols c-1..c+1, all 22 rows. Will GetCollidableTileStill's hotspot (ObjY-8 for Link, per Z_07.asm:2110) actually land in a forced cell? Is the col->PlayAreaTiles mapping (col*0x16+row) correct, and is ObjX>>3 the right col when PlayAreaTiles rows=0x16=22? Could the hotspot read a DIFFERENT structure (nametable/CIRAM) than PlayAreaTiles?
3. NES ANCHOR: setting GameSubmode=0 then GameMode=$10 — does the NES mode dispatcher actually run InitMode10 (submode 0) on the next frame, or does the prior mode's submode machinery interfere? Is the 8-frame anchor poll correct?
4. GEN "ARM ONCE": probe_gen arms the $24 tile + Link pos + WALK mode for ONE frame then clears. The golden probe warns that re-forcing every frame FIGHTS cave_fade. Does this probe correctly avoid re-forcing during the 130-frame capture loop? Is anchoring frame 0 at the arm frame valid vs the NES GameMode=$10 anchor (the differ allows ±1 frame)?
5. FRAME ALIGNMENT: NES anchors on GameMode=$10; Gen anchors on the arm frame. Both then capture 130 frames. Is the cadence comparable? Note Gen GameMode mirror stays $05 (no mode $10) — so GameMode must NOT be raw-compared (the differ handles this). Is capturing it still useful (yes, for phase mapping)? 
6. RULE V3 COMPLETENESS: are all domains enumerated/used in full ranges with metadata? Anything missing for the stated goal (ObjY trajectory, sprite Y/X/attr/tile, walk-pose cadence, behind-BG, palette, EffectRequest)? Is dumping CHR/VRAM once at frame 32 (not per frame) safe given patterns are static across the window?
7. CRASH/HANG: any nil deref, infinite loop, file-handle leak, missing client.exit on an early-return path? os.execute mkdir correctness on Windows?
8. CORE ASSUMPTIONS: NES probe requires NesHawk for "VRAM" CHR-RAM reads — is that the only core-specific risk? Gen SAT@$F800 — trust the mutation-proof or re-verify?

End with VERDICT: APPROVE / APPROVE-WITH-CHANGES / REWORK and the single highest-priority fix.

==================== probe_nes_cave_transition.lua ====================
(see file tools/parity/cave_golden/probe_nes_cave_transition.lua — read it)

==================== probe_gen_cave_transition.lua ====================
(see file tools/parity/cave_golden/probe_gen_cave_transition.lua — read it)

==================== FULL SOURCE: probe_nes_cave_transition.lua ====================
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
-- Globals (run_*_transition.py prelude or manual):
--   CAVE_ID (0x6A..0x7D), QUEST (1/2), OW_ROOM (host OW room), OUT_DIR.

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
local CELL_OBJ_DIR0      = 0x0098  -- ObjDir[0]
local CELL_ROOM_ID       = 0x00EB
local CELL_OBJ_GRIDOFF0  = 0x0394  -- ObjGridOffset[0]
local CELL_OBJ_ANIMCTR0  = 0x03D0  -- ObjAnimCounter[0]
local CELL_OBJ_ANIMFRM0  = 0x03E4  -- ObjAnimFrame[0]
local CELL_FADE_CYCLE    = 0x051C  -- FadeCycle (visible mid-fade)
local CELL_TARGET_MODE   = 0x005B  -- TargetMode
local CELL_UG_ENTRANCE   = 0x0065  -- UndergroundEntranceTile
local CELL_UG_EXIT_TYPE  = 0x005A  -- UndergroundExitType
local CELL_EFFECT_REQ    = 0x0603  -- EffectRequest (stairs SFX $08)
local CELL_CUR_QUEST     = 0x062D
local CELL_PPUCTRL       = 0x00FF  -- CurPpuControl_2000 (8x16 + spr table)
local PLAY_AREA_TILES    = 0x6530  -- PlayAreaTiles base

-- ─── Domain readers (NesHawk) ───────────────────────────────────────
local function R(o)   return memory.read_u8(o, "RAM") end
local function W(o,v) memory.write_u8(o, v, "RAM") end
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

-- ─── Force the REAL descent (GameMode $10 submode 0 = InitMode10) ───
-- Settle in OW_ROOM, force a $24 band under Link's column into PlayAreaTiles
-- so GetCollidableTileStill returns $24 at the hotspot, then GameMode=$10 +
-- GameSubmode=0. InitMode10 then sets StairsTargetY=ObjY+$10 itself and the
-- descend runs for real. Returns the start (anchor) framecount, or nil.
local function start_descent()
    W(CELL_CUR_LEVEL, 0x00)
    W(CELL_ROOM_ID,   OW_ROOM)
    W(CELL_CUR_QUEST, QUEST)
    idle(4)
    -- Link's tile column from ObjX (OW playfield tiles are 8 px; PlayAreaTiles
    -- is col-major col*0x16+row, 22 rows). Band cols c-1..c+1, all rows.
    local objx = R(CELL_OBJ_X0)
    local col  = (objx >> 3) & 0x1F
    for c = col - 1, col + 1 do
        if c >= 0 and c <= 0x0F then
            for row = 0, 0x15 do
                W(PLAY_AREA_TILES + c * 0x16 + row, 0x24)
            end
        end
    end
    -- Drive SetTargetMode's tail exactly (Z_05.asm:7284+): cave id from
    -- LevelBlockAttrsB[RoomId]; mode B regular / C shortcut.
    local cave_mode = (CAVE_ID >= 0x7B) and 0x0C or 0x0B
    W(CELL_UG_ENTRANCE, 0x24)
    W(CELL_TARGET_MODE, cave_mode)
    W(CELL_GAME_SUBMODE, 0x00)        -- so GameMode $10 runs InitMode10 (sub 0)
    W(CELL_GAME_MODE,    0x10)
    -- Anchor: first frame mode $10 is actually live.
    for _ = 1, 8 do
        if R(CELL_GAME_MODE) == 0x10 then return emu.framecount() end
        emu.frameadvance()
    end
    return (R(CELL_GAME_MODE) == 0x10) and emu.framecount() or nil
end

-- ─── Bundle writer (NCTB = NES Cave Transition Bundle) ──────────────
-- Per-frame fNNN.bin layout:
--   "NCTB"(4) u8 frame_off
--   12 state bytes: GameMode,Submode,FrameCounter, ObjX,ObjY,ObjDir,
--                   ObjGridOffset,ObjAnimFrame,ObjAnimCounter,
--                   EffectRequest,FadeCycle,ppuctrl
--   OAM 256 ($0200 shadow) ; PALRAM 32 ($3F00)
-- Total per frame = 4+1+12+256+32 = 305 bytes.
-- Full CHR(8192)+CIRAM(2048) dumped ONCE to chr_ref.bin at CHR_REF_FRAME
-- (sprite/BG patterns are static across the window; no need per frame).
local function capture(frame_off)
    local f = io.open(string.format("%s\\f%03d.bin", OUT, frame_off), "wb")
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
    for i = 0, 255 do f:write(string.char(OAM(i))) end
    for i = 0, 31  do f:write(string.char(PAL(i))) end
    f:close()
end

local function capture_chr_ref()
    local f = io.open(OUT .. "\\chr_ref.bin", "wb")
    f:write("NCHR")
    for i = 0, 8191 do f:write(string.char(CHR(i))) end
    for i = 0, 2047 do f:write(string.char(NT(i)))  end
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("NES cave TRANSITION: cave=$%02X quest=%d ow=$%02X",
                    CAVE_ID, QUEST, OW_ROOM))
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

==================== FULL SOURCE: probe_gen_cave_transition.lua ====================
-- probe_gen_cave_transition.lua — Genesis (Debug.md) cave-ENTRY-ANIMATION capture.
--
-- Sibling of probe_gen_cave_golden.lua. The golden probe enters the cave then
-- SETTLES ~90 frames and samples the static interior at {0,8,16,24,60,120}.
-- THIS probe captures EVERY frame of the TRANSITION: it arms the cave-entry
-- gate on ONE frame (forced $24 under a grid-aligned Link, WALK mode), then
-- — without re-forcing anything — records each frame while cave_fade runs its
-- Link-descend, scene swap, and emerge. Pairs with
-- probe_nes_cave_transition.lua; cave_transition_diff.py compares them after
-- NES->Gen normalization (reusing cave_byte_diff.py's LUT + sprite decode).
--
-- Anchor: frame 0 = the frame immediately AFTER the single arm frame (when
-- cave_fade_begin_enter has fired). The NES side anchors on its GameMode=$10
-- instant; the differ tolerates a +-1 frame capture-phase shift.
--
-- CRITICAL (proven in probe_gen_cave_golden.lua): re-forcing tile/pos/mode
-- every frame FIGHTS cave_fade (pins Y, resets mode, re-fires cave_init ->
-- garbled SAT/text). So we arm exactly once, release fully, then only READ.
--
-- Genesis domains (genplus-gx): "68K RAM" (NES mirror @ $8000+addr),
-- "VRAM" (SAT @ $F800 per _oam_dma_flush; planes $C000/$E000), "CRAM" (128B).
--
-- Globals (run_*_transition.py prelude or manual):
--   CAVE_ID, QUEST, OUT_DIR, OW_ROOM.

CAVE_ID = CAVE_ID or 0x6A
QUEST   = QUEST   or 1
OUT_DIR = OUT_DIR or "C:\\tmp\\cave_golden"
OW_ROOM = OW_ROOM or 0x77

local OUT = string.format("%s\\gen_%02X_trans", OUT_DIR, CAVE_ID)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

local CAPTURE_FRAMES = CAPTURE_FRAMES or 130
local CHR_REF_FRAME  = 32

-- ─── 68K RAM offsets (nes_ram mirror + port state) ──────────────────
local OFF_SCENE       = 0x0281   -- s_scene low byte
local OFF_IN_GAMEPLAY = 0x0274
local OFF_LINK_X      = 0x1564   -- players[0].x (BE short)
local OFF_LINK_Y      = 0x1566   -- players[0].y (BE short)
local SCENE_CAVE      = 2
local SAT_BASE        = 0xF800   -- VDP SAT (mutation-proven in golden probe)

-- nes_ram low offsets (read via 0x8000 + addr), identical to NES probe
local N_GAME_MODE     = 0x0012
local N_GAME_SUBMODE  = 0x0013
local N_FRAME_COUNTER = 0x0015
local N_OBJ_X0        = 0x0070
local N_OBJ_Y0        = 0x0084
local N_OBJ_DIR0      = 0x0098
local N_OBJ_GRIDOFF0  = 0x0394
local N_OBJ_ANIMCTR0  = 0x03D0
local N_OBJ_ANIMFRM0  = 0x03E4
local N_FADE_CYCLE    = 0x051C
local N_EFFECT_REQ    = 0x0603
local N_OBJTYPE_1     = 0x0350

local function r8(o)   return memory.read_u8(o, "68K RAM") end
local function w8(o,v) memory.write_u8(o, v, "68K RAM") end
local function nes_r8(a) return r8(0x8000 + a) end
local function read_scene() return r8(OFF_SCENE) end
local function read_room()  return r8(0x0041) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b) joypad.set(b) end
local function press_for(b, n) press(b); emu.frameadvance(); press({}); idle(math.max(0, n - 1)) end

local function LOG(s)
    local fh = io.open(OUT .. "\\dbg.txt", "a")
    if fh then fh:write(s .. "\n"); fh:close() end
    print(s)
end

local function write_link_xy(x, y)
    w8(OFF_LINK_X, (x >> 8) & 0xFF); w8(OFF_LINK_X + 1, x & 0xFF)
    w8(OFF_LINK_Y, (y >> 8) & 0xFF); w8(OFF_LINK_Y + 1, y & 0xFF)
end
local function force_warp_tile(col, row, tile)
    w8(0x8000 + 0x6530 + col * 0x16 + row, tile)  -- nes_ram play-area cache
    w8(0x0285 + col * 22 + row, tile)             -- s_raw_tiles[col][row]
end
local function clear_warp_tile()
    w8(0x8000 + 0x6530 + 15 * 0x16 + 9, 0x00)
    w8(0x0285 + 15 * 22 + 9, 0x00)
end
local function force_mode_walk() for i = 0x027A, 0x027D do w8(i, 0) end end

-- ─── Boot (A+B+C chord, Phase E) ────────────────────────────────────
local function boot_to_gameplay()
    for frame = 1, 1500 do
        if frame >= 30 and frame <= 600 and (frame % 30) == 0 then
            press({["P1 A"]=true, ["P1 B"]=true, ["P1 C"]=true})
        end
        emu.frameadvance()
        if r8(OFF_IN_GAMEPLAY) == 1 then idle(60); return true end
    end
    return false
end

-- ─── Teleport navigate to OW_ROOM (MODE_TELEPORT debug) ─────────────
local function navigate_to_room(target)
    write_link_xy(0x78, 0x70)
    press_for({["P1 X"]=true}, 8)
    for _ = 1, 64 do
        local cur = read_room()
        if cur == target then break end
        local cc, cr = cur & 0x0F, (cur >> 4) & 0x07
        local tc, tr = target & 0x0F, (target >> 4) & 0x07
        if cc > tc then press_for({["P1 Left"]=true}, 16)
        elseif cc < tc then press_for({["P1 Right"]=true}, 16)
        elseif cr > tr then press_for({["P1 Up"]=true}, 16)
        elseif cr < tr then press_for({["P1 Down"]=true}, 16)
        else break end
    end
    press_for({["P1 X"]=true}, 8)
    idle(30)
end

-- ─── Arm cave-entry ONCE, return anchor framecount ──────────────────
-- Arm the warp on exactly one frame (forced $24 + grid-aligned Link + WALK
-- mode), then release. cave_fade_begin_enter fires; the descent runs over
-- the following frames. Anchor = the frame right after the arm.
local function arm_descent()
    navigate_to_room(OW_ROOM)
    idle(30)
    force_warp_tile(15, 9, 0x24)
    write_link_xy(15 * 8, 9 * 8 + 0x35)
    force_mode_walk()
    emu.frameadvance()        -- the single arm frame
    clear_warp_tile()         -- release immediately; never re-force
    return emu.framecount()
end

-- ─── Bundle writer (GCTB = Gen Cave Transition Bundle) ──────────────
-- Per-frame fNNN.bin layout:
--   "GCTB"(4) u8 frame_off
--   3 port-state bytes: s_scene, link_x_hi-derived? (keep raw):
--     we store the 16-bit players[0].x and .y (BE) = 4 bytes
--   12 nes_ram bytes: GameMode,Submode,FrameCounter, ObjX,ObjY,ObjDir,
--                     ObjGridOffset,ObjAnimFrame,ObjAnimCounter,
--                     EffectRequest,FadeCycle,ObjType+1
--   SAT 512 ($F800, 64 sprites x 8 bytes) ; CRAM 128
--   NES OAM mirror 256 ($0200 low) = source sprite list
-- Total = 4+1+1+4+12+512+128+256 = 918 bytes.
-- Full VRAM(64KB) dumped ONCE to vram_ref.bin at CHR_REF_FRAME.
local function vram_block(start, size)
    local b = {}
    for i = 0, size - 1 do b[#b+1] = string.char(memory.read_u8(start + i, "VRAM")) end
    return table.concat(b)
end
local function dom_block(dom, size)
    local b = {}
    for i = 0, size - 1 do b[#b+1] = string.char(memory.read_u8(i, dom)) end
    return table.concat(b)
end

local function capture(frame_off)
    local f = io.open(string.format("%s\\f%03d.bin", OUT, frame_off), "wb")
    f:write("GCTB")
    f:write(string.char(frame_off & 0xFF))
    f:write(string.char(read_scene()))
    f:write(string.char(r8(OFF_LINK_X))); f:write(string.char(r8(OFF_LINK_X + 1)))
    f:write(string.char(r8(OFF_LINK_Y))); f:write(string.char(r8(OFF_LINK_Y + 1)))
    f:write(string.char(nes_r8(N_GAME_MODE)))
    f:write(string.char(nes_r8(N_GAME_SUBMODE)))
    f:write(string.char(nes_r8(N_FRAME_COUNTER)))
    f:write(string.char(nes_r8(N_OBJ_X0)))
    f:write(string.char(nes_r8(N_OBJ_Y0)))
    f:write(string.char(nes_r8(N_OBJ_DIR0)))
    f:write(string.char(nes_r8(N_OBJ_GRIDOFF0)))
    f:write(string.char(nes_r8(N_OBJ_ANIMFRM0)))
    f:write(string.char(nes_r8(N_OBJ_ANIMCTR0)))
    f:write(string.char(nes_r8(N_EFFECT_REQ)))
    f:write(string.char(nes_r8(N_FADE_CYCLE)))
    f:write(string.char(nes_r8(N_OBJTYPE_1)))
    f:write(vram_block(SAT_BASE, 512))           -- SAT
    f:write(dom_block("CRAM", 128))              -- CRAM
    for i = 0, 255 do f:write(string.char(nes_r8(0x0200 + i))) end  -- NES OAM mirror
    f:close()
end

local function capture_vram_ref()
    local f = io.open(OUT .. "\\vram_ref.bin", "wb")
    f:write("GVRM")
    f:write(vram_block(0x0000, 0x10000))         -- full 64KB
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("Gen cave TRANSITION: cave=$%02X ow=$%02X", CAVE_ID, OW_ROOM))
if not boot_to_gameplay() then LOG("BOOT FAIL"); client.exit(); return end

local anchor = arm_descent()
LOG(string.format("armed at framecount=%d scene=%d obj_y=$%02X",
                  anchor, read_scene(), nes_r8(N_OBJ_Y0)))

local saw_cave = false
for off = 0, CAPTURE_FRAMES - 1 do
    capture(off)
    if off == CHR_REF_FRAME then capture_vram_ref() end
    if read_scene() == SCENE_CAVE then saw_cave = true end
    emu.frameadvance()
end

LOG(string.format("done: %d frames, saw_cave=%s objtype1=$%02X -> %s",
                  CAPTURE_FRAMES, tostring(saw_cave), nes_r8(N_OBJTYPE_1), OUT))
client.screenshot(OUT .. "\\shot.png")
client.exit()
