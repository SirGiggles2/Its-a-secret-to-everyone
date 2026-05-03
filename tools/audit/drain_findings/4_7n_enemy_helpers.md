# Drain Finding — Phase 4 Task 4.7 (native port) — enemy helpers

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for 5 enemy
subsystem leaf helpers. Establishes `src/game/enemies/enemy_dispatch.{h,c}`
scaffold + `NATIVE_ENEMY` cutover gate. Phase 4 enemy port begins —
biggest visible RoomRom gap (no enemies in OW per user feedback).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/enemies/enemy_dispatch.{h,c}` | `enemy_find_empty_monster_slot`, `enemy_hide_sprites_over_link`, `enemy_play_secret_found_tune`, `enemy_play_boss_death_cry`, `enemy_gohma_play_parry_tune` |
| Drain | `src/oracle/enemies/enemy_runtime.c` (12-20), `enemy_common_runtime.c` (4-20) |
| NES asm | `reference/aldonunez/Z_07.asm` |
| State accessors | `src/state/enemy_state.h` | `ENEMY_OAM_HIDE_0/1`, `ENEMY_SFX_SECRET/BOSS_CRY/BOSS_CRY_FLAGS/PARRY`, `ENEMY_NEXT_SHOT_SLOT`, `OBJ()` macro for `NES_OBJ_TYPE` |

## Drain MATCH proof

| Function | Drain | Verdict |
|----------|-------|---------|
| find_empty_monster_slot | scan slots 11..1 for OBJ_TYPE==0; on hit set ENEMY_NEXT_SHOT_SLOT and return slot; else 0 | **MATCH** — NES FindEmptyMonsterSlot |
| hide_sprites_over_link | ENEMY_OAM_HIDE_0 = $F8; ENEMY_OAM_HIDE_1 = $F8 | **MATCH** |
| play_secret_found_tune | ENEMY_SFX_SECRET = 4 | **MATCH** |
| play_boss_death_cry | ENEMY_SFX_BOSS_CRY = 2; ENEMY_SFX_BOSS_CRY_FLAGS = $80 | **MATCH** |
| gohma_play_parry_tune | ENEMY_SFX_PARRY = 1 | **MATCH** |

**Drain verdict: 5 functions FULL MATCH** vs NES (verified-by-use).

## Native port

Mechanical translation. No semantic changes. Pure C, no shims.

## Cutover gate

- New gate: `NATIVE_ENEMY` (independent from prior gates).
- 1 hand-written z07_* wrapper in src/gen/z_07.c
  (z07_find_empty_monster_slot). Other 4 functions don't have z01/z07_
  wrappers — they're called only from native enemy code (Plan-C drain
  internal call paths).
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links enemy_dispatch.o unconditionally beside other phase 4 .o.

## Stance update

Phase 4 Task 4.7 (Stance: ADOPT) — first enemy batch. 5 leaf helpers
ported. Real enemy update/draw functions (walker, wanderer, flyer,
boss, dodongo, manhandla, lamnola, gleeok, etc.) are heavy in
transpile shims (c_check_monster_collisions, c_draw_object_*,
c_shoot_limited, c_wanderer_target_player, etc.) — many require
multi-stage ports with cross-subsystem dependencies. Next batch
candidates (small/leaf-y):
  - enrt_walker_alt_dir_get_opposite (dir-bit toggle)
  - enrt_walker_alt_dir_end_loop (state mutation)
  - enrt_walker_alt_dir_get_random_perpendicular (RNG-driven dir)

Bigger ports: per-monster updaters defer until cross-subsystem deps
(c_draw_object_*, c_check_monster_collisions, c_shoot_limited)
land natively.

## Provenance

- 2026-05-03. Author: Claude Opus.
- First Phase 4 enemy port — establishes scaffold for biggest
  visible RoomRom gap (no enemy update/draw in OW currently).
