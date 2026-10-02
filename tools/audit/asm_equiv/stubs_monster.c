/* Callee stubs for the monster AI specs; the 6502 side has the same stubs
 * in specs_monster.py (STUBS_MONSTER_ASM). Draw output and the collision
 * pass are the boundary: CheckMonsterCollisions has its own spec, the
 * sprite writers are checked by the screen sweep. See harness_core.c. */
extern unsigned char g_mem[];
void eq_log_byte(unsigned char v);

static void log_draw(unsigned char kind, unsigned char frame, unsigned int slot)
{
    eq_log_byte(kind); eq_log_byte(frame); eq_log_byte((unsigned char)slot);
    eq_log_byte(g_mem[0x00]); eq_log_byte(g_mem[0x01]); eq_log_byte(g_mem[0x0F]);
}

void draw_object_mirrored(unsigned char frame, unsigned int slot) { log_draw('M', frame, slot); }
void draw_object_not_mirrored(unsigned char frame, unsigned int slot) { log_draw('N', frame, slot); }
void draw_object_mirrored_with_frame(unsigned char frame, unsigned int slot) { log_draw('M', frame, slot); }
void draw_object_not_mirrored_with_frame(unsigned char frame, unsigned int slot) { log_draw('N', frame, slot); }

void link_collision_check_monster_collisions(unsigned int slot)
{
    eq_log_byte('K'); eq_log_byte((unsigned char)slot);
}

void link_collision_check_link_collision(unsigned int slot)
{
    eq_log_byte('L'); eq_log_byte((unsigned char)slot);
}
