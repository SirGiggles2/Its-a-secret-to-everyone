# $2B BlueBubble

- **NES source**: reference/aldonunez/Z_04.asm UpdateBubble
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:14 enrt_update_bubble
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: wanderer_update_common(64) + palette = CUR_SPRITE_ATTR_ROW &
3 (Blue uses live palette toggle) + animate(1) + Link collision. On
hit: ENEMY_BUBBLE_EFFECT=16 (stun cycle). INIT sets WALK_SPEED=$40.
