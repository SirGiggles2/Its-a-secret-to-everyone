# $3A Lamnola1 / $3B Lamnola2

- **NES source**: reference/aldonunez/Z_04.asm:9699 UpdateLamnola
- **Drained C**:  src/oracle/enemies/enemy_lamnola_runtime.c:44 enrt_update_lamnola
- **Coverage**:   FULL
- **Stance**:     ADOPT

Behavior: segmented worm boss. Head leads, body segments follow. Uses
shared `enrt_update_common_wanderer` primitive from wanderer family —
B1.1 fix path applies if Lamnola shoots (it doesn't, no _TryShooting
call). enemy_lamnola_bridge.c calls enrt_play_boss_death_cry_if_needed
+ shove reset at tail.
