# $1A Peahat

- **NES source**: reference/aldonunez/Z_04.asm:4014 UpdatePeahat
- **Drained C**:  src/game/enemies/enemy_flyer_bridge.c:426 enrt_update_peahat
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: ShoveDir → Obj_Shove, else InvClock|StunTimer-gated
ControlPeahatFlight + MoveFlyer. 6-state flight machine (SpeedUp,
PeahatDecideState, Chase, Wander, SlowDown, Delay). DecideState picks
2/3/4 from RNG_A ($B0/$20 thresholds). Frame = FLAP_PHASE & 1.
Collision: state 5 → CheckMonsterCollisions, else CheckLinkCollision.
