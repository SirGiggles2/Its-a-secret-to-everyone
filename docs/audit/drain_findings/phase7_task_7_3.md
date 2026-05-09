# Phase 7 Task 7.3 — Flyer / Jumper Family

- **NES source**: `reference/aldonunez/Z_07.asm:5601 InitObject_JumpTable`
                  + `reference/aldonunez/Z_04.asm:5295 UpdateObject_JumpTable`
                  (entries $12 Vire / $13 Zol / $14 RedZol / $15 Gel /
                  $1A Peahat / $1B BlueKeese / $28 Rope) +
                  `Z_04.asm:3143 UpdatePeahat` + boss-runtime Vire chain.
- **Drained C**:  `src/oracle/enemies/enemy_walker_runtime.c`
                  + `enemy_flyer_runtime.c` + `enemy_common_runtime.c`
                  + `enemy_wanderer_runtime.c` + `enemy_boss_runtime.c`.
- **Coverage**:   FULL — 6/6 wired UPDATE rows ticking with drained or
                  natively-bridged primitives.
- **Stance**:     ADOPT (drains linked verbatim) + EXTEND (per-call
                  bridges in `src/game/enemies/enemy_*_bridge.c`).

## Wired dispatch

| Hex | NES type     | INIT row                              | UPDATE row              | Step |
|-----|--------------|---------------------------------------|-------------------------|------|
| $12 | Vire         | `enrt_init_walker`                    | `enrt_update_vire`      | 7    |
| $13 | Zol          | `enrt_init_walker`                    | `enrt_update_zol`       | 4    |
| $14 | RedZol       | `enrt_init_walker`                    | `enrt_update_gel` (NES alias) | 4 |
| $15 | Gel          | `enrt_init_gel`                       | `enrt_update_gel`       | 4    |
| $1A | Peahat       | `enrt_init_peahat`                    | `enrt_update_peahat`    | 6    |
| $1B | BlueKeese    | `enrt_init_blue_keese`                | `enrt_update_keese`     | 3    |
| $1C | RedKeese     | `enrt_init_red_or_black_keese`        | `enrt_update_keese`     | 3    |
| $1D | BlackKeese   | `enrt_init_red_or_black_keese`        | `enrt_update_keese`     | 3    |
| $28 | Rope         | `enrt_init_rope`                      | `enrt_update_rope`      | 5    |

## Bridges added

| File | Primitives drained / forwarded | Step |
|------|--------------------------------|------|
| `src/game/enemies/enemy_flyer_bridge.c` (extended) | `Directions8`, `c_move_flyer`, `c_reset_shove_info`, `c_control_keese_flight`, `c_draw_object_mirrored_with_frame` | 3 |
| `src/game/enemies/enemy_walker_bridge.c` (extended) | `c_update_zol_state`, `c_zol_check_collisions`, `c_gel_move`, `c_gel_check_collisions` | 4 |
| `src/game/enemies/enemy_flyer_bridge.c` (extended) | `c_update_peahat` (Z_04 native drain) | 6 |
| `src/game/enemies/enemy_boss_bridge.c` (NEW)       | `z07_set_type_and_clear_object`, `c_gel_move_splitting`, `z04_update_common_wanderer`, `c_anim_advance_and_fetch`, `c_find_empty_monster_slot` (native), `c_shoot` | 7 |

All bridges live under `src/game/enemies/` per WT-5 — no new files
under `RoomRom/`.

## Probes

- `tools/debug/probes/probe_family73_dispatch.lua` — multi-slot
  family-73 trace at `$FF7E40`. Seeds 6 slots (zol/gel/peahat/keese/
  rope/vire) and runs 31 samples × 20 frames = 600-frame evolution.
- Probe block: `ENEMY_LOOP_FAMILY73_BASE = 0x00FF7E40`. 4-byte 'FM'
  header + 6 entries × 8 bytes (alive/type/x/y/dir/anim_t/move_t/flap).
- Result: `tools/audit/drain_findings/phase7_task_7_3_step8/`
  (multi_slot_dispatch_verify.md + probe_family73_PASS.txt + .png).

## Step audit

