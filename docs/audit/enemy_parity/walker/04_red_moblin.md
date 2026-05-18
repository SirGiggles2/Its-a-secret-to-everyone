# $04 RedMoblin

- **NES source**: reference/aldonunez/Z_04.asm:1956 UpdateMoblin
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:234 enrt_update_moblin
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: turn rate $A0, Wanderer_TargetPlayer, arrow shot ($5B) at
qspeed=$20. Red Moblin gated by B1.1 rng check.
Verified live: WTS=$01 sometimes but SHT=$00 throughout 240-frame probe.
