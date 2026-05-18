# $06 RedGoriya

- **NES source**: reference/aldonunez/Z_04.asm:424 UpdateGoriya
- **Drained C**:  src/oracle/enemies/enemy_wanderer_runtime.c:169 enrt_update_goriya
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: Goriya AI + boomerang shot $5C. Red Goriya gated by RNG_A ==
$23 or $77 only (per enrt_walker_set_input_dir_and_try_shooting_boomerang
line 265-269). Different gate than B1.1 (specific value match, not
threshold).
