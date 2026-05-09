-- Phase 7 Task 7.2 step 4 -- frame trace probe.
--
-- Verifies enrt_update_rope (UPDATE row $07 wired step 4) actually
-- ticks per frame for force-spawned slow octorok at slot 1. Reads
-- live block at $FF7F00 published every frame by
-- enemy_loop_probe_publish_live() at end of enemy_loop_tick().
--
-- Block layout (must match src/game/enemies/probes/enemy_loop_probe.h):
--   [0..1] = 'T','K' magic
--   [2..3] = frame_counter (be u16)
--   [4]    = ENEMY_ALIVE_FLAG(1)
--   [5]    = ENEMY_TYPE(1)
--   [6]    = ENEMY_X(1)
--   [7]    = ENEMY_Y(1)
--   [8]    = ENEMY_DIR(1)
--   [9]    = ENEMY_ANIM_TIMER(1)
--   [10]   = ENEMY_DRAW_FRAME(1)
--   [11]   = ENEMY_MOVE_TIMER(1)
--   [12]   = ENEMY_STATE_TIMER(1)
--   [13]   = ENEMY_WALK_SPEED(1)
--
-- PASS gates (no oam_router yet, so visual is irrelevant):
--   1. magic == 'TK' (publisher fired at all)
--   2. frame_counter strictly monotonic between samples (tick is hot)
--   3. ENEMY_ALIVE_FLAG(1) stays 1 across the trace
--   4. ENEMY_TYPE(1) stays $07
--   5. ENEMY_ANIM_TIMER(1) decrements OR ENEMY_DRAW_FRAME(1) advances
--      across the 120-frame window (proves enrt_update_rope reached
--      the z07_anim_advance_and_fetch -> sprite_anim_advance_and_fetch
--      bridge call)

local TICK_BASE = 0x7F00     -- $FF7F00 in 68K RAM domain (post-tick)
local PRE_BASE  = 0x7F40     -- $FF7F40 (pre-tick snapshot)
local MULTI_BASE = 0x7F80    -- $FF7F80 step-8 multi-slot block
local PROBE_BASE = 0x7E00    -- $FF7E00 (init probe)
local DOMAIN = "68K RAM"

local function read_u8(base, off)
    return memory.read_u8(base + off, DOMAIN)
end

local function read_u16_be(base, off)
    local hi = memory.read_u8(base + off, DOMAIN)
    local lo = memory.read_u8(base + off + 1, DOMAIN)
    return (hi * 256) + lo
end

local function snapshot()
    return {
        magic_t   = read_u8(TICK_BASE, 0),
        magic_k   = read_u8(TICK_BASE, 1),
        frame     = read_u16_be(TICK_BASE, 2),
        alive     = read_u8(TICK_BASE, 4),
        type_     = read_u8(TICK_BASE, 5),
        x         = read_u8(TICK_BASE, 6),
        y         = read_u8(TICK_BASE, 7),
        dir       = read_u8(TICK_BASE, 8),
        anim_t    = read_u8(TICK_BASE, 9),
        draw_f    = read_u8(TICK_BASE, 10),
        move_t    = read_u8(TICK_BASE, 11),
        state_t   = read_u8(TICK_BASE, 12),
        walk_spd  = read_u8(TICK_BASE, 13),
        link_x    = read_u8(TICK_BASE, 14),
        link_y    = read_u8(TICK_BASE, 15),
    }
end

local OUT_PATH = "C:\\tmp\\probe_walker_tick_trace.txt"
local f = io.open(OUT_PATH, "w")
local function w(s)
    print(s)
    if f then f:write(s .. "\n") end
end

-- 1) Idle to settle title.
for _ = 1, 180 do emu.frameadvance() end

-- 2) A+B+C chord enters roomrom_debug_enter (force_spawn slot 1).
local chord = {["P1 A"] = true, ["P1 B"] = true, ["P1 C"] = true}
for _ = 1, 30 do
    joypad.set(chord)
    emu.frameadvance()
end

-- 3) Let boot path complete.
for _ = 1, 60 do emu.frameadvance() end

w(string.rep("=", 60))
w("WALKER TICK TRACE -- $FF7F00 live block")
w(string.rep("-", 60))

