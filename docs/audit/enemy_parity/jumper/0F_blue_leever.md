# $0F BlueLeever

- **NES source**: reference/aldonunez/Z_04.asm:2599 UpdateBlueLeever
- **Drained C**:  src/game/enemies/enemy_jumper_bridge.c:616 enrt_update_blue_leever
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: ObjTurnRate=$A0 + Wanderer_TargetPlayer + UpdateBurrower
fall-through. Burrow state cycle 0..5 with BlueLeeverStateQSpeeds/
Times/AnimTimes tables. Collisions only in state 3.
