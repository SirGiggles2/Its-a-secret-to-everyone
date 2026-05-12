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
local SHOT_BASE = 0x7FA8     -- $FF7FA8 step-14 shot scan block
local CV_BASE   = 0x7FCC     -- $FF7FCC step-17 collision-viz block
local DM_BASE   = 0x7FD8     -- $FF7FD8 step-19 damage-viz block
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

local function read_u32_be(base, off)
    local b0 = memory.read_u8(base + off,     DOMAIN)
    local b1 = memory.read_u8(base + off + 1, DOMAIN)
    local b2 = memory.read_u8(base + off + 2, DOMAIN)
    local b3 = memory.read_u8(base + off + 3, DOMAIN)
    return (b0 * 0x1000000) + (b1 * 0x10000) + (b2 * 0x100) + b3
end

-- step 17 collision-viz reader. counter > 0 + monotonic growth across
-- the trace window proves c_check_monster_collisions runs per slot per
-- tick (movement+collision walker checklist item).
local function coll_viz()
    return {
        magic_c = read_u8(CV_BASE, 0),
        magic_v = read_u8(CV_BASE, 1),
        mc      = read_u32_be(CV_BASE, 2),
        lc      = read_u32_be(CV_BASE, 6),
    }
end

-- step 19 damage-viz reader. probe seeds slot 13 sword + MON_HP(1)=$08;
-- with sword level 1 dmg=$10, the first damage tick drops HP < dmg ->
-- combat_handle_monster_died fires. Gates check HP drop, kill count
-- bump, metastate=16, type clear (drop spawn).
local function dmg_viz()
    return {
        magic_d        = read_u8(DM_BASE, 0),
        magic_m        = read_u8(DM_BASE, 1),
        hp_seed        = read_u8(DM_BASE, 2),
        hp_live        = read_u8(DM_BASE, 3),
        hit_reaction   = read_u8(DM_BASE, 4),
        shove_dir      = read_u8(DM_BASE, 5),
        shove_timer    = read_u8(DM_BASE, 6),
        metastate      = read_u8(DM_BASE, 7),
        mon_type       = read_u8(DM_BASE, 8),
        death_frame    = read_u8(DM_BASE, 9),
        kill_count     = read_u8(DM_BASE, 10),
        sword_state    = read_u8(DM_BASE, 11),
        harm_flag      = read_u8(DM_BASE, 12),
        room_kill_total = read_u8(DM_BASE, 13),  -- step 20: NES RoomKillCount $034F
    }
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

-- 2) Arm the heavy enemy-loop stress probe, then A+B+C enters
-- roomrom_debug_enter (force_spawn slot 1).
memory.write_u8(0x73F8, 0x52, "68K RAM") -- 'R'
memory.write_u8(0x73F9, 0x50, "68K RAM") -- 'P'
memory.write_u8(0x73FA, 0x03, "68K RAM") -- heavy mirror + enemy stress
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

-- step 14 shot-scan reader.
local function shot_scan()
    local b = {
        magic_s   = read_u8(SHOT_BASE, 0),
        magic_h   = read_u8(SHOT_BASE, 1),
        active    = read_u8(SHOT_BASE, 2),
        found     = read_u8(SHOT_BASE, 3),
        entries   = {},
    }
    for i = 0, 7 do
        local e = {
            slot = read_u8(SHOT_BASE, 4 + i*4 + 0),
            type_= read_u8(SHOT_BASE, 4 + i*4 + 1),
            x    = read_u8(SHOT_BASE, 4 + i*4 + 2),
            y    = read_u8(SHOT_BASE, 4 + i*4 + 3),
        }
        table.insert(b.entries, e)
    end
    return b
end

-- 5) Sample 31 snapshots over 600 frames (step 14: longer to give
-- octorok a window to actually shoot via c_shoot_if_wanted).
local samples = {}
local multi_samples = {{}, {}, {}, {}, {}}  -- per-slot (1..5) sample lists
local shot_samples = {}                      -- step 14
local shot_max_active = 0                    -- step 14 peak ActiveMonsterShots
local shot_max_found  = 0                    -- step 14 peak shot slot count
local shot_first_seen = nil                  -- step 14 first sample with found > 0
local cv_samples = {}                        -- step 17 collision-viz samples
local dm_samples = {}                        -- step 19 damage-viz samples
for i = 1, 31 do
    local s = snapshot()
    table.insert(samples, s)
    -- step 14 shot capture every iteration
    local sh = shot_scan()
    table.insert(shot_samples, sh)
    -- step 17 collision-viz capture
    table.insert(cv_samples, coll_viz())
    -- step 19 damage-viz capture
    table.insert(dm_samples, dmg_viz())
    if sh.active > shot_max_active then shot_max_active = sh.active end
    if sh.found  > shot_max_found  then shot_max_found  = sh.found  end
    if shot_first_seen == nil and sh.found > 0 then shot_first_seen = i end
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
    if i < 31 then
        for _ = 1, 20 do emu.frameadvance() end
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

