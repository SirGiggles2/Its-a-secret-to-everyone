# Phase 7 Task 7.2 step 14 — shot-scan probe extension

## Task header (Drain Rule D1)

- **NES source**: NES RAM `ActiveMonsterShots` ($034C) +
                  `ENEMY_TYPE` cells $03A0..$03AE (slots 1..15) per
                  `reference/aldonunez/Z_04.asm` UpdateMonsterShot
                  contract ($53..$5C type range).
- **Drained C**:  `src/game/enemies/probes/enemy_loop_probe.c`
                  `publish_shot_scan` + header
                  `src/game/enemies/probes/enemy_loop_probe.h`
                  `ENEMY_LOOP_SHOT_SCAN_BASE = 0x00FF7FA8`.
                  Lua reader in
                  `tools/debug/probes/probe_walker_tick_trace.lua`.
- **Coverage**:   N/A (probe extension — no NES body drained).
- **Stance**:     EXTEND existing $FF7E00 / $FF7F00 / $FF7F40 /
                  $FF7F80 probe family. New $FF7FA8 block = 36 bytes
                  ('SH' magic + ActiveMonsterShots + scan_count + 8
                  entries × 4 bytes).

## Drain shape

`publish_shot_scan` runs every tick from `enemy_loop_probe_publish_live`.
Loops slot 1..15, samples `ENEMY_TYPE(slot)`, records first 8 hits
where type ∈ $53..$5C. Publishes `(slot, type, x, y)` quads at
$FF7FA8+4..$FF7FCB. ActiveMonsterShots ($034C) at $FF7FAA so we can
correlate "NES counter says N shots" vs "scan sees M typed slots" —
divergence would mean either (a) a type-$53..$5C row owns a slot
without bumping the counter, or (b) the counter advanced without the
slot getting a recognised type stamp (likely UPDATE row clearing).

Lua reader lives in the existing single-file probe; sample loop
extended from 13×10 frames (130) to 31×20 frames (600) so the
octorok has a full ObjWantsToShoot cycle to fire.

## Verification — 12/12 PASS unchanged

Existing walker-tick gates G1..G12 still PASS. Step-14 block is
*informational* — no new PASS gate to avoid coupling probe to a
behavior we have not yet drained natively.

```
ActiveMonsterShots first=0 last=3 peak=3
shot slots found first=0 last=3 peak=3
first shot observed at sample idx=3 (~frame 40)
  slot 10 type=$5B xy=( 64, 96)
```

Reading:

- ActiveMonsterShots and shot_count both peak at 3 within 600 frames
  — counter and slot-scan agree, no divergence.
- $5B = `MonsterArrow`. Slot 10 was empty at boot; the dispatch shell
  wrote $5B there during the run, which means a non-walker UPDATE row
  (or an init via spawn shim) is firing. This is what step 13 owed
  the rolled-forward TODO list "extension: sample dynamically-spawned
  shot slots".
- Position (64,96) matches slot 2 moblin's seeded position — the
  shot inherited from a parent monster rather than the seeded
  octorock at slot 1. So the spawn lane is moblin → arrow ($5B).
  Confirms the projectile-spawn glue is reaching live cells.
- First sighting at sample idx=3 (~frame 40 after the 270-frame
  boot wait) ≈ 6 frames after the multi-slot probe wakes the moblin.

## What this proves / does not prove

PROVES:
- Step-12 UPDATE-row dispatch table has live consumers — at least
  one $5B row exists in a real slot during normal tick.
- Step-13 native `draw_arrow` body now has actual data to draw — a
  real $5B slot at known X/Y means the next tick of `c_draw_arrow`
  fires against real OBJ_X/OBJ_Y, not a no-op zero slot.
- Probe MMIO blocks at $FF7E00 / $FF7F00 / $FF7F40 / $FF7F80 /
  $FF7FA8 do not collide.

DOES NOT PROVE:
- That the OAM bytes from `draw_arrow` reach Genesis SAT — still
  blocked on rolled-forward TODO `oam_router (task #7)` (NES OAM
  $0200..$02FF → Genesis SAT slots 10+).
- That `UpdateMonsterArrow` ($5B body) is correct — that body is a
  NULL row in `enemy_update_fns[]` until step 15 drains
  `UpdateRodOrArrow` / `UpdateArrowOrBoomerang` (Z_07.asm:3813 /
  4322). Right now $5B slots only get *drawn*, not *moved*; the
  moblin just stamped the type cell and let the position sit.

## Master plan checklist progress

After step 14 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook (UPDATE rows + draw helpers both native, live
                       consumer confirmed via $5B at slot 10)
- [ ] probe movement+collision  (movement done; collision via
                                 c_check_monster_collisions exists,
                                 needs probe extension for visible
                                 outcome)
- [ ] probe damage+death+drop   (combat hook not wired)
- [ ] commit family             (final phase commit)

## Rolled-forward TODOs

- Drain `UpdateRodOrArrow` / `UpdateArrowOrBoomerang` ($5B/$5C
  bodies) — Z_07.asm:3813 / 4322. Pulls in MoveShot,
  BoomerangFrameCycle, GetDirectionsAndDistancesToTarget,
  SetBoomerangSpeed, DestroyCountedMonsterShot, CheckLinkCollision,
  InvMagicBoomerang. Multi-hour drain, deferred to step 15.
- OAM→SAT router (task #7): NES `nes_ram[$0200..$02FF]` → Genesis
  SAT slots 10+; needed before any drained sprite is *visible* in
  emulator output.
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- `c_obj_shove` native (combat damage hook) — still stubbed.
- Walker_CheckTileCollision (room tile registry).
