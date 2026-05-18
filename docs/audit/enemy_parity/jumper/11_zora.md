# $11 Zora

- **NES source**: reference/aldonunez/Z_04.asm:1920 UpdateZora
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:174 enrt_update_zora
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: InvClock-gated UpdateBurrower. State 3 + timer == $FD →
ShootFireball $55 + reset timer to $20. State 0 → destroy + DEC
ZoraActive (room respawn allowed). Frame select: state 1 picks
front (2) / back (3) by zora Y vs Link Y.
