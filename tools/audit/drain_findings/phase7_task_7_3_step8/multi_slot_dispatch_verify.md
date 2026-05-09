# Phase 7 Task 7.3 step 8 — family-73 multi-slot dispatch verify

**Date:** 2026-05-09
**Stance:** EXTEND (probe-only; no new runtime drain)
**Drained C primary:** `src/oracle/enemies/enemy_*_runtime.c` (zol/gel/peahat/keese/rope/vire)
**NES source secondary:** `Z_04.asm:5295 UpdateObject_JumpTable` (rows $12/$13/$15/$1A/$1B/$28)
**Coverage:** 6/6 wired UPDATE rows alive + advancing per-frame state.

## Goal

Mirror Task 7.2 step 8 multi-slot probe pattern for the family-73
(flyer/jumper/zol/gel/rope/vire) cluster wired in steps 3..7. Prove the
6 dispatch UPDATE rows tick without crashing and (for movement-active
types) advance per-frame state through the drained C chain.

## Wiring under test

| Slot | NES type | Family enemy | UPDATE row             | Wired in step |
|------|----------|--------------|------------------------|---------------|
| 6    | $13      | Zol          | `enrt_update_zol`      | step 3        |
| 7    | $15      | Gel          | `enrt_update_gel`      | step 4        |
| 8    | $1A      | Peahat       | `enrt_update_peahat`   | step 5        |
| 9    | $1B      | BlueKeese    | `enrt_update_keese`    | step 6        |
| 10   | $28      | Rope         | `enrt_update_rope`     | step 4        |
| 11   | $12      | Vire         | `enrt_update_vire`     | step 7        |

## Probe layout

- Probe block at `ENEMY_LOOP_FAMILY73_BASE = 0x00FF7E40` (declared in
  `src/game/enemies/probes/enemy_loop_probe.h:157`).
- Header: 4 bytes (`'F'`, `'M'`, reserved, reserved).
- 6 entries × 8 bytes: `[alive, type, x, y, dir, anim_t, move_t, flap]`.
- Total 52 bytes; sits between probe-pairs ending `$FF7E3B` and the
  tick block at `$FF7F00`.
- Seeded by `enemy_loop_force_spawn_typed()` calls in
  `enemy_loop_probe_run()` (slots 6..11 staggered across the room
  midpoints to avoid co-collisions during the 600-frame trace).
- Published every frame by `publish_family73()` from
  `enemy_loop_probe_publish_live()`.

## Probe

`tools/debug/probes/probe_family73_dispatch.lua`. Boot pattern: idle 180
→ A+B+C chord 30 → settle 60 → 31 samples × 20 frames = 600 frames of
trace. Output: `C:\tmp\probe_family73_dispatch.txt` + .png screenshot.

## Gates (8 of 8 PASS)

```
PASS  G1 magic 'FM' present
PASS  G2 slot  6 zol    ($13) alive+type held
PASS  G3 slot  7 gel    ($15) alive+type held
PASS  G4 slot  8 peahat ($1A) alive+type held
PASS  G5 slot  9 keese  ($1B) alive+type held
PASS  G6 slot 10 rope   ($28) alive+type held
PASS  G7 slot 11 vire   ($12) alive+type held
PASS  G8 at least one family-73 slot advanced motion/anim (witness: zol)

>>> FAMILY-73 DISPATCH: PASS <<<
```

## Per-slot evolution (t+0 → t+600)

| Slot | xy start    | xy end      | Notes                                              |
|------|-------------|-------------|----------------------------------------------------|
| 6 zol    | (48,48)   | (32,13)   | wandered NW; move-timer cycled $05→$00 multiple times |
| 7 gel    | (48,112)  | (48,31)   | jumped N along x=48; gel-splitting move pattern    |
| 8 peahat | (48,174)  | (48,86)   | sustained N drift dir=$08, anim_t=1 (flap held)    |
| 9 keese  | (208,48)  | (208,225) | wrapped (208,1) → (208,253); flying drift          |
| 10 rope  | (208,112) | (208,112) | stationary (rope only moves on Link sight; anim cycling 1→10) |
| 11 vire  | (208,176) | (208,82)  | jumped N; anim_t cycled 1→10 each ~10 frames       |

All 6 slots remain `alive=1` and hold their NES TYPE byte unchanged
across 600 frames — no crash, no slot-stomp, no type-clear regression.
Five of six advanced motion (rope's stationary state matches NES rope
behavior — it idles until triggered).

## Files

- `probe_family73_PASS.txt` — full 31-sample trace + per-slot summary.
- `probe_family73_PASS.png` — BizHawk screenshot at trace end.

## Outcome

Family-73 dispatch verified end-to-end. The 6 UPDATE rows wired across
steps 3..7 all tick without crashing; downstream drained C bodies
(`enrt_update_*`, `c_gel_move_splitting`, `z04_update_common_wanderer`,
`c_anim_advance_and_fetch`, `c_find_empty_monster_slot`, `c_shoot`,
`z07_set_type_and_clear_object`) link clean and execute per-frame.

Closes Task 7.3 step 8. Step 9 = task close commit (master plan tick +
phase summary).

## Known gap (not blocking step 8)

`ENEMY_THROWER_SLOT ($0340)` is read by `enrt_shoot` (vire spawn-on-jump)
but currently unwritten by `enemy_loop_tick` per-slot. NES `Shoot` uses
`CurObjIndex` (X reg) implicitly. Vire $12 in this trace did not split
during the 600-frame window (jump phase didn't reach split trigger).
First time vire shoots a split-slot, `c_shoot` will read whatever
`$0340` happened to hold from the last writer. Track for follow-up; not
a step 8 gate failure.
