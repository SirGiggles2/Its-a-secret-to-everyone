# $12 Vire

- **NES source**: reference/aldonunez/Z_04.asm:6918 UpdateVire
- **Drained C**:  src/oracle/enemies/enemy_boss_runtime.c:356 enrt_update_vire
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 2-state machine. State 0 = UpdateCommonWanderer($80) +
VireJumpOffsets[|grid_offset|] Y adjustment when horizontal-facing.
State 1 = Zol-shove. On death (state >= 2): destroy + spawn 2 Red
Keese ($1C) via 2-iter make-keese loop.