-- 4) Confirm INIT probe still passing (sanity).
local init_e = read_u8(PROBE_BASE, 0)
local init_l = read_u8(PROBE_BASE, 1)
w(string.format("init probe magic = '%c%c' (expect 'EL')", init_e, init_l))

-- step 8 multi-slot reader. probe_idx 0..4 = slots 1..5 (step 11: +darknut).
local function multi_slot(probe_idx)
    local off = probe_idx * 8
    return {
        alive    = read_u8(MULTI_BASE, off + 0),
        type_    = read_u8(MULTI_BASE, off + 1),
        x        = read_u8(MULTI_BASE, off + 2),
        y        = read_u8(MULTI_BASE, off + 3),
        dir      = read_u8(MULTI_BASE, off + 4),
        anim_t   = read_u8(MULTI_BASE, off + 5),
        draw_f   = read_u8(MULTI_BASE, off + 6),
        walk_spd = read_u8(MULTI_BASE, off + 7),
    }
end

-- 5) Sample 13 snapshots over 120 frames (every 10 frames).
local samples = {}
local multi_samples = {{}, {}, {}, {}, {}}  -- per-slot (1..5) sample lists
for i = 1, 13 do
    local s = snapshot()
    table.insert(samples, s)
    local pre_type = read_u8(PRE_BASE, 5)
    local pre_alive = read_u8(PRE_BASE, 4)
    local raw_350 = read_u8(PRE_BASE, 16)
    -- Direct read of $FF8350 from Lua (bypasses publisher entirely).
    -- Debug.md A4 = $FF8000 (per src/debug/a4_probe_asm.s); NES $0350
    -- maps to physical $FF8350 in the 68K RAM domain.
    local raw_350_lua = memory.read_u8(0x8350, "68K RAM")
    w(string.format(
        "[t+%3d] f=%5d alive=%d/%d type(pre/post/raw/lua)=$%02X/$%02X/$%02X/$%02X x=$%02X y=$%02X dir=$%02X anim=%2d draw=$%02X move=$%02X state=$%02X spd=$%02X link=($%02X,$%02X)",
        (i-1)*10, s.frame, pre_alive, s.alive,
        pre_type, s.type_, raw_350, raw_350_lua,
        s.x, s.y, s.dir,
        s.anim_t, s.draw_f, s.move_t, s.state_t, s.walk_spd,
        s.link_x, s.link_y))
    -- step 8 multi-slot capture (every 10 frames same as slot 1)
    for slot_idx = 1, 5 do
        table.insert(multi_samples[slot_idx], multi_slot(slot_idx - 1))
    end
    if i < 13 then
        for _ = 1, 10 do emu.frameadvance() end
    end
end

