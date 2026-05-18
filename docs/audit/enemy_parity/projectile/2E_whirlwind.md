# $2E Whirlwind

- **NES source**: reference/aldonunez/Z_01.asm:1765 UpdateWhirlwind_Full
- **Drained C**:  src/game/world/trap_dispatch.c trap_update_whirlwind_full
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: cyclone that grabs Link + warps to dungeon entrance.
Self-contained; uses core_set_up_whirlwind + core_destroy_whirlwind +
room_go_to_next_mode_from_play primitives.
