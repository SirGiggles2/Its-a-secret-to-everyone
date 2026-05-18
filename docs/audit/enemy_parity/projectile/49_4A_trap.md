# $49 / $4A Trap

- **NES source**: reference/aldonunez/Z_01.asm:2434 UpdateTrap_Full
- **Drained C**:  src/game/world/trap_dispatch.c trap_update_trap_full
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: corner trap (dungeon). 4 or 6 traps spawned per cluster from
TrapXs/TrapYs tables. Fire when Link aligned axially → fly toward
Link, bounce off wall, return. trap_init_trap_full seeds cluster on
INIT.
