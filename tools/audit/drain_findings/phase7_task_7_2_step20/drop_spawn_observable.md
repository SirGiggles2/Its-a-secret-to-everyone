# Phase 7 Task 7.2 step 20 — drop spawn observable end-to-end

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:5403 UpdateMetaObject`
                  + `:4977 AnimateAndDrawMetaObject`
                  + `:5414 UpdateMetaObjectEnd`
                  + `:1604 IsrNmi @LoopTimer` (DecTimers).
- **Drained C**:  `src/game/enemies/enemy_walker_bridge.c::update_meta_object`
                  (NEW, this step). DecTimers prepass added inline to
                  `src/game/enemies/enemy_loop.c::enemy_loop_tick`.
                  Metastate dispatch gate added to enemy_loop_tick body
                  (NEW, this step). Probe block extended at $FF7FD8 byte 13
                  with `ROOM_OW_CUR_KILL_TOTAL` ($034F). Lua reader gates
                  G18/G19/G20 added.
- **Coverage**:   FULL — every NES UpdateMetaObject / AnimateAndDrawMetaObject /
                  UpdateMetaObjectEnd branch is reproduced. Skipped:
                  spark/cloud DRAW (OAM router pending) +
                  `SetUpDroppedItem` (drop-id table — separate item-subsystem
                  task; the drop conversion that gates it is verified).
- **Stance**:     ADOPT. No prior drain candidate for UpdateMetaObject in
                  `src/oracle/`. NES ASM is the only authority — transcribed
                  verbatim with two scoped stubs.

## Drain shape

NES UpdateObject (`Z_07.asm:5237`) preamble runs FOR EVERY object every
frame and short-circuits to `UpdateMetaObject` whenever
`ObjMetastate != 0`:

```
LDA ObjMetastate, X
BEQ +
JMP UpdateMetaObject
+
; ... regular per-type body ...
```

Step 20 wires the same gate into our C dispatcher
`enemy_loop_tick`: pre-dispatch we check `ENEMY_METASTATE(slot)` and
divert to `update_meta_object(slot)` BEFORE `enemy_update_fns[type](slot)`.

`update_meta_object` body:

```
ms = ENEMY_METASTATE(slot)

if ms >= $10:                  ; spark path (death)
    nibble = ms & $0F
    if nibble == 0:            ; @AnimateSpark BEQ @IncMetastate
        ENEMY_MOVE_TIMER = 6   ; immediate INC, no draw, no timer gate
        ENEMY_METASTATE  = ms+1
    else:                       ; nibble != 0 — draw + timer gate
        if ENEMY_MOVE_TIMER == 0:
            ENEMY_MOVE_TIMER = 6
            ENEMY_METASTATE  = ms+1
else:                          ; cloud path (spawn)
    if ENEMY_MOVE_TIMER == 0:
        ENEMY_MOVE_TIMER = 6
        ENEMY_METASTATE  = ms+1

; UpdateMetaObject post-call check (Z_07.asm:5407)
if (ms & $0F) < $04: return    ; mid-anim — keep ticking next frame

; UpdateMetaObjectEnd (Z_07.asm:5414)
if (ms & $10) == 0:            ; cloud-end (metastate $04)
    ENEMY_METASTATE = 0        ; reset, walker resumes regular UPDATE
    return

; metastate $14 — death-spark complete: convert to dropped item
META_ITEM_MONSTER_TYPE(slot) = ENEMY_TYPE(slot)
if obj_type not in ($5D, $14, $1C):
    META_WORLD_KILL_CYCLE = (META_WORLD_KILL_CYCLE + 1) % 10
    if obj_type != $11:                               ; skip Zora
        ROOM_OW_CUR_KILL_TOTAL++                       ; NES RoomKillCount $034F
ENEMY_TYPE(slot)        = $60                        ; dropped-item type
ENEMY_ALIVE_FLAG(slot)  = 1                          ; ObjUninitialized=1
META_OBJ_ATTR(slot)     = $81                        ; custom collide+draw
; TODO native_set_up_dropped_item(slot)              ; deferred
ENEMY_METASTATE(slot)   = 0                          ; @Reset
```

## DecTimers prepass

NES `IsrNmi @LoopTimer` (Z_07.asm:1604-1616) decrements `ObjTimer`
($0028..) for every slot every VBlank. The walker direction-decision
logic (`enemy_walker_runtime.c:107` — `if MOVE_TIMER == 0`) and
`update_meta_object` spark/cloud progression both gate on
`ObjTimer == 0`. Without the dec, `ObjTimer` set by InitObject /
clear_slot_scratch never reaches 0 → metastate frozen at $01 →
walker frozen.

Per-frame prepass added in `enemy_loop_tick`:

```c
for (slot = 1..0xB) {
    if (ENEMY_MOVE_TIMER(slot) != 0) ENEMY_MOVE_TIMER(slot)--;
    if (ENEMY_STUN_TIMER(slot) != 0) ENEMY_STUN_TIMER(slot)--;
}
```

This is the native-frame equivalent of NES VBlank-driven dec. Step 19
trace passed without it because (a) walker MOVEMENT is speed-driven
(c_walker_move ignores MOVE_TIMER for position) and (b) damage-path
gates only checked first-frame death values. Step 20 trace requires
the dec because the metastate-end logic is timer-gated.

## RoomKillCount vs WorldKillCount

NES distinguishes:

- `WorldKillCount` ($0627) — bumped by `HandleMonsterDied`
  (Z_01.asm:5952). Tracked across the whole world (OW or UW).
  Drained as `combat_handle_monster_died` in
  `combat_dispatch.c:30`. Cell macro `ROOM_KILL_COUNT` (misnamed;
  alias of `DUNGEON_WORLD_KILL_COUNT`).
- `RoomKillCount` ($034F) — bumped by `UpdateMetaObjectEnd`
  (Z_07.asm:5453) only on the drop-conversion path. Resets per room.
  Cell macro `ROOM_OW_CUR_KILL_TOTAL`.

Initial step 20 draft mistakenly bumped `ROOM_KILL_COUNT` ($0627) in
update_meta_object's drop path — would have produced a double-bump
(once from combat_handle_monster_died + once from
update_meta_object). NES auth wins ties → fixed to use
`ROOM_OW_CUR_KILL_TOTAL` ($034F). Probe block byte 13 published. G20
gate added. Trace shows kill_count=1, room_kill_total=1 (single
each, NES-correct).

## Verification — 20/20 PASS

```
WALKER TICK TRACE -- $FF7F00 live block
[t+  0..300] f= 19..296 alive=1/1 type(pre/post/raw/lua)=...

