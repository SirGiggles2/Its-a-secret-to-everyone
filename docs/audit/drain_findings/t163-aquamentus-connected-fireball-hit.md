# T-163 Aquamentus fireball harm in a connected fight (2026-09-29)

- **NES source**: `reference/aldonunez/Z_01.asm` projectile `HarmLink`/`BeginShove` path and live NES L1 boss-room work RAM; `Z_04.asm:Aquamentus_Shoot` emits type `$55` shots.
- **Drained C**: linked `src/game/combat/link_collision_dispatch.c:link_collision_harm_link`/`link_collision_begin_shove`, with boss shot production in `src/game/enemies/enemy_boss_bridge.c`; no production source changed.
- **Coverage**: PARTIAL (one unshielded fireball harm, cleanup, invulnerability and shove during controller-driven Original L1 Aquamentus fight; boss body contact and other projectile immunity rules remain separate).
- **Stance**: VERIFY at connected-route scope, carrying earlier staged P1.6 projectile evidence only for its original scope.

The current `tools/lockstep/presets/t013_boss_visual_astra_20260929.json` route uses controller input from the registered file, enters real L1 room `$35`, fights Aquamentus, takes the heart and Triforce, and exits. There is no HP, room-clear or item injection between the doorway and the hit. On `builds/Debug.md` SHA-256 `9cf38246cf8b9c0c6ecc6da2d22d04aff3035a047df183c97e212e6d8fec1ed4`, the run matched **9,065/9,065 KEY ticks**. NES and Genesis work-RAM rows in `builds/reports/lockstep/t013_boss_visual_astra_20260929/{nes,gen}.ram` are identical for the named cells below.

At tick 8011 Link is at `(A2,85)`, HeartValues `$21`, invincibility timer 0, shove distance 0; projectile slot 11 is type `$55` at `(B0,80)`. At tick 8012 the slot is cleared, HeartValues becomes `$20` (half-heart loss), invincibility timer becomes `$18` (24), shove distance `$20` and shove direction `$82`, on both systems. Link moves left through `(96,85)` at 8016 and `(8A,85)` at 8019, reaching `(82,85)` with shove distance 0 at 8022. The invincibility timer counts down to 0 at 8059 on both. This covers the actual hit and recovery, not only a damage register or staged collision.

The diagnostic's full-RAM **GATE FAIL** has no ratchet baseline (131 unmasked cells); that is not presented as an acceptance pass. The boss-body contact case and other P1 child behavior remain TODO.
