# $31 / $32 Dodongo

- **NES source**: reference/aldonunez/Z_04.asm:5856 UpdateDodongo
- **Drained C**:  src/game/enemies/bosses/boss_dodongo.c:207 boss_dodongo_update
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: 4-step tail UpdateDodongoState (3-state JT: 0 Move /
1 Bloated / 2 Stunned) + Dodongo_CheckCollisions + Dodongo_CheckBombHit
+ Dodongo_Draw. Bomb-eating boss. NES UpdateDodongo has no
PlayBossHitCry tail (drain matches).
