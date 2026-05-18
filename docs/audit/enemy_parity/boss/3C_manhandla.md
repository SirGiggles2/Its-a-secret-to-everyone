# $3C Manhandla

- **NES source**: reference/aldonunez/Z_04.asm:7842 UpdateManhandla
- **Drained C**:  src/oracle/enemies/enemy_manhandla_runtime.c:44 enrt_update_manhandla
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 5-segment manhandla (center + 4 hands). Center slot 5 picks
new direction every 16 frames (TurnTowardsPlayer8 vs TurnRandomlyDir8
@ RNG_A >= $80). All segments share direction. Hand-segments fire
fireball $56 on RNG_B >= $E0. enrt_manhandla_check_collisions has
hit/death cry + shove reset.
