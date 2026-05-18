# $1B BlueKeese

- **NES source**: reference/aldonunez/Z_04.asm:1180 UpdateKeese
- **Drained C**:  src/oracle/enemies/enemy_flyer_runtime.c:164 enrt_update_keese
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: InvClock|ItemLiftTimer-gated ControlKeeseFlight + MoveFlyer.
6-state flight machine (KeeseDecideState picks 2/3/4 from RNG_B
$A0/$20). Frame = (FLAP_PHASE >> 1) & 1 (half rate of peahat). INIT
sets MAX_AIR_SPEED=$C0, AIR_SPEED=$1F (slower than red).