-- step 8/11 multi-slot trace dump
w(string.rep("-", 60))
w("STEP 8/11 MULTI-SLOT TRACE -- $FF7F80 (slots 1-5)")
w("slot 1=octorock $07, 2=moblin $03, 3=goriya $05, 4=stalfos $2A, 5=darknut $0B")
for slot_idx = 1, 5 do
    local first = multi_samples[slot_idx][1]
    local last  = multi_samples[slot_idx][#multi_samples[slot_idx]]
    w(string.format(
        "  slot %d type=$%02X alive %d->%d xy=(%d,%d)->(%d,%d) dir=$%02X->$%02X anim=%d->%d draw=$%02X->$%02X spd=$%02X->$%02X",
        slot_idx, first.type_, first.alive, last.alive,
        first.x, first.y, last.x, last.y,
        first.dir, last.dir,
        first.anim_t, last.anim_t,
        first.draw_f, last.draw_f,
        first.walk_spd, last.walk_spd))
end

w(string.rep("-", 60))

-- 6) Gate evaluation.
local first = samples[1]
local last  = samples[#samples]
local pass = true
local function gate(ok, name)
    w(string.format("  %s  %s", ok and "PASS" or "FAIL", name))
    if not ok then pass = false end
end

gate(first.magic_t == 0x54 and first.magic_k == 0x4B,
     "G1 magic 'TK' (publisher fired)")
gate(last.frame > first.frame,
     string.format("G2 frame_counter advanced (%d -> %d)",
                   first.frame, last.frame))

local alive_held = true
local type_held  = true
for _, s in ipairs(samples) do
    if s.alive ~= 1 then alive_held = false end
    if s.type_ ~= 0x07 then type_held = false end
end
gate(alive_held, "G3 ENEMY_ALIVE_FLAG(1) stays 1 across trace")
gate(type_held,  "G4 ENEMY_TYPE(1) stays $07 across trace")

-- G5: anim_timer or draw_frame must change at least once across samples.
-- Both are written by sprite_anim_advance_and_fetch chain inside
-- enrt_update_rope. If neither moves, the UPDATE chain is dead.
local anim_changed = false
local draw_changed = false
for i = 2, #samples do
    if samples[i].anim_t ~= samples[i-1].anim_t then anim_changed = true end
    if samples[i].draw_f ~= samples[i-1].draw_f then draw_changed = true end
end
gate(anim_changed or draw_changed,
     string.format("G5 anim_timer OR draw_frame advanced (anim_changed=%s draw_changed=%s)",
                   tostring(anim_changed), tostring(draw_changed)))

-- G6 (step 5 add): X or Y must change. With c_walker_move drained
-- (composes object_bound_by_room + object_move_object), walking
-- speed $20 = 1 pixel every 8 frames. Over 120 frames octorok at
-- DIR=$02 (left) starting at X=$80 should land near X=$80 - 15.
local x_changed = false
local y_changed = false
for i = 2, #samples do
    if samples[i].x ~= samples[i-1].x then x_changed = true end
    if samples[i].y ~= samples[i-1].y then y_changed = true end
end
gate(x_changed or y_changed,
     string.format("G6 X OR Y advanced (x_changed=%s y_changed=%s; first=%d,%d last=%d,%d)",
                   tostring(x_changed), tostring(y_changed),
                   first.x, first.y, last.x, last.y))

-- step 8 gates: G7-G10 verify each step-7 wired slot stays alive +
-- preserves type across the trace window. Build crash would have
-- failed link; this checks runtime crash (slot type cleared, alive
-- flag dropped, etc).
local function multi_gate(slot_idx, expected_type, gate_name)
    local sl = multi_samples[slot_idx]
    local alive_held = true
    local type_held = true
    for _, ms in ipairs(sl) do
        if ms.alive ~= 1 then alive_held = false end
        if ms.type_ ~= expected_type then type_held = false end
    end
    gate(alive_held and type_held,
         string.format("%s slot %d type=$%02X alive+type held",
                       gate_name, slot_idx, expected_type))
end
multi_gate(2, 0x03, "G7")  -- moblin
multi_gate(3, 0x05, "G8")  -- goriya
multi_gate(4, 0x2A, "G9")  -- stalfos

-- G10: at least one of slots 2/3/4 advanced anim_timer or draw_frame
-- (proves the dispatch chain ran the body, not just init). Moblin
-- expected NOT to advance (bare drain, no anim/draw); goriya/stalfos
-- expected to advance.
local any_extra_advanced = false
for slot_idx = 2, 4 do
    local sl = multi_samples[slot_idx]
    for i = 2, #sl do
        if sl[i].anim_t ~= sl[i-1].anim_t then any_extra_advanced = true end
        if sl[i].draw_f ~= sl[i-1].draw_f then any_extra_advanced = true end
    end
end
gate(any_extra_advanced,
     "G10 at least one of slots 2/3/4 advanced anim/draw (goriya or stalfos ticking)")

-- step 11 darknut gates: G11 alive+type held, G12 darknut moved (X or Y).
multi_gate(5, 0x0B, "G11")  -- BlueDarknut alive + type held

local darknut_moved = false
do
    local sl = multi_samples[5]
    for i = 2, #sl do
        if sl[i].x ~= sl[i-1].x then darknut_moved = true end
        if sl[i].y ~= sl[i-1].y then darknut_moved = true end
    end
end
gate(darknut_moved,
     string.format("G12 darknut (slot 5) X or Y advanced over trace; first=(%d,%d) last=(%d,%d)",
                   multi_samples[5][1].x, multi_samples[5][1].y,
                   multi_samples[5][#multi_samples[5]].x,
                   multi_samples[5][#multi_samples[5]].y))

w(string.rep("-", 60))
w(pass and ">>> WALKER TICK TRACE: PASS <<<"
        or ">>> WALKER TICK TRACE: FAIL <<<")
w(string.rep("=", 60))

local shot = "C:\\tmp\\probe_walker_tick_trace.png"
client.screenshot(shot)
print("Screenshot: " .. shot)

if f then f:close() end
