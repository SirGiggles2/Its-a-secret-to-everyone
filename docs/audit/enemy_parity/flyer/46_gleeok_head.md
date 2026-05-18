# $46 GleeokHead

- **NES source**: reference/aldonunez/Z_04.asm:8527 UpdateGleeokHead
- **Drained C**:  src/game/enemies/bosses/boss_gleeok.c:697 boss_gleeok_update_head
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: flying-head 5-state dispatch. State 0 init via
z04_init_blue_keese reuse. States 2/3 routed through
c_control_keese_flight (chase/wander). Fireball $56 shoot per timer.
Spawned by Gleeok detach when neck dies.
