# $07-$0A Octoroks

- **NES source**: `reference/aldonunez/Z_04.asm:UpdateOctorock`;
  `Z_07.asm` type dispatch entries `$07-$0A`.
- **Drained C**: `src/oracle/enemies/enemy_walker_runtime.c:enrt_init_slow_octorock_or_ghini`;
  `src/game/enemies/enemy_walker_bridge.c:enrt_update_octorock`;
  projectile path in `src/oracle/enemies/enemy_projectile_runtime.c`.
- **Coverage**: PARTIAL (natural red Octorok movement, visible rock, sword
  combat, death, one randomized drop/pickup, immediate room-history revisit;
  all variants and NES-aligned timing remain TODO).
- **Stance**: EXTEND.

The original parity audit excluded `$07-$0A`; the user's 2026-09 recovery
scope includes them. Do not treat the old exclusion baseline as acceptance.

Focused evidence: `builds/reports/recovery/octorok-combat-20260921/result.json`
and `builds/reports/recovery/octorok-facing-20260921/`. The natural room `$67`
scenario loaded four `$07` Octoroks. Controller play produced visible `$53`
rocks, a sword hit, death spark, natural `$22` drop and pickup, then immediate
departure/re-entry with the two surviving Octoroks retained. Right/left facing
and animation were separately inspected in the facing probe.

Still open: red/blue and slow/fast variants, exact NES movement/animation and
projectile cadence, drop-rate branches and all drop types, room-clear variants,
longer persistence, Quest 2, and boundary/corner behavior. This file records
scoped evidence; it does not pass P3.3, P3.4 or P3.5 as a whole.
