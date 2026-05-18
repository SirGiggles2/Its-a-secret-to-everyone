# $22 FlyingGhini

- **NES source**: reference/aldonunez/Z_04.asm:3967 UpdateFlyingGhini
- **Drained C**:  src/game/enemies/enemy_flyer_bridge.c:481 enrt_update_flying_ghini
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: InvClock-gated ControlFlyingGhiniFlight + MoveFlyer +
enrt_draw_ghini_and_check_collisions. 6-state flight (GhiniDecideState
RNG_A $A0/$08 thresholds). INIT shared with Armos
(InitArmosOrFlyingGhini secret-scan path).