| Step | Commit   | Drop                                                         |
|------|----------|--------------------------------------------------------------|
| 1    | 0b1b6b04 | link flyer/jumper drain TUs into Debug.md                    |
| 2    | 3f0da81d | flyer/jumper unresolved-primitive audit                      |
| 3    | c2076cda | bridge flyer primitives + wire keese ($1B/$1C/$1D)            |
| 4    | 81ce1127 | bridge zol/gel primitives + wire $13/$14/$15                 |
| 5    | e4303fbc | wire rope $28 dispatch rows                                  |
| 6    | edc4f827 | native UpdatePeahat drain + wire $1A                         |
| 7    | 0c8fc617 | link boss TU + bridge vire primitives + wire $12             |
| 8    | cb8bae84 | family-73 multi-slot dispatch verify (8/8 PASS)              |
| 9    | this     | Task 7.3 commit family close                                 |

## Step 8 verdict (8/8 PASS)

```
PASS  G1 magic 'FM' present
PASS  G2 slot  6 zol    ($13) alive+type held
PASS  G3 slot  7 gel    ($15) alive+type held
PASS  G4 slot  8 peahat ($1A) alive+type held
PASS  G5 slot  9 keese  ($1B) alive+type held
PASS  G6 slot 10 rope   ($28) alive+type held
PASS  G7 slot 11 vire   ($12) alive+type held
PASS  G8 at least one family-73 slot advanced motion/anim (witness: zol)
```

Per-slot motion (t+0 → t+600):
- zol (48,48) → (32,13), wandered NW; move-timer cycled $05→$00 4×
- gel (48,112) → (48,31), jumped N; gel-splitting move pattern
- peahat (48,174) → (48,86), N drift dir=$08
- keese (208,48) → (208,225), wrapped — flying drift active
- rope (208,112) → (208,112), idle but anim cycled 1→10 (NES rope
  only moves on Link sight; UPDATE body still ticked)
- vire (208,176) → (208,82), jumped N, anim_t cycled 1→10

## Build verification

`Debug.bat` clean per-step through commit `cb8bae84`. Banned-token
gate green (no Title.md / RoomRom.md / CombinedDebug.md / whatif
references in active code). Active scope = `src/game/enemies/**` +
existing RoomRom main include lines (no new RoomRom files per WT-5).
No substrate edits.

## Coverage gates

- 4-line task header: filled.
- Gate 1 (per-function diff): drained C linked verbatim — `enrt_*`
  bodies are byte-for-byte from oracle TUs. Bridge files re-implement
  only the c_*-named primitives the Title-side ABI doesn't already
  provide; each forwards to a drained twin or carries a NES-verbatim
  body (see `enemy_boss_bridge.c::c_find_empty_monster_slot`).
- Gate 2 (per-RAM-cell trace): step 8 probe verifies 6 slots' alive/
  type/x/y/anim/move cells across 600 frames — all 6 hold their NES
  TYPE byte unchanged + 5 of 6 advance motion (rope's stationary
  state matches NES idle behavior).
- Gate 3 (per-scenario oracle): deferred to Phase 7 milestone tag.

## Phase 7 close-gate progress

- focused_probe_set: ✅ (`probe_family73_dispatch.lua` 8-gate trace,
  slots 6..11 multi-type dispatch)
- diff_vs_nes_reference: ✅ — 6/6 dispatch rows linked to drained C
  matching `Z_04.asm:5295 UpdateObject_JumpTable` and `Z_07.asm:5601
  InitObject_JumpTable` entries
- screenshot_state_evidence: ✅ (`probe_family73_PASS.png`)

## Known gap (not blocking task close)

`ENEMY_THROWER_SLOT ($0340)` is read by `enrt_shoot` (vire spawn-on-
jump) but currently unwritten by `enemy_loop_tick` per-slot. NES
`Shoot` uses `CurObjIndex` (X reg) implicitly. Step 8 probe's vire
did not split during the 600-frame window (jump phase didn't reach
split trigger). First time vire shoots a split-slot, `c_shoot` will
read whatever `$0340` happened to hold from the last writer. Track
for Task 7.5 (vire split behavior is on the Special Enemy Family
checklist anyway).

## Re-entry triggers for follow-on tasks

| Trigger | Goes to |
|---------|---------|
| Vire split spawn slot computation | Task 7.5 (special family) |
| Per-frame parity oracle vs NES capture | Phase 7 exit Gate 2 |
| Per-scenario room-load → spawn → death | Phase 7 milestone tag |
