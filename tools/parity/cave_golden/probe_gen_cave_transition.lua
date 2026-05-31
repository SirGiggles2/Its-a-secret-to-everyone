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
-- NOTE: the REAL players[] is at M68K $FF1570 (nm Debug.out: `players`=e0ff1570;
-- .x word @ $1570, .y word @ $1572). This probe keeps the legacy $1564/$1566
-- here ON PURPOSE: write_link_xy is used by navigate_to_room to "park" Link
-- before the teleport sequence, and the teleport drives real movement itself —
-- pointing write_link_xy at the real $1570 disrupts that nav (crashes the run).
-- The only consequence of the stale addr is the DESCENT-window ObjX mirror
-- ($78 vs NES $70) — a probe-parking cosmetic, not a gameplay divergence
-- (in-cave ObjX is correct $70). A clean fix needs a nav that tolerates a real
-- pre-park; deferred. Use $1570/$1572 if/when that nav is reworked.
local OFF_LINK_X      = 0x1564   -- (stale; see note above)
local OFF_LINK_Y      = 0x1566
local SCENE_CAVE      = 2
-- GAMEPLAY SAT base = $F400 (SGDK SLIST_DEFAULT; roomrom_vram_map.h:43),
-- live-verified in cave_byte_diff.py:96 ("$F400 holds the cave-coherent SAT,
-- Link y=192"). genesis_shell sets reg5=$F800 only at BOOT for the TITLE
-- screen; SGDK re-points to $F400 for gameplay, so the $F800 region in-cave
-- is the STALE title SAT. We capture a 2 KB window from $F400 so BOTH the
-- gameplay SAT ($F400) and the legacy title SAT ($F800) are present; the
-- differ reads $F400. (RULE ZERO: the plan/memory's $F800 was the title SAT.)
local SAT_BASE        = 0xF400
local SAT_WINDOW      = 0x800    -- 2 KB: covers $F400 gameplay + $F800 title

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

-- This BizHawk build loads the Genesis Plus GX *Waterbox* core, which exposes
-- NO "68K RAM" domain — work RAM is reachable only via the "M68K BUS" domain
-- (16 MB) at $FF0000+offset. (The older golden probe's "68K RAM" silently fell
-- back to the wrong domain here -> all-00 reads; that is the root cause of the
-- original cave_diff_report's empty Genesis sprites.) Live-enumerated 2026-05-30.
local WORKRAM_BASE = 0xFF0000
local function r8(o)   return memory.read_u8(WORKRAM_BASE + o, "M68K BUS") end
local function w8(o,v) memory.write_u8(WORKRAM_BASE + o, v, "M68K BUS") end
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

-- RULE V3.1: enumerate domains live; abort loud if any expected one is absent
-- (wrong core -> garbage reads -> poisoned golden).
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

local function open_bin(path)
    local f = io.open(path, "wb")
    if not f then
        LOG("FATAL: cannot open " .. path .. " — aborting"); client.exit(); error("open " .. path)
    end
    return f
end

local function write_link_xy(x, y)
    w8(OFF_LINK_X, (x >> 8) & 0xFF); w8(OFF_LINK_X + 1, x & 0xFF)
    w8(OFF_LINK_Y, (y >> 8) & 0xFF); w8(OFF_LINK_Y + 1, y & 0xFF)
end
-- Fill the ENTIRE OW tile grid (16 cols x 22 rows) in BOTH caches with `tile`.
-- The collision routine reads ONE cell at Link's hotspot; on this Waterbox core
-- the (15,9) single-cell the legacy golden used is NOT the cell the gate reads
-- (live: it saw $26 there) — proven by dbg_gate (seen=$26, fire=0) vs dbg_gate2
-- (full-grid fill -> seen=$24, fire=1, SCENE_CAVE at fr76, objtype1=$6A). Full
-- fill is position-independent: whatever cell the hotspot maps to is $24.
-- NOTE: this corrupts the OW BG tiles shown DURING the descent (all $24) — fine
-- for sprite/RAM/anim/SFX capture; Step 6 (behind-BG) will refine to a minimal
-- force for a clean descent BG. cave_init repopulates tiles after SWAP_ENTRY.
local function fill_tiles(tile)
    for col = 0, 15 do
        for row = 0, 21 do
            w8(0x8000 + 0x6530 + col * 0x16 + row, tile)  -- nes_ram play-area cache
            w8(0x0285 + col * 22 + row, tile)             -- s_raw_tiles[col][row]
        end
    end
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
--
-- Cell (15,9) + Link y = 9*8+0x35 = 125 ($7D, y_low=$D) is the SAME arm the
-- proven probe_gen_cave_golden.lua uses (its invariant gate passes: cave
-- loaded, objtype1==CAVE_ID). The live gate (main.c:2089-2095) fires on
-- y_low==$0D + collision_get_collidable_tile_still(0)==$24 — exactly what
-- this sets. (Refutes a review claim that the hotspot reads row 10: the gate
-- keys on y_low + the collision tile, not a +0x0B/HUD row calc.)
local function arm_descent()
    navigate_to_room(OW_ROOM)
    if read_room() ~= OW_ROOM then
        LOG(string.format("FATAL: navigate failed — room=$%02X want $%02X", read_room(), OW_ROOM))
        client.exit(); error("nav fail")
    end
    idle(30)
    -- Park Link at the SAME entrance pos the NES probe uses (ObjX=$70,
    -- ObjY=$8D, y_low=$D) so the DESCENT window's ObjX/ObjY line up frame-for
    -- -frame (Gen descends straight down from here, X constant). Without this
    -- the descent X differed ($78 vs NES $70) = 73 spurious ObjX diffs.
    write_link_xy(0x70, 0x8D)
    w8(0x8000 + 0x70, 0x70)   -- ObjX[0] nes-mirror (re-synced each frame from
                              -- the real players[].x below; harmless seed)
    -- Set the REAL players[] struct (M68K $FF1570 .x word / $FF1572 .y word,
    -- 68K big-endian) AFTER teleport completes — the safe post-teleport frame.
    -- write_link_xy above uses the legacy $1564 (a NO-OP for this build) ONLY so
    -- navigate_to_room's pre-teleport park can't disrupt the teleport machine;
    -- the descent X mirror (nes_ram $70) is re-synced from THIS real .x each
    -- frame, so without it the descent entered at the teleport-park X ($78) =
    -- 73 spurious ObjX diffs vs NES $70. (players[] addr = nm Debug.out.)
    w8(0x1570, 0x00); w8(0x1571, 0x70)   -- players[0].x = $0070 (112)
    w8(0x1572, 0x00); w8(0x1573, 0x8D)   -- players[0].y = $008D (y_low=$D, gate)
    -- Fill the whole tile grid with $24 + force WALK mode, then advance ONE
    -- frame. DO NOT re-force pos/mode after this (that fights cave_fade —
    -- golden's warning); the grid stays $24 until the first SCENE_CAVE frame,
    -- where the capture loop clears it once. Proven flow: gate fires within ~1
    -- frame, descent runs ~64 frames, SWAP_ENTRY -> SCENE_CAVE ~fr76.
    fill_tiles(0x24)
    force_mode_walk()
    emu.frameadvance()        -- the arm frame; grid stays $24
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
--   SAT_WINDOW 2048 ($F400..$FBFF: gameplay SAT @ $F400 + title SAT @ $F800)
--   CRAM 128 ; NES OAM mirror 256 ($0200 low) = source sprite list
-- Total = 4+1+1+4+12+2048+128+256 = 2454 bytes.
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
    local f = open_bin(string.format("%s\\f%03d.bin", OUT, frame_off))
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
    f:write(vram_block(SAT_BASE, SAT_WINDOW))    -- SAT window ($F400 gameplay + $F800 title)
    f:write(dom_block("CRAM", 128))              -- CRAM
    for i = 0, 255 do f:write(string.char(nes_r8(0x0200 + i))) end  -- NES OAM mirror
    f:close()
end

local function capture_vram_ref()
    local f = open_bin(OUT .. "\\vram_ref.bin")
    f:write("GVRM")
    f:write(vram_block(0x0000, 0x10000))         -- full 64KB
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("Gen cave TRANSITION: cave=$%02X ow=$%02X", CAVE_ID, OW_ROOM))
assert_domains({"M68K BUS", "VRAM", "CRAM"})
if not boot_to_gameplay() then LOG("BOOT FAIL"); client.exit(); return end

local anchor = arm_descent()
LOG(string.format("armed at framecount=%d scene=%d obj_y=$%02X",
                  anchor, read_scene(), nes_r8(N_OBJ_Y0)))

-- NOTE on ObjX (descent window): NES forces entrance ObjX=$70; Gen enters via
-- teleport (spawn column $78). The REAL Link position players[0].x can be set to
-- $70, but the nes_ram ObjX mirror ($70/$FF8070) the differ reads is decoupled
-- from players[0].x during cave_fade (a main-loop writer keeps it at the
-- teleport-spawn $78), so the descent-window ObjX shows $78 vs NES $70. This is
-- an entrance-column + mirror-sync artifact, NOT a Link-position divergence
-- (in-cave ObjX matches $70; the MOTION fields ObjY/ObjDir/ObjGridOffset are
-- byte-CLEAN). Left as the documented residual.
local saw_cave = false
for off = 0, CAPTURE_FRAMES - 1 do
    capture(off)
    if off == CHR_REF_FRAME then capture_vram_ref() end
    if read_scene() == SCENE_CAVE then
        if not saw_cave then fill_tiles(0x00) end  -- one-time: stop re-trigger
        saw_cave = true
    end
    emu.frameadvance()
end

-- FAIL LOUD if the arm never produced a cave transition: a 130-frame run that
-- never reached SCENE_CAVE captured overworld gameplay, not the descent.
-- Write a status marker so the differ rejects this bundle instead of blessing
-- garbage (RULE V1: no silent "done" on unverified work).
do
    local objt1 = nes_r8(N_OBJTYPE_1)
    local verdict = (saw_cave and objt1 == CAVE_ID) and "PASS" or "FAIL"
    local sf = io.open(OUT .. "\\status.txt", "w")
    if sf then
        sf:write(string.format("%s saw_cave=%s objtype1=$%02X want=$%02X frames=%d\n",
            verdict, tostring(saw_cave), objt1, CAVE_ID, CAPTURE_FRAMES))
        sf:close()
    end
    LOG(string.format("%s: saw_cave=%s objtype1=$%02X (want $%02X) -> %s",
        verdict, tostring(saw_cave), objt1, CAVE_ID, OUT))
end
client.screenshot(OUT .. "\\shot.png")
client.exit()
