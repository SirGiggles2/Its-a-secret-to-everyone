-- probe_gen_cave_golden.lua — Genesis (Debug.md) per-cave golden capture.
--
-- Mirror of probe_nes_cave_golden.lua for the Genesis port. Enters the
-- cave for CAVE_ID, then captures SAT + CRAM + VRAM at the SAME frame
-- phases {0,8,16,24,60,120} so cave_byte_diff.py can compare each phase.
--
-- Genesis domains (genplus-gx, verified in
-- tools/parity/dungeon_visual_sweep/probe_one_gen.lua):
--   "68K RAM"  (NES mirror at $FF8000 + nes_addr; cells read at low addr)
--   "VRAM"     (SAT at $FC00 640B; planes at $C000/$E000)
--   "CRAM"     (128B = 64 colors)
--
-- Entry path: rather than navigate OW (slow + flaky), use the cave
-- dispatch-bypass proven in probe_one_gen.lua — but cleaner here: boot,
-- then directly call the cave-entry via the SAME forced warp tile +
-- cave-entry gate the live game uses. We force ObjType[1] etc the way
-- cave_init would, matching the NES force-state, so the capture reflects
-- the live render pipeline (cave_dispatch + draw chains), NOT a synthetic
-- poke. The cave-entry GATE (main.c:2089) does the real cave_init +
-- cave_fade; we drive Link onto a forced $24 tile to trigger it.
--
-- Globals (run_gen_golden.py prelude):
--   CAVE_ID, QUEST, OUT_DIR, OW_ROOM (overworld room hosting this cave)

CAVE_ID = CAVE_ID or 0x6A
QUEST   = QUEST   or 1
OUT_DIR = OUT_DIR or "C:\\tmp\\cave_golden"
OW_ROOM = OW_ROOM or 0x77

local OUT = string.format("%s\\gen_%02X", OUT_DIR, CAVE_ID)
os.execute('if not exist "' .. OUT .. '" mkdir "' .. OUT .. '"')

local FRAMES = {0, 8, 16, 24, 60, 120}

-- ─── 68K RAM cell offsets (nes_ram mirror; same low addrs as
--      probe_one_gen.lua) ───────────────────────────────────────────
local OFF_SCENE       = 0x0281   -- s_scene low byte (4-byte int BE)
local OFF_IN_GAMEPLAY = 0x0274
local OFF_FRAME_CTR   = 0x0015   -- nes_ram FrameCounter mirror
local OFF_LINK_X      = 0x1564   -- players[0].x (BE short)
local OFF_LINK_Y      = 0x1566
local SCENE_CAVE      = 2

local function r8(o)   return memory.read_u8(o, "68K RAM") end
local function w8(o,v) memory.write_u8(o, v, "68K RAM") end
local function nes_r8(a) return r8(0x8000 + a) end
local function read_scene() return r8(OFF_SCENE) end
local function idle(n) for _=1,n do emu.frameadvance() end end
local function press(b) joypad.set(b) end
local function press_for(b, n)
    press(b); emu.frameadvance(); press({}); idle(math.max(0, n - 1))
end

local function write_link_xy(x, y)
    w8(OFF_LINK_X,     (x >> 8) & 0xFF)
    w8(OFF_LINK_X + 1, x & 0xFF)
    w8(OFF_LINK_Y,     (y >> 8) & 0xFF)
    w8(OFF_LINK_Y + 1, y & 0xFF)
end

-- Forced cave-entry tile in BOTH caches (nes_ram collision cache +
-- s_raw_tiles BSS), as proven in probe_one_gen.lua.
local function force_warp_tile(col, row, tile)
    w8(0x8000 + 0x6530 + col * 0x16 + row, tile)  -- nes_ram play-area cache
    w8(0x0285 + col * 22 + row, tile)             -- s_raw_tiles[col][row]
end
local function force_mode_walk()
    for i = 0x027A, 0x027D do w8(i, 0) end        -- s_mode int = WALK
end

