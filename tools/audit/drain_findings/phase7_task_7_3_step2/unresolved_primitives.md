# Phase 7 Task 7.3 step 2 — flyer / jumper unresolved-primitive audit

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:5601 InitObject_JumpTable`
                  + `:5295 UpdateObject_JumpTable`
                  (entries $12-$15 jumper/zol/gel + $1A-$1D peahat/keese
                  + $28 rope; vire init+update via boss_runtime.c).
- **Drained C**:  `src/oracle/enemies/enemy_flyer_runtime.c` (linked in step 1)
                  + `src/oracle/enemies/enemy_walker_runtime.c` (linked Task 7.2 step 1)
                  + `src/oracle/enemies/enemy_common_runtime.c` (linked Task 7.2 step 1).
- **Coverage**:   PARTIAL — drain candidates exist for every Task 7.3 type
                  except peahat UPDATE (still transpiled in `z_04.asm`).
- **Stance**:     ADOPT (when wired). Drain bodies will be linked verbatim;
                  bridging primitives drained per-call as they surface.

## Why dispatch is NOT wired in this step

Mirrors Task 7.2 step 2 reasoning. Adding any single Task 7.3 init or
update row to `enemy_init_fns[]` / `enemy_update_fns[]` retains the
parent oracle TU past `--gc-sections`, which pulls every other drained
function in the same TU and surfaces unresolved `c_*` primitives the
Title-side ABI does not provide.

Per Drain Rule D1 we cannot stub primitives — that would silently no-op
drained behavior. Step 3+ must drain (or bridge to existing native
drains) each primitive before its consuming type can wire.

## Unresolved-primitive inventory (per type)

Captured from `ld.exe` output after a probe wiring of `[0x13/0x14/0x15/0x1B/0x1C/0x1D/0x28]`.

| NES type | Init drain                       | Update drain        | Unresolved primitives revealed |
| -------- | -------------------------------- | ------------------- | ------------------------------ |
| $12 Vire        | `enemy_boss_runtime.c::InitVire` (NOT linked) | `enemy_boss_runtime.c::enrt_update_vire` (NOT linked) | full file — `oracle_enemy_boss.o` link blocked behind boss-class shim plumbing |
| $13 Zol         | `enrt_init_walker`             | `enrt_update_zol` (walker_runtime.c:156)          | `c_update_zol_state`, `c_zol_check_collisions`, `c_draw_object_mirrored_with_frame` |
| $14 RedZol      | `enrt_init_walker`             | `enrt_update_gel` (walker_runtime.c:163, NES alias) | (same as $15) |
| $15 Gel         | `enrt_init_gel` (walker_runtime.c:92) | `enrt_update_gel`  | `c_gel_move`, `c_gel_check_collisions`, `c_draw_object_mirrored_with_frame` |
| $1A Peahat      | `enrt_init_peahat` (flyer_runtime.c:100) | UPDATE drain pending (transpiled at `src/zelda_translated/z_04.asm:3143 UpdatePeahat`) | drain task — landing UpdatePeahat in `enemy_flyer_runtime.c` is prereq |
| $1B BlueKeese   | `enrt_init_blue_keese` (flyer_runtime.c:151) | `enrt_update_keese` (flyer_runtime.c:164) | `Directions8` (data table), `c_control_keese_flight`, `c_move_flyer`, `c_reset_shove_info`, `c_draw_object_mirrored_with_frame` |
| $1C RedKeese    | `enrt_init_red_or_black_keese` (flyer_runtime.c:159) | `enrt_update_keese`  | (same set as $1B) |
| $1D BlackKeese  | `enrt_init_red_or_black_keese` | `enrt_update_keese` | (same set as $1B) |
| $28 Rope        | `enrt_init_rope` (walker_runtime.c:71) | `enrt_update_rope` (walker_runtime.c:97) | (rope shares walker primitives — `c_walker_move`, `c_walker_check_collisions`; the bridge for these landed Task 7.2 step 4 / step 18 — should resolve as soon as $28 row lands BUT pulls the `c_update_zol_state`-class shims via the walker TU retention) |

## Distinct primitive set to drain / bridge in subsequent steps

```
c_update_zol_state              — zol AI state machine
c_zol_check_collisions          — zol vs Link / projectile / wall collision
c_gel_move                      — gel locomotion
c_gel_check_collisions          — gel collision
c_draw_object_mirrored_with_frame — shared draw (walker $1B keese / zol / gel)
c_control_keese_flight          — keese AI bob/dart
c_move_flyer                    — shared flyer locomotion
c_reset_shove_info              — shove-state reset on bounce
Directions8                     — 8-direction unit-vector table
```

Vire is a separate dependency — links `oracle_enemy_boss.o` which has
its own shim graph; drained the same way once boss-side primitives
surface.

## Step 3+ sequencing (proposed)

Mirror of Task 7.2 step 4 / step 5 walker-bridge cadence:

1. **Step 3 — bridge `Directions8` + flyer primitives** (`c_move_flyer`,
   `c_reset_shove_info`, `c_control_keese_flight`,
   `c_draw_object_mirrored_with_frame`). Wire keese rows
   $1B/$1C/$1D → `enrt_init_*_keese` + `enrt_update_keese`.
2. **Step 4 — bridge zol/gel primitives** (`c_update_zol_state`,
   `c_zol_check_collisions`, `c_gel_move`, `c_gel_check_collisions`).
   Wire $13/$14/$15.
3. **Step 5 — wire rope** ($28). Walker primitives already drained
   Task 7.2 step 18 — should be a single dispatch row commit.
4. **Step 6 — drain UpdatePeahat** from `z_04.asm:3143` into
   `enemy_flyer_runtime.c::enrt_update_peahat`. Wire $1A.
5. **Step 7 — link `oracle_enemy_boss.o`** + bridge boss primitives.
   Wire $12 Vire.
6. **Step 8+ — probe each behavior** mirroring Task 7.2 step 8 multi-slot
   probe pattern. 6/6 family-functional lines.
7. **Step 9 — Task 7.3 commit family** close.

## Build verification

`Debug.bat` clean post step 2. `oracle_enemy_flyer.o` linked but
`--gc-sections` strips entirely (no consumers yet). No new banned-token
hits. Active scope `src/game/enemies/**` — WT-5 honored.
