# $30 Gibdo

- **NES source**: reference/aldonunez/Z_04.asm:6464 UpdateGibdo
- **Drained C**:  src/oracle/enemies/enemy_common_runtime.c:22 enrt_update_gibdo
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: UpdateCommonWanderer($80) + CheckMonsterCollisions +
Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor(8) +
SetObjHFlip + DrawObjectNotMirrored frame 0. Simplest walker — 6
NES instructions.
