# $1E Armos

- **NES source**: reference/aldonunez/Z_04.asm:3302 UpdateArmos
- **Drained C**:  src/game/enemies/enemy_walker_bridge.c:1219 enrt_update_armos
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: UpdateGoriya base + ObjShoveDir/ObjAnimCounter gates +
DrawArmosAndCheckCollisions. Anim 6 frames per cycle; frame index EOR
$02 to flip between front/back pose-pairs. INIT $1E uses
InitArmosOrFlyingGhini (secret-armos scan + power bracelet path on
match). On death → ObjType=$5D DeadDummy.