-- Clear the forced $24 cave-entry trigger from BOTH caches, every frame.
-- DEFENSIVE only: keeps the stale forced tile from re-triggering the OW
-- cave-entry gate if scene were to flip back to OW. (The shop-cave "M MAS
-- MA MAS" text churn was NOT this — a write-watch on $FF8416 proved the
-- writer was a stale slot-4 wanderer's ENEMY_PUSH_TIMER aliasing
-- CAVE_TEXT_CHAR_INDEX; fixed in cave_init via enemy_loop_clear_all_slots.
-- The clear is retained as cheap entry-hygiene.)
local function clear_warp_tile()
    w8(0x8000 + 0x6530 + 15 * 0x16 + 9, 0x00)     -- nes_ram play-area cache
    w8(0x0285 + 15 * 22 + 9, 0x00)                -- s_raw_tiles[15][9]
end
local function idle_clear(n)
    for _=1,n do clear_warp_tile(); emu.frameadvance() end
end

-- ─── Boot (A+B+C chord, Phase E pattern) ────────────────────────────
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
local function read_room() return r8(0x0041) end
local function navigate_to_room(target)
    write_link_xy(0x78, 0x70)               -- park Link off warp row
    press_for({["P1 X"]=true}, 8)           -- enter teleport
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
    press_for({["P1 X"]=true}, 8)           -- exit teleport
    idle(30)
end

-- ─── Enter cave via live gate (forced $24 at canonical row) ─────────
-- Cave-entry gate (main.c:2089) fires when Link.y&0x0F==0x0D + standing
-- tile is $24/$88/$70-$73. Force $24 at (15,9), put Link at the row-9
-- cave-Y (link_y = 9*8 + 0x35 = 0x8D, low nibble $D), poll for scene.
local function enter_cave()
    navigate_to_room(OW_ROOM)
    idle(30)
    -- ARM the warp, then RELEASE. The cave-entry gate fires from OW WALK
    -- when Link stands grid-aligned on a $24 tile; that starts cave_fade,
    -- which runs a ~64-frame Link-descend (incrementing Link Y + changing
    -- mode) before flipping s_scene to CAVE. The OLD loop re-forced the
    -- tile + Link pos + WALK mode EVERY frame for the whole descend, which
    -- FOUGHT cave_fade (pinned Y, reset mode to WALK) and re-triggered
    -- cave_init repeatedly -> stale scattered text + duplicate flames in
    -- every non-home cave (byte-proven: char_idx=3 but ~18 glyphs shown).
    -- Fix: arm only until the warp fires (s_scene leaves a clean OW-WALK
    -- baseline / the coordinator changes mode), then STOP all forcing and
    -- let cave_fade complete uninterrupted.
    -- Arm on EXACTLY ONE frame, then release fully. The coordinator reads
    -- Link's standing tile + alignment + mode each gameplay tick; one
    -- frame with the $24 tile + grid-aligned Link + WALK mode is enough to
    -- fire cave_fade. After that, touching tile/pos/mode AT ALL re-fires
    -- cave_init mid-descend and corrupts the SAT/nametable with stale
    -- accumulated text + flames (the s_mode-left-WALK signal never trips —
    -- cave entry keeps s_mode=WALK and flips s_scene only at SWAP_ENTRY,
    -- 64 frames later). So: arm once, release, poll for scene.
    force_warp_tile(15, 9, 0x24)
    write_link_xy(15 * 8, 9 * 8 + 0x35)
    force_mode_walk()
    emu.frameadvance()
    for _ = 1, 400 do
        if read_scene() == SCENE_CAVE then
            -- CRITICAL: clear the forced $24 trigger from BOTH caches once
            -- inside the cave. If left set, the warp coordinator / cave_fade
            -- RE-TRIGGERS cave entry every ~32 frames -> re-runs cave_init
            -- -> resets CAVE_TEXT_CHAR_INDEX mid-stream -> the dialogue
            -- re-streams its prefix ("M MAS MA MAS" churn) + bonfires
            -- re-spawn (scattered flames). Byte-proven via DBG_TRACE: with
            -- the tile cleared, char_idx climbs 0->59 monotonically; with it
            -- set, char_idx sawtooths 0->5->0. (ROM cave text engine is
            -- correct; this was a pure probe artifact for non-home caves.)
            clear_warp_tile()
            idle_clear(8); return true
        end
        emu.frameadvance()
    end
    return false
