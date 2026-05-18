# $2A Stalfos

- **NES source**: reference/aldonunez/Z_04.asm:4670 UpdateStalfos
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:248 enrt_update_stalfos
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: UpdateCommonWanderer($80) + CheckMonsterCollisions +
animate-and-draw(8). Quest-2 only: sword-shot $57 via enrt_try_shooting
gated on ShootTimer != 0 OR Random+slot < $F8. Quest-1 early-return
before shoot. B1.1 fix affects quest-2 path.
