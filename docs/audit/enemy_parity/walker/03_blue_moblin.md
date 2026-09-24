# $03 BlueMoblin

- **NES source**: reference/aldonunez/Z_04.asm:1956 UpdateMoblin
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:234 enrt_update_moblin
- **Coverage**:   PARTIAL
- **Stance**:     ADOPT

Behavior: turn rate $A0, Wanderer_TargetPlayer, arrow shot ($5B) at
qspeed=$20. Blue Moblin skips B1.1 rng gate.
Verified live: SHT cycles $28 → $0A → $1D.

Focused normal-room integration: overworld room `$4D` loaded four type `$03`
Moblins, naturally fired a `$5B` arrow by frame 37, advanced it across
consecutive frames, and cleared the tracked projectile at frame 128.
Evidence: `builds/reports/recovery/moblin-natural-arrow-20260923/result.json`.
NES-aligned aim/cadence, collision outcomes and complete movement/art parity
remain open; the earlier SHT evidence did not pass the whole enemy.
