# $28 Rope

- **NES source**: reference/aldonunez/Z_04.asm:4549 UpdateRope
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:97 enrt_update_rope
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: save dir → input dir, Walker_Move (skipped if InvClock |
StunTimer). On dir-change → speed=$20. If qspeed=$20 + grid offset=0,
check |dx| < 8 (rush vertically) or |dy| < 8 (rush horizontally) at
$60 speed. 10-frame anim cycle. Quest 2 uses CUR_SPRITE_ATTR_ROW & 3
palette variation.
