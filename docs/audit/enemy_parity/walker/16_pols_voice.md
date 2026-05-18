# $16 PolsVoice

- **NES source**: reference/aldonunez/Z_04.asm:6533 UpdatePolsVoice
- **Drained C**:  src/game/enemies/enemy_special_bridge.c:328 enrt_update_pols_voice
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 2-state walker/jumper. State 0 = walking (decrement remaining
distance, ADC PolsVoiceWalkSpeedsY by dir). State 1 = jumping (vertical
accel $38 frac + carry whole). Gates: InvClock | StunTimer → draw-only;
odd FrameCounter → draw-only. Tile $B0 or $F4..$FF → set state 1.
ObjInvincibilityMask = $FE (sword-only damage).
