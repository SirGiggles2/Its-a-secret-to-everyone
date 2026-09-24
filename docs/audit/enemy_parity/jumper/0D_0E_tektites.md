# $0D-$0E Tektites

- **NES source**: `reference/aldonunez/Z_04.asm:InitTektite`,
  `UpdateTektiteOrBoulder`; `Jumper_AnimateAndCheckCollisions`.
- **Drained C**: `src/oracle/enemies/enemy_boss_runtime.c:enrt_init_tektite`,
  `enrt_update_tektite_or_boulder`, and
  `enrt_jumper_animate_and_check_collisions`.
- **Coverage**: PARTIAL (natural Genesis jump, landing, bounds and airborne
  presentation; no aligned live NES/Genesis frame oracle yet).
- **Stance**: EXTEND.

The original parity audit excluded `$0D/$0E`; the user's 2026-09 recovery
scope includes them. The former baseline exclusion is historical, not current
acceptance policy.

Focused evidence: `builds/reports/recovery/tektite-jump-20260921/result.json`.
Four naturally loaded Tektites in overworld room `$76` moved, completed
repeated state-0/state-1 jump cycles, landed, alternated sprite frames and
stayed within room bounds. The renderer now carries the state-derived frame
into the airborne draw branch, matching the NES control flow identified in
`UpdateTektiteOrBoulder`.

A staged NES/Genesis corner case confirms the second-hit path. Starting at
dir $09, reversal count 1, and one pixel beyond the upper-right bounds, both
engines yield dir $05 and count 0 after one update (boundary reversal plus
the two-hit horizontal flip). Coordinates and bounds differ by room implementation,
but the resulting state, target-Y setup, speed and unchanged position agree.
Evidence and ROM/probe identities: `builds/reports/recovery/tektite-boundary-20260923/`.

Still open: frame-aligned NES/Genesis art and timing, blue/red differences,
additional natural edge/reversal scenarios, collision/damage, death/drop, Quest 2 and room
revisit. This scoped result does not pass P3.3/P3.4 as a whole.

