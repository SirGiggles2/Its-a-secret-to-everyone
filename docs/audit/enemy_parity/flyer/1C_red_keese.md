# $1C RedKeese

- **NES source**: reference/aldonunez/Z_04.asm:1180 UpdateKeese
- **Drained C**:  src/oracle/enemies/enemy_flyer_runtime.c:164 enrt_update_keese
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: same as Blue Keese. INIT
(enrt_init_red_or_black_keese) bumps AIR_SPEED to $7F (faster than
Blue's $1F).
