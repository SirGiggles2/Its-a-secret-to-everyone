# $0B BlueDarknut

- **NES source**: reference/aldonunez/Z_04.asm:6474 UpdateDarknut
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:281 enrt_update_darknut
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: turn rate $80, UpdateCommonWanderer, never stunned
(StunTimer = 0). Custom 8-frame anim derivation: LEFT → hflip, dir>>2
yields base frame, ObjAnimFrame ? +3 + hflip-on-up. INIT sets
INVINCIBILITY=$F6 + WALK_SPEED=$20.
