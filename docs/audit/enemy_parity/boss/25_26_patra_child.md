# $25 PatraChild1 / $26 PatraChild2

- **NES source**: reference/aldonunez/Z_04.asm:10164 enrt_update_patra_child path
- **Drained C**:  src/oracle/enemies/enemy_patra_runtime.c enrt_update_patra_child
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: State 0 staged spawn off slot-2 child's angle, State 1
orbit + draw + collision + dead-dummy transition on kill. INIT for
$25/$26 is a no-op — patra children seeded inside parent
enrt_init_patra (slot 2..9 loop), not via dispatch table.
