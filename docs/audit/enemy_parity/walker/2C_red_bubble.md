# $2C RedBubble

- **NES source**: reference/aldonunez/Z_04.asm UpdateBubble
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:14 enrt_update_bubble
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: same as Blue Bubble but palette = type - $2B = 1. On Link
collision: ENEMY_BUBBLE_STATUS = type - $2C = 0 (disable-sword effect).
