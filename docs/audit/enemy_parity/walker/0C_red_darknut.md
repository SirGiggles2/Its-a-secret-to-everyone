# $0C RedDarknut

- **NES source**: reference/aldonunez/Z_04.asm:6474 UpdateDarknut
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:281 enrt_update_darknut
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: same as Blue Darknut. INIT sets WALK_SPEED=$28 (faster
than Blue $20). Both Darknut types use same UPDATE body.
