# $55 / $56 Fireball

- **NES source**: reference/aldonunez/Z_04.asm:982 UpdateFireball
- **Drained C**:  src/oracle/enemies/enemy_projectile_runtime.c:302 enrt_update_fireball
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 2-state. State 0 pick aim (z01_get_directions_and_distances_to_target
slot 0 = Link) + speed indices (mid index 4) + reset fracs. State 1
(timer countdown then move per axis with FireballQSpeedsX/Y). No
bounce; destroy on out-of-bounds OR Link hit. $55 from Zora/Manhandla
fireball, $56 from Gohma/GleeokHead fireball.
