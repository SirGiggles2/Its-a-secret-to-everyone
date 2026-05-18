# $1F BoulderSet

- **NES source**: reference/aldonunez/Z_04.asm:2168 UpdateBoulderSet
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c:98 enrt_update_boulder_set
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: rock spawner (statue). ObjTimer countdown; on 0 →
FindEmptyMonsterSlot, set type=$20 Boulder, INC ActiveBoulders.
Cap 3 active boulders.
