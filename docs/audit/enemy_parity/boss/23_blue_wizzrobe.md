# $23 BlueWizzrobe

- **NES source**: reference/aldonunez/Z_04.asm:7034 UpdateBlueWizzrobe
- **Drained C**:  src/oracle/enemies/enemy_wizzrobe_runtime.c enrt_update_blue_wizzrobe
- **Coverage**:   FULL
- **Stance**:     GREENFIELD

Behavior: walking + teleporting alternation. ObjTimer drives walking;
ObjRemDistance ($0394) drives teleporting. Magic-clock-gated draw +
collisions. Teleport target from Random + tile-walkability check
via Wizzrobe_GetCollidableTile. Shoots magic shot $58 via
BlueWizzrobe_TryShooting.
