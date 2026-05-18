# $13 Zol

- **NES source**: reference/aldonunez/Z_04.asm:1235 UpdateZol
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:156 enrt_update_zol
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 3-state machine via c_update_zol_state. State 0 = wander
(qspeed=$18). State 1 = big shove (gel_move_splitting). State 2 =
split into 2 Gels with opposite dirs. Draw mirrored frame indexed by
ENEMY_CUR_SPRITE_ATTR_ROW bit 3.
