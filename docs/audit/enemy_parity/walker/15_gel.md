# $15 Gel

- **NES source**: reference/aldonunez/Z_04.asm:1381 UpdateGel
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:163 enrt_update_gel
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 3-state Gel. State 0 init (qspeed=$20, timer=5, advance).
State 1 try gel_move_splitting, on block snap to grid + state 2.
State 2 wander at qspeed=$40 via update_normal_zol_or_gel.
ZolGelDelays table indexed by RNG & 3 (+4 for Gel offset).
