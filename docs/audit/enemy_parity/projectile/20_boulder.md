# $20 Boulder

- **NES source**: reference/aldonunez/Z_04.asm:2168 UpdateTektiteOrBoulder
- **Drained C**:  src/oracle/enemies/enemy_boss_runtime.c:126 enrt_update_tektite_or_boulder
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: rolling rock projectile (Death Mountain). Shares state
machine with Tektite ($0D/$0E out-of-scope) — type-keyed branches at
enemy_boss_runtime.c:218 (Boulder skips reversal-timer randomization).
