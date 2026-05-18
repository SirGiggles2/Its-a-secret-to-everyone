# $01 BlueLynel

- **NES source**: reference/aldonunez/Z_04.asm:1965 UpdateLynel
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:243 enrt_update_lynel
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: Goriya AI + sword shot ($57) at qspeed=$20. Blue Lynel skips
B1.1 rng gate (NES `_TryShooting` blue-type whitelist).
