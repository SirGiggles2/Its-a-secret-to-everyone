# $03 BlueMoblin

- **NES source**: reference/aldonunez/Z_04.asm:1956 UpdateMoblin
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:234 enrt_update_moblin
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: turn rate $A0, Wanderer_TargetPlayer, arrow shot ($5B) at
qspeed=$20. Blue Moblin skips B1.1 rng gate.
Verified live: SHT cycles $28 → $0A → $1D.
