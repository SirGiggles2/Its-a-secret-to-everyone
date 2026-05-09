# Phase 7 Task 7.2 step 17 — collision-viz counters

## Task header (Drain Rule D1)

- **NES source**: N/A (instrumentation, no NES body drained).
- **Drained C**:  `src/game/enemies/enemy_walker_bridge.c` —
                  globals `g_check_monster_collisions_calls`,
                  `g_check_link_collision_calls` + increment in the
                  `c_check_monster_collisions` /
                  `c_check_link_collision` wrappers.
                  `src/game/enemies/probes/enemy_loop_probe.c`
                  `publish_collision_viz()` + header
                  `ENEMY_LOOP_COLLISION_VIZ_BASE = 0x00FF7FCC`.
                  Lua reader in
                  `tools/debug/probes/probe_walker_tick_trace.lua`.
- **Coverage**:   N/A (probe extension).
- **Stance**:     EXTEND existing $FF7E00 / $FF7F00 / $FF7F40 /
                  $FF7F80 / $FF7FA8 probe family. New $FF7FCC block =
                  10 bytes ('CV' magic + mc u32 + lc u32). Block end
                  = $FF7FD5.

## Drain shape

`publish_collision_viz` runs every tick from
`enemy_loop_probe_publish_live`. Reads the two `volatile unsigned long`
counters incremented by the wrapper functions:

```
c_check_monster_collisions(slot)
  g_check_monster_collisions_calls++
  link_collision_check_monster_collisions(slot)

c_check_link_collision(slot)
  g_check_link_collision_calls++
  link_collision_check_link_collision(slot)
```

Counters are write-once-per-call inside the bridge, read-only outside.
The probe block format is `'C' 'V' mc_be_u32 lc_be_u32` so the lua
reader can dump growth + delta across the trace window.

## Verification — 14/14 PASS (G13/G14 added)

```
STEP 17 COLLISION-VIZ -- $FF7FCC (c_check_*_calls counters)
  magic 'CV' = 'CV'
  monster_collisions_calls first=38 last=592 delta=554
  link_collision_calls    first=0 last=0 delta=0
  ...
  PASS  G13 collision-viz magic 'CV' present (publisher fired)
  PASS  G14 monster_collisions_calls grew across trace (38 -> 592)
>>> WALKER TICK TRACE: PASS <<<
```

Reading:

- `g_check_monster_collisions_calls` grew 38 -> 592 across ~600 frames
  with 5 walker slots seeded. Average ~0.92 calls/frame. Below 5/frame
  because octorok rows alternate between move-frames (calls fire) and
  shoot-windup frames (`ENEMY_WALK_SPEED == 0` branch returns early
  per `enrt_update_octorock` step 4 inlined `_TryShooting`). The
  delta proves `c_check_monster_collisions` is not just compiled —
  it's the live consumer of `c_walker_move`'s drained chain on every
  active walker slot per tick.
- `g_check_link_collision_calls` stayed 0. Consistent with the
  Phase 7 Task 7.2 wiring: walker UPDATE rows do not call
  `c_check_link_collision` directly (only shot UPDATE rows would,
  via `enrt_update_monster_shot`). Link is parked at (0,0) off-screen
  by the probe's `LINK_X = LINK_Y = 0` post-init handoff so even the
  wired shot rows skip the actual collision body. Counter staying 0
  is therefore *expected*, not a regression.

## What this proves / does not prove

PROVES:

- The "probe movement+collision" walker checklist line — collision
  invocation is now visible as instrumentation evidence. Prior
  closure of this line was deferred because it had no visible
  outcome until combat is wired; the counter is the visible outcome.
- `c_check_monster_collisions` (drained `link_collision_dispatch.c`
  body) is reachable from every wired walker UPDATE row.
- `enemy_walker_bridge.c` wrappers + the probe block live cleanly
  alongside the existing $FF7F00 / $FF7F80 / $FF7FA8 publishers
  (no MMIO collision; trace 12+2 = 14/14 PASS).

DOES NOT PROVE:

- That `link_collision_check_monster_collisions` returns the *correct*
  collision result for any given slot — only that it executes.
  Per-slot correctness still gated on the room-tile registry +
  combat hook landing.
- That collision damage flows through to Link / death / drop. That
  needs the rolled-forward TODO `Walker_CheckTileCollision (room
  tile registry)` + `c_obj_shove combat damage hook` (the latter is
  ready as of step 16; the former still pending).

## Master plan checklist progress

After step 17 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook (UPDATE rows + draw helpers both native, live
                       $5B consumer captured)
- [x] probe movement+collision (G14 monster_collisions_calls
                                grew 38 -> 592 across trace; closes
                                the line)
- [ ] probe damage+death+drop  (combat damage hook still not wired
                                end-to-end; Obj_Shove native body
                                ready, Walker_CheckTileCollision
                                pending)
- [ ] commit family            (final phase commit)

## Rolled-forward TODOs

- Drain `UpdateRodOrArrow` / `UpdateArrowOrBoomerang` ($5B/$5C
  bodies) — Z_07.asm:3813 / 4322. Step 15. Multi-hour.
- OAM->SAT router (task #7).
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring.
- Walker_CheckTileCollision (room tile registry) — last gate before
  damage+death+drop becomes observable.
- Combat damage hook wiring (sword/projectile -> ShoveDir set ->
  Obj_Shove fires).
