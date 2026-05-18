# $33 BlueGohma / $34 RedGohma

- **NES source**: reference/aldonunez/Z_04.asm:8207 UpdateGohma
- **Drained C**:  src/oracle/enemies/enemy_boss_runtime.c:796 enrt_update_gohma
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: random-direction pick (RNG_A >= $B0 right / >= $60 left /
else down) + 1/2-pixel movement accumulator + 0x20-pixel sprint
reverse + eye state machine (open / half-open / closed cycle,
$C0|RNG reload). Shoot timer rollover → fireball $56. Tail-calls
c_gohma_animate_and_draw + c_gohma_check_collisions (5-position
collision loop). Arrow-only damage gate in Gohma_HandleWeaponCollision.
