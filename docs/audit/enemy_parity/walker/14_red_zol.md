# $14 RedZol

- **NES source**: reference/aldonunez/Z_04.asm UpdateGel (aliased)
- **Drained C**:  src/oracle/enemies/enemy_walker_runtime.c:163 enrt_update_gel
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: NES UpdateObject_JumpTable row $14 = UpdateGel (alias —
RedZol uses Gel behavior, not Zol). Movement = gel_move 3-state
dispatch + collisions + draw at frame indexed by CUR_SPRITE_ATTR_ROW
bit 1.
