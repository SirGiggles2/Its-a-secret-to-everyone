# $40 StandingFire

- **NES source**: reference/aldonunez/Z_04.asm:257 UpdateStandingFire
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:146 enrt_update_standing_fire
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: c_check_link_collision + palette=2 + DIR=$08 +
z07_animate_object_walking + (FRAME_FLAGS=0 if type != $40) +
draw_not_mirrored frame 0. Stationary fire in caves / Death Mountain.
