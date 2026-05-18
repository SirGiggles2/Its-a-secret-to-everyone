# $24 RedWizzrobe

- **NES source**: reference/aldonunez/Z_04.asm:7474 UpdateRedWizzrobe
- **Drained C**:  src/oracle/enemies/enemy_wizzrobe_runtime.c enrt_update_red_wizzrobe
- **Coverage**:   FULL
- **Stance**:     GREENFIELD

Behavior: 4-state machine (jump table at Z_04.asm:7496). State 0/2
align + fade. State 1 RedWizzrobe_1. State 3 RedWizzrobe_3 (active
walking/shooting). Fade counter at $0394 alias.
RedWizzrobeOffsetsX/Y + Directions tables for teleport.
