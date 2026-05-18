# $42..$45 Gleeok (1-4 necks)

- **NES source**: reference/aldonunez/Z_04.asm:8601 UpdateGleeok
- **Drained C**:  src/oracle/enemies/enemy_gleeok_runtime.c:68 enrt_update_gleeok
- **Coverage**:   FULL
- **Stance**:     EXTEND

Behavior: $42=1neck, $43=2neck, $44=3neck, $45=4neck — all share
UpdateGleeok. Drain composes c_gleeok_fetch_neck_addrs /
gleeok_move_neck / draw_segment_and_check_collisions / calc_segment_limits
/ stretch_neck / gleeok_check_collisions / dec_head_timer per neck.
6 segments per neck. INIT seeds 4 necks × 6 segments per
Gleeok_NeckXs/Ys. Hit/death cry handled via Gleeok_CheckCollisions
inner asm (NES Z_04.asm:9147).