-- step 14 shot-scan diagnostic dump (NOT a PASS gate — observation only).
-- If shot_max_active > 0 OR shot_max_found > 0, the shot UPDATE rows
-- ($53/$57 etc) are firing live. If both 0, octorok never reached
-- ObjWantsToShoot=1 in this trace window. Either way: data, not failure.
do
    local first_shot = shot_samples[1]
    local last_shot  = shot_samples[#shot_samples]
    w("STEP 14 SHOT SCAN -- $FF7FA8 (ActiveMonsterShots + slots 1..15 typed $53..$5C)")
    w(string.format("  magic 'SH' = '%c%c'", first_shot.magic_s, first_shot.magic_h))
    w(string.format("  ActiveMonsterShots first=%d last=%d peak=%d",
                    first_shot.active, last_shot.active, shot_max_active))
    w(string.format("  shot slots found first=%d last=%d peak=%d",
                    first_shot.found, last_shot.found, shot_max_found))
    if shot_first_seen ~= nil then
        w(string.format("  first shot observed at sample idx=%d (~frame %d)",
                        shot_first_seen, (shot_first_seen-1)*20))
        for _, e in ipairs(shot_samples[shot_first_seen].entries) do
            if e.type_ ~= 0 then
                w(string.format("    slot %2d type=$%02X xy=(%3d,%3d)",
                                e.slot, e.type_, e.x, e.y))
            end
        end
    else
        w("  no shot slots observed across trace window (octorok never shot)")
    end
end

w(string.rep("-", 60))

-- step 17 collision-viz diagnostic dump.
do
    local first_cv = cv_samples[1]
    local last_cv  = cv_samples[#cv_samples]
    w("STEP 17 COLLISION-VIZ -- $FF7FCC (c_check_*_calls counters)")
    w(string.format("  magic 'CV' = '%c%c'", first_cv.magic_c, first_cv.magic_v))
    w(string.format("  monster_collisions_calls first=%d last=%d delta=%d",
                    first_cv.mc, last_cv.mc, last_cv.mc - first_cv.mc))
    w(string.format("  link_collision_calls    first=%d last=%d delta=%d",
                    first_cv.lc, last_cv.lc, last_cv.lc - first_cv.lc))
end

w(string.rep("-", 60))

-- step 19 damage-viz diagnostic dump.
do
    local first_dm = dm_samples[1]
    local last_dm  = dm_samples[#dm_samples]
    w("STEP 19 DAMAGE-VIZ -- $FF7FD8 (slot 1 octorok damage cells)")
    w(string.format("  magic 'DM' = '%c%c'", first_dm.magic_d, first_dm.magic_m))
    w(string.format("  hp_seed=$%02X first=$%02X last=$%02X",
                    first_dm.hp_seed, first_dm.hp_live, last_dm.hp_live))
    w(string.format("  hit_reaction first=$%02X last=$%02X",
                    first_dm.hit_reaction, last_dm.hit_reaction))
    w(string.format("  shove_dir/timer first=($%02X,$%02X) last=($%02X,$%02X)",
                    first_dm.shove_dir, first_dm.shove_timer,
                    last_dm.shove_dir, last_dm.shove_timer))
    w(string.format("  metastate first=$%02X last=$%02X (16=death)",
                    first_dm.metastate, last_dm.metastate))
    w(string.format("  mon_type first=$%02X last=$%02X (0x60=drop)",
                    first_dm.mon_type, last_dm.mon_type))
    w(string.format("  death_frame first=$%02X last=$%02X (32=set on death)",
                    first_dm.death_frame, last_dm.death_frame))
    w(string.format("  kill_count first=%d last=%d",
                    first_dm.kill_count, last_dm.kill_count))
    w(string.format("  sword_state(13) first=$%02X last=$%02X (expect $02)",
                    first_dm.sword_state, last_dm.sword_state))
    w(string.format("  harm_flag first=$%02X last=$%02X",
                    first_dm.harm_flag, last_dm.harm_flag))
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
    -- step 20: slot 1 is sword-killed on frame 1 by the damage probe
    -- seed and converted to dropped-item type $60 by update_meta_object.
    -- Accept either octorok ($07) or dropped item ($60).
    if s.type_ ~= 0x07 and s.type_ ~= 0x60 then type_held = false end
end
gate(alive_held, "G3 ENEMY_ALIVE_FLAG(1) stays 1 across trace")
gate(type_held,  "G4 ENEMY_TYPE(1) stays $07 or $60 (drop conv) across trace")

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

-- G6 (step 5 add, step 20 relaxed): X or Y must change. Slot 1
-- octorok is sword-killed on frame 1 by the damage probe seed and
-- converted to dropped-item $60 — it never moves under its own power.
-- Use slot 2 moblin instead (not sword-seeded). G12 already covers
-- darknut motion; this gate now covers walker dispatch on a non-killed
-- slot.
local s2 = multi_samples[2]  -- slot 2 moblin
local m_first = s2[1]
local m_last  = s2[#s2]
gate(m_first.x ~= m_last.x or m_first.y ~= m_last.y,
     string.format("G6 slot 2 moblin X or Y advanced (first=%d,%d last=%d,%d)",
                   m_first.x, m_first.y, m_last.x, m_last.y))

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

-- step 17 G13/G14: collision-viz counters monotonically grow. Proves
-- c_check_monster_collisions runs every tick across multi-slot probe.
local first_cv = cv_samples[1]
local last_cv  = cv_samples[#cv_samples]
gate(last_cv.magic_c == 0x43 and last_cv.magic_v == 0x56,
     "G13 collision-viz magic 'CV' present (publisher fired)")
gate(last_cv.mc > first_cv.mc,
     string.format("G14 monster_collisions_calls grew across trace (%d -> %d)",
                   first_cv.mc, last_cv.mc))

-- step 19 damage gates. Probe seeded MON_HP(1)=$08 + sword slot 13
-- OBJ_STATE=2 at coincident coords. Sword level 1 dmg=$10. First hit
-- routes through combat_handle_monster_died: HP unchanged in died path
-- (NES asm doesn't decrement when hp<dmg), but ROOM_KILL_COUNT++,
-- MON_METASTATE=16, DEATH_FRAME_COUNTER=32. Drop conversion needs
-- death-anim metastate advance to $14 — observable as MON_TYPE=$60.
local first_dm = dm_samples[1]
local last_dm  = dm_samples[#dm_samples]
gate(last_dm.magic_d == 0x44 and last_dm.magic_m == 0x4D,
     "G15 damage-viz magic 'DM' present (publisher fired)")
gate(last_dm.kill_count > 0,
     string.format("G16 ROOM_KILL_COUNT bumped (death observed) %d -> %d",
                   first_dm.kill_count, last_dm.kill_count))
gate(last_dm.metastate == 16 or last_dm.mon_type == 0x60,
     string.format("G17 death/drop state set (metastate=$%02X mon_type=$%02X)",
                   last_dm.metastate, last_dm.mon_type))

-- step 20 drop conversion. update_meta_object dispatched via enemy_loop
-- metastate gate. After 20 ticks (4 * 5 metastate frames) MON_TYPE
-- transitions $07 -> $60 and MON_METASTATE resets to $00. ENEMY_ALIVE
-- stays 1 so iterator keeps polling the slot.
gate(last_dm.mon_type == 0x60,
     string.format("G18 drop conversion fired (mon_type $07 -> $%02X expect $60)",
                   last_dm.mon_type))
gate(last_dm.metastate == 0,
     string.format("G19 metastate reset post-drop (last=$%02X expect $00)",
                   last_dm.metastate))
-- step 20 G20: NES UpdateMetaObjectEnd (Z_07.asm:5453) bumps RoomKillCount
-- ($034F = ROOM_OW_CUR_KILL_TOTAL), distinct from WorldKillCount ($0627 =
-- ROOM_KILL_COUNT). Drop conversion path must INC the per-room counter.
gate(last_dm.room_kill_total > 0,
     string.format("G20 RoomKillCount ($034F) bumped via UpdateMetaObjectEnd %d -> %d",
                   first_dm.room_kill_total, last_dm.room_kill_total))

w(string.rep("-", 60))
w(pass and ">>> WALKER TICK TRACE: PASS <<<"
        or ">>> WALKER TICK TRACE: FAIL <<<")
w(string.rep("=", 60))

local shot = "C:\\tmp\\probe_walker_tick_trace.png"
client.screenshot(shot)
print("Screenshot: " .. shot)

if f then f:close() end
