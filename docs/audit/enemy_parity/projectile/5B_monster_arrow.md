# $5B MonsterArrow

- **NES source**: reference/aldonunez/Z_04.asm:2102 UpdateMonsterArrow
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c enrt_update_monster_arrow
- **Coverage**:   PARTIAL
- **Stance**:     EXTEND

Behavior: qspeed=$80 + ObjTimer pre-check (if !=0, draw + check
shooter alive via ObjRefId, reset timer if shooter dead). Else delegate
to enrt_update_monster_shot which moves + Link collides + shield
bounces. Bounce state $30 → enrt_bounce_shot decrements counter to $20
then destroys.

Missing vs NES UpdateArrowOrBoomerang: state $20 spark deactivation
path (NES @Deactivate destroys arrow on anim countdown=0). Stopgap:
arrows destroy via bounce-counter saturation instead. Visible diff:
spark frame omitted.

Fix B5.1 + arrow timer pre-check committed.
