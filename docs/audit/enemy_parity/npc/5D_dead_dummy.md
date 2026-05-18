# $5D DeadDummy

- **NES source**: reference/aldonunez/Z_07.asm:5389 UpdateDeadDummy
- **Drained C**:  src/game/enemies/enemy_walker_bridge.c z07_update_dead_dummy
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: universal "dead enemy" placeholder. Set by other enemies
on death (e.g. $1E Armos, $3F GuardFire, Moldorm tail segments). Tick
no-op — slot occupies space until room reload. NPC for accounting.
