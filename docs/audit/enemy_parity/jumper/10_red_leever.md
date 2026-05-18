# $10 RedLeever (jumper-family canonical row)

- **NES source**: reference/aldonunez/Z_04.asm:2737 UpdateRedLeever
- **Drained C**:  src/game/enemies/enemy_jumper_bridge.c:472 enrt_update_red_leever
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: state-0 spawn-from-Link with cap-2 ActiveRedLeeverCount +
RedLeeverLongTimer gate. State 3 shove + move + boundary cycle. Fall-
through to RedLeever_Animate via Burrower_AnimateDrawAndCheckCollisions
shared helper. RedLeeverStateAnimTimes table.
