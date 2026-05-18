# $38 Digdogger1 / $39 Digdogger2

- **NES source**: reference/aldonunez/Z_04.asm:5265 UpdateDigdogger
- **Drained C**:  src/oracle/enemies/enemy_boss_runtime.c:666 enrt_update_digdogger
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: full body — magic-clock/stun gate, flute states 1+2 (turn
vs split-up vs make-children), 4-corner CheckBigDigdoggerCollisions
loop, big + little draw, Digdogger_ChangeSpeed/Move/Draw helpers.
$38 = original, $39 = 2nd-quest variant (more children on split).
INIT seeds 8-way dir from Random + SFX $40 boss roar.
