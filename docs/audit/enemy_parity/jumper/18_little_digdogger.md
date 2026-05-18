# $18 LittleDigdogger

- **NES source**: reference/aldonunez/Z_04.asm:5265 UpdateDigdogger (IsChild branch)
- **Drained C**:  src/oracle/enemies/enemy_boss_runtime.c enrt_update_digdogger
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: child Digdogger spawned by flute-split of parent ($38/$39).
Shares enrt_update_digdogger drain — IsChild gating drives little vs
big draw + 4-corner collision loop. No separate INIT row (children
seeded inside parent init).
