# $10 RedLeever (walker dispatch row)

- **NES source**: reference/aldonunez/Z_04.asm:2737 UpdateRedLeever
- **Drained C**:  src/game/enemies/enemy_jumper_bridge.c:472 enrt_update_red_leever
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: state-0 spawn-from-Link gate (RedLeeverLongTimer +
ActiveRedLeeverCount cap), state-3 shove/move/boundary cycle, fall-
through to RedLeever_Animate via Burrower_AnimateDrawAndCheckCollisions
shared helper. Also listed under jumper family ($10 is dual-classed).
