# $3F GuardFire

- **NES source**: reference/aldonunez/Z_04.asm:9684 UpdateGuardFire
- **Drained C**:  src/game/enemies/enemy_walker_bridge.c:1394 enrt_update_guard_fire
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: rate-6 animate-and-draw + monster collisions + DeadDummy
convert on kill (metastate non-zero → ObjType=$5D). Stationary
flame guarding dungeon door area.
