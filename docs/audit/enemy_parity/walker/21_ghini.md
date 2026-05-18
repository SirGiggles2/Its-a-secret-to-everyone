# $21 Ghini

- **NES source**: reference/aldonunez/Z_04.asm:3067 UpdateGhini
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:341 enrt_update_ghini
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: UpdateCommonWanderer($FF — max turn rate) +
DrawGhiniAndCheckCollisions + CheckMonsterCollisions. On death
(Metastate != 0), loop slots $B..1 and force-kill any $22 FlyingGhini
by setting their metastate=$11. Frame select by UP-component vs L/R
hflip via dir-bit checks.