STEP 19 DAMAGE-VIZ -- $FF7FD8 (slot 1 octorok damage cells)
  metastate first=$01 last=$00 (16=death)
  mon_type first=$07 last=$60 (0x60=drop)
  kill_count first=0 last=1
  PASS  G1 magic 'TK' (publisher fired)
  PASS  G2 frame_counter advanced (19 -> 296)
  PASS  G3 ENEMY_ALIVE_FLAG(1) stays 1 across trace
  PASS  G4 ENEMY_TYPE(1) stays $07 or $60 (drop conv) across trace
  PASS  G5 anim_timer OR draw_frame advanced
  PASS  G6 slot 2 moblin X or Y advanced (first=64,96 last=31,96)
  PASS  G7..G12 multi-slot walkers ticking
  PASS  G13..G14 collision counters growing
  PASS  G15 damage-viz magic
  PASS  G16 WorldKillCount bumped (0 -> 1) via combat_handle_monster_died
  PASS  G17 death/drop state set (metastate=$00 mon_type=$60)
  PASS  G18 drop conversion fired (mon_type $07 -> $60)
  PASS  G19 metastate reset post-drop (last=$00)
  PASS  G20 RoomKillCount ($034F) bumped via UpdateMetaObjectEnd 0 -> 1
>>> WALKER TICK TRACE: PASS <<<
```

## What this proves / does not prove

PROVES:

- Walker checklist line "probe damage+death+drop" — all 3 of 3 now
  visible end-to-end as instrumentation evidence.
- Metastate dispatch gate diverts dying/spawning slots to
  update_meta_object before per-type UPDATE — NES-faithful preamble.
- DecTimers prepass restores VBlank-driven ObjTimer cadence; walker
  direction-decision + metastate animation both unblock.
- UpdateMetaObject 6-frame-per-metastate-frame timer cycle (cloud
  $01->$02->$03->$04 + reset; spark $10->$11->$12->$13->$14 + drop
  conv) executes against real RAM cells.
- Drop conversion: ENEMY_TYPE $07->$60, ENEMY_ALIVE_FLAG=1,
  META_OBJ_ATTR=$81, META_ITEM_MONSTER_TYPE=$07,
  META_WORLD_KILL_CYCLE=1, ROOM_OW_CUR_KILL_TOTAL=1, METASTATE=0.
- WorldKillCount ($0627) and RoomKillCount ($034F) bumps are
  routed to the correct cells (1 each, not double-bumped).

DOES NOT PROVE:

- Drop SPRITE rendering. The $60 dropped-item type still needs an
  enemy_init_fns[$60] / enemy_update_fns[$60] row to draw the actual
  rupee/heart/bomb sprite. Currently $60 is dispatched through the
  enemy_loop iterator but no fn is wired so it just sits at the
  death position.
- `SetUpDroppedItem` (Z_04.asm:11103). The drop-item ID table lookup
  + fairy-on-$10-kills + help-drop randomization is deferred to a
  follow-up task in the item subsystem. The conversion that gates
  it (metastate $14 → $60 type) is verified.
- Cloud animation drawing. The $01..$04 metastate cloud frames cycle
  correctly per timer but the DRAW call is stubbed (OAM router not
  wired for spawning-cloud sprites). NES would draw a 4-frame
  spawning-cloud at the slot position during this window.
- Multi-frame death-spark drawing. Same as cloud — cycle works,
  draw stubbed.

## Master plan checklist progress

After step 20 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook
- [x] probe movement+collision (step 17 closed)
- [x] probe damage+death+drop (step 20 closes the final 3rd line —
                                MON_TYPE $07->$60 + RoomKillCount
                                bump on drop conv path verified)
- [ ] commit family       (final phase commit — next step after this)

## Rolled-forward TODOs

- enemy_init_fns[$60] / enemy_update_fns[$60] for dropped-item
  sprite render + Link pickup. Step 21 candidate.
- Native `SetUpDroppedItem` (Z_04.asm:11103) drop-id table + fairy
  + help-drop logic. Item-subsystem task.
- OAM router (task #7) — required for spawning-cloud and
  death-spark sprite render to be visible.
- Drain `UpdateArrowOrBoomerang` ($5B/$5C bodies). Step 15. Multi-hour.
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring.
- Room init that writes `$034A` (ObjectFirstUnwalkableTile) — last
  prereq before c_walker_check_tile_collision body activates.