end

-- ─── Bundle writer (GCGD = Gen Cave GolDen) ─────────────────────────
-- Layout per frame fNNN.bin:
--   "GCGD" magic (4)
--   u8 frame_phase
--   u8 cave_id
--   u8 s_scene (sanity: should be 2)
--   u8 objtype_1 (nes_ram $0350 — cave_id)
--   CRAM 128 bytes
--   VRAM 0x10000 bytes (FULL 64KB). SAT lives at $F800 (512B, 64 sprites)
--     per _oam_dma_flush (src/nes_io.asm:2300 VDP cmd $78000083 = VRAM
--     write $F800 + DMA). Sprite tile patterns live anywhere in VRAM, so
--     capture all of it — no address guessing.
--   68K RAM 0x10000 bytes (FULL 64KB work RAM). NES OAM mirror @ $0200 is
--     the SOURCE sprite list the port converts -> SAT; nes_ram state cells.
--   VSRAM 80 bytes (vertical scroll).
-- Total = 4 + 4 + 128 + 65536 + 65536 + 80 = 131288 bytes.
local function vram_block(start, size)
    local buf = {}
    for i = 0, size - 1 do buf[#buf+1] = string.char(memory.read_u8(start + i, "VRAM")) end
    return table.concat(buf)
end
local function dom_block(dom, size)
    local buf = {}
    for i = 0, size - 1 do buf[#buf+1] = string.char(memory.read_u8(i, dom)) end
    return table.concat(buf)
end

local function capture(frame_phase)
    local path = string.format("%s\\f%03d.bin", OUT, frame_phase)
    local f = io.open(path, "wb")
    f:write("GCGD")
    f:write(string.char(frame_phase & 0xFF))
    f:write(string.char(CAVE_ID & 0xFF))
    f:write(string.char(read_scene()))
    f:write(string.char(nes_r8(0x0350)))   -- ObjType+1
    f:write(dom_block("CRAM", 128))         -- CRAM (64 colors)
    f:write(vram_block(0x0000, 0x10000))    -- FULL 64KB VRAM (SAT@$F800 + tiles)
    f:write(dom_block("68K RAM", 0x10000))  -- FULL 64KB work RAM (NES OAM
                                            -- mirror @$0200 = source sprite
                                            -- list; nes_ram state; etc)
    f:write(dom_block("VSRAM", 80))         -- vertical scroll
    f:close()
end

-- ─── Main ───────────────────────────────────────────────────────────
print(string.format("Gen cave golden: cave_id=$%02X ow_room=$%02X", CAVE_ID, OW_ROOM))
if not boot_to_gameplay() then print("BOOT FAIL"); client.exit(); return end
if not enter_cave() then
    -- still capture so the differ records a "no entry" rather than silent.
    capture(0)
    print("CAVE ENTRY FAIL"); client.exit(); return
end

-- Post-entry defensive clear (see clear_warp_tile). The settle + capture
-- loops below also re-clear every frame via idle_clear. The real shop-cave
-- text fix lives in the ROM (cave_init enemy_loop_clear_all_slots); the
-- INVARIANT GATE at the tail (char_idx-monotonic + no-alive-slot) is what
-- actually proves it per cave.
clear_warp_tile()

-- DBG_WATCH (one-off, gated by global): register an M68K write-callback on
-- the System-Bus address of nes_ram[$0416] (CAVE_TEXT_CHAR_INDEX) = $FF8416.
-- On every write of value 0 (the mid-stream reset we're hunting), capture the
-- M68K PC of the writing instruction. The PC -> function map pins the EXACT
-- code zeroing char_idx (cave_init vs native reset vs transpiled corert_ vs an
-- unknown bulk clear), which the in-RAM counters can't (they sit in a possibly
-- per-frame-cleared region). Read-only logging.
if DBG_WATCH then
    local hits = {}        -- pc(hex) -> count, for writes of value 0
    local allw = {}        -- pc(hex) -> count, for ALL writes
    local function pcstr()
        local ok, regs = pcall(emu.getregisters)
        if not ok or not regs then return "noregs" end
        -- genplus key is "M68K PC"; fall back to scanning for a PC-ish key.
        local pc = regs["M68K PC"] or regs["PC"] or regs["m68000 PC"]
        if pc == nil then
            for k, v in pairs(regs) do
                if tostring(k):find("PC") then pc = v; break end
            end
        end
        return pc and string.format("%06X", pc & 0xFFFFFF) or "noPC"
    end
    local function on_write(addr, val)
        local p = pcstr()
        allw[p] = (allw[p] or 0) + 1
        if (val or 0) == 0 then hits[p] = (hits[p] or 0) + 1 end
    end
    -- Try the documented bus-write registrations; genplus exposes the 68K bus.
    local reg_ok = false
    for _, scope in ipairs({"System Bus", "M68K BUS", nil}) do
        local ok = pcall(function()
            if scope then event.on_bus_write(on_write, 0xFF8416, scope)
            else            event.on_bus_write(on_write, 0xFF8416) end
        end)
        if ok then reg_ok = true; break end
    end
    local f = io.open("C:/tmp/shop_watch.txt", "w")
    f:write(string.format("cave=$%02X ow=$%02X reg_ok=%s -- writes to $FF8416 (char_idx)\n",
        CAVE_ID, OW_ROOM, tostring(reg_ok)))
    for fr = 1, 160 do clear_warp_tile(); emu.frameadvance() end
    f:write("--- writes of VALUE 0 (the reset) by writer PC ---\n")
    for p, c in pairs(hits) do f:write(string.format("PC=%s  count=%d\n", p, c)) end
    f:write("--- ALL writes by PC ---\n")
    for p, c in pairs(allw) do f:write(string.format("PC=%s  count=%d\n", p, c)) end
    f:close()
    print("DBG_WATCH -> C:/tmp/shop_watch.txt")
    client.exit(); return
end

-- DBG_TRACE (one-off, gated by global): log the cave NPC state machine
-- per frame from entry through settle, to disambiguate the shop-cave text
-- re-stream (re-entry vs CAVE_DELAY_TIMER gate-stall vs $C0 latch). Pure
-- read-only logging + file write; no memory writes, no logic change.
if DBG_TRACE then
    local function C(a) return r8(0x8000 + a) end
    -- TEST: clear the forced $24 warp tile from BOTH caches so the warp
    -- coordinator / cave_fade can't re-trigger cave entry from the stale
    -- forced tile while we trace (isolates probe-persistent-tile re-entry).
    w8(0x8000 + 0x6530 + 15 * 0x16 + 9, 0x00)
    w8(0x0285 + 15 * 22 + 9, 0x00)
    local f = io.open("C:/tmp/shop_trace.txt", "w")
    f:write(string.format("cave=$%02X ow=$%02X (warp tile cleared each frame)\n", CAVE_ID, OW_ROOM))
    -- ps=$00AD person_state, idx=$0416 char_idx, lo=$045F line_addr_lo (CORRECT
    -- cell; $0417 prior was wrong), sel=$0415 selector, dly=$0029 delay,
    -- initN=$07F0 cave_init counter, rstN=$07F1 reset-char-offset counter,
    -- objt1=$0350 ObjType+1.
    f:write("fr sc ps idx lo sel dly | initN rstN objt1\n")
    local pinit, prst = -1, -1
    for fr = 0, 160 do
        local initN, rstN = C(0x07F0), C(0x07F1)
        local mark = ""
        if initN ~= pinit then mark = mark .. " <CAVE_INIT>" end
        if rstN  ~= prst  then mark = mark .. " <RESET_CHAR>" end
        pinit, prst = initN, rstN
        f:write(string.format(
            "%3d sc=%d ps=%d idx=%2d lo=%02X sel=%02X dly=%02X | iN=%d rN=%d ot1=%02X%s\n",
            fr, read_scene(), C(0x00AD), C(0x0416), C(0x045F), C(0x0415), C(0x0029),
            initN, rstN, C(0x0350), mark))
        clear_warp_tile()   -- match capture path: hold tile clear every frame
        emu.frameadvance()
    end
    f:close()
    print("DBG_TRACE -> C:/tmp/shop_trace.txt")
    client.exit(); return
end

-- REVIEW PASS 2 finding: enter_cave() returns at the FIRST scene==CAVE
-- frame, which is during cave_fade SWAP_ENTRY / LINK_DESCEND. The NES
-- side captures at submode 8 (WalkCave = fully settled). To align both
-- to a STABLE post-init state, settle here until cave_fade finishes its
-- descend (16 steps x 4 frames = 64) + a margin. Bonfire OBJ_ANIM_CNTR
-- (per-slot, sprite_runtime.c:104) and Link halt are stable by then.
idle_clear(90)
-- Mirror the NES golden's deterministic restart (probe_nes_cave_golden.lua
-- force_state_cave tail): person_state=0 + Link halt + NPC slot pos, then a
-- short settle. This RESTARTS the dialogue stream from char_idx 0 on BOTH
-- platforms so the per-frame BG text byte-diff is frame-aligned. (Pre-fix
-- this restart exposed the "M MAS MA MAS" churn, but that was a slot-4
-- wanderer aliasing CAVE_TEXT_CHAR_INDEX, now fixed in cave_init — the
-- stream is monotonic, so restart-then-stream matches NES exactly.)
w8(0x8000 + 0x00AD, 0x00)   -- CAVE_PERSON_STATE = 0 (restart dialogue)
w8(0x8000 + 0x00AC, 0x40)   -- ObjState[0] Link halt (nes_ram mirror)
w8(0x8000 + 0x0070 + 1, 0x78)  -- ObjX+1 (NPC slot)
w8(0x8000 + 0x0084 + 1, 0x80)  -- ObjY+1 (NPC slot)
idle_clear(8)

-- DEBUG (one-off, DBG_DUMP global): locate the live SAT + flame pal.
if DBG_DUMP then
    local dbg = io.open("C:/tmp/gen_dbg.txt", "w")
    local ok, regs = pcall(emu.getregisters)
    dbg:write("--- emu.getregisters ---\n")
    if ok and regs then for k, v in pairs(regs) do
        dbg:write(string.format("%s = %s\n", tostring(k), tostring(v))) end
    else dbg:write("getregisters failed\n") end
    dbg:write("--- live OAM mirror $0200 (low) ---\n")
    for i = 0, 63 do
        local y = r8(0x0200 + i*4); local t = r8(0x0201 + i*4)
        local a = r8(0x0202 + i*4); local x = r8(0x0203 + i*4)
        if y ~= 0 or t ~= 0 or x ~= 0 then
            dbg:write(string.format("OAM[%d] y=%02X t=%02X a=%02X x=%02X\n", i, y, t, a, x)) end
    end
    dbg:write("--- live OAM mirror $8200 (high) ---\n")
    for i = 0, 63 do
        local y = r8(0x8200 + i*4); local t = r8(0x8201 + i*4)
        local a = r8(0x8202 + i*4); local x = r8(0x8203 + i*4)
        if y ~= 0 or t ~= 0 or x ~= 0 then
            dbg:write(string.format("OAM8[%d] y=%02X t=%02X a=%02X x=%02X\n", i, y, t, a, x)) end
    end
    -- live SAT scan across candidate VRAM bases (read VRAM live)
    for _, base in ipairs({0xF800, 0xFC00, 0xD800, 0xBC00, 0xB800}) do
        dbg:write(string.format("--- live SAT @ $%04X ---\n", base))
        for s = 0, 24 do
            local o = base + s*8
            local y = memory.read_u16_be(o, "VRAM")
            local w2 = memory.read_u16_be(o+4, "VRAM")
            local x = memory.read_u16_be(o+6, "VRAM")
            if (y & 0x1FF) ~= 0 or (x & 0x1FF) ~= 0 then
                dbg:write(string.format(" s%d y=%d x=%d pal=%d tile=%X link=%d\n",
                    s, (y&0x1FF)-128, (x&0x1FF)-128, (w2>>13)&3, w2&0x7FF,
                    memory.read_u8(o+3,"VRAM")&0x7F))
            end
        end
    end
    dbg:close()
    print("DBG dumped C:/tmp/gen_dbg.txt")
    -- Mutation test: zero each candidate SAT base, screenshot. Whichever
    -- base makes the on-screen sprites VANISH is the VDP-displayed SAT
    -- (reg5 base). Definitive, since genplus does not expose VDP reg5.
    client.screenshot("C:/tmp/zero_before.png")
    for _, base in ipairs({0xF800, 0xFC00, 0xD800, 0xBC00, 0xB800}) do
        local orig = {}
        for i = 0, 639 do orig[i] = memory.read_u8(base + i, "VRAM") end
        for i = 0, 639 do memory.write_u8(base + i, 0, "VRAM") end
        idle(3)
        client.screenshot(string.format("C:/tmp/zero_%04X.png", base))
        for i = 0, 639 do memory.write_u8(base + i, orig[i], "VRAM") end
        idle(3)
    end
    print("DBG mutation screenshots done")
    client.exit()
    return
end

-- Determinism: zero the FrameCounter mirror so phase lines up with NES.
-- (Bonfire cadence is driven by per-slot OBJ_ANIM_CNTR + matched idle
-- counts, but FrameCounter-bit-gated logic like person-blink also needs
-- the same phase-0 baseline on both platforms.)
w8(OFF_FRAME_CTR, 0x00)
local prev = 0
for _, target in ipairs(FRAMES) do
    idle_clear(target - prev)
    prev = target
    capture(target)
end
client.screenshot(OUT .. "\\shot.png")

-- Tier-1 INVARIANT GATE (debate K2 D4, 2026-05-28): cheapest detector for the
-- slot-aliasing bug class that garbled shop-cave text. NO NES golden needed.
-- Two asserts over a 150-frame post-capture window:
--   (1) CAVE_TEXT_CHAR_INDEX ($0416) strictly NON-DECREASING. A decrease means
--       another writer clobbered it (e.g. a stale enemy work-cell alias:
--       ENEMY_PUSH_TIMER $0412+slot collides at slot 4 = $0416). This is the
--       exact signature of the bug fixed in cave_init (enemy_loop_clear_all_slots).
--   (2) NO enemy slot 4..11 ENEMY_ALIVE ($0492+slot): caves must enter on a
--       fresh object page. A live slot means cave_init's clear regressed.
do
    local function C(a) return r8(0x8000 + a) end
    local mono_ok = true
    local prev_idx = C(0x0416)
    local min_idx, max_idx = prev_idx, prev_idx
    for _ = 1, 150 do
        clear_warp_tile(); emu.frameadvance()
        local idx = C(0x0416)
        if idx < prev_idx then mono_ok = false end
        prev_idx = idx
        if idx < min_idx then min_idx = idx end
        if idx > max_idx then max_idx = idx end
    end
    local alive = ""
    for s = 4, 11 do
        if C(0x0492 + s) ~= 0 then alive = alive .. string.format(" slot%d", s) end
    end
    local slots_ok = (alive == "")
    -- (3) cave actually LOADED: ObjType+1 ($0350) must equal CAVE_ID, else the
    --     force-warp picked the wrong/no cave (debate D1: fail loud, never
    --     bless a silent empty/wrong-cave capture).
    local objt1 = C(0x0350)
    local cave_ok = (objt1 == CAVE_ID)
    local verdict = (mono_ok and slots_ok and cave_ok) and "PASS" or "FAIL"
    local f = io.open(OUT .. "\\invariant.txt", "w")
    f:write(string.format(
        "cave=$%02X %s char_idx_monotonic=%s(min=%d,max=%d) no_alive_slots4_11=%s cave_loaded=%s(objt1=$%02X)%s\n",
        CAVE_ID, verdict, tostring(mono_ok), min_idx, max_idx, tostring(slots_ok),
        tostring(cave_ok), objt1,
        (alive ~= "") and (" ALIVE:" .. alive) or ""))
    f:close()
    print("invariant: " .. verdict)
end

print("done: " .. OUT)
client.exit()
