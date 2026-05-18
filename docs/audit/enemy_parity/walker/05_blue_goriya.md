# $05 BlueGoriya

- **NES source**: reference/aldonunez/Z_04.asm:424 UpdateGoriya
- **Drained C**:  src/oracle/enemies/enemy_wanderer_runtime.c:169 enrt_update_goriya
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: Goriya AI (|dx|/|dy| pick → shoot boomerang $5C if distance
< $51). Blue Goriya always allowed to shoot per
L_Walker_SetInputDirAndTryShootingBoomerang.
