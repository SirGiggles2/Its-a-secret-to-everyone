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

/* Over-Link draws write fixed OAM slots ($40/$44) on both machines; the
 * sprite bytes are the screen sweep's job. Logged like the other draws. */
void draw_object_mirrored_over_link(unsigned char frame, unsigned int slot) { log_draw('O', frame, slot); }
void draw_object_not_mirrored_over_link(unsigned char frame, unsigned int slot) { log_draw('P', frame, slot); }

/* Link_EndMoveAndAnimate_Bank4 boundary (Wallmaster carrying Link): the
 * NES stub logs 'A' + ObjX/ObjY of Link; the Genesis mirror runs the
 * RoomRom Link owner, whose first call is the face query. Link's own
 * movement/animation is a separate subsystem. */
unsigned char roomrom_main_current_link_face(void)
{
    eq_log_byte('A'); eq_log_byte(g_mem[0x70]); eq_log_byte(g_mem[0x84]);
    return 0;
}
void roomrom_main_set_link_story_pose(unsigned char x, unsigned char y, unsigned char face)
{ (void)x; (void)y; (void)face; }
void roomrom_combat_animate_link_base(void) { }
void roomrom_sprites_set_link_hurt_pose(short x, short y, int face, unsigned char f, unsigned char t)
{ (void)x; (void)y; (void)face; (void)f; (void)t; }
void roomrom_sprites_set_link_pose(short x, short y, int face, unsigned char f)
{ (void)x; (void)y; (void)face; (void)f; }
/* Genesis render-cache patch for the Wallmaster's closed hand: no NES RAM
 * effect (the NES OAM patch that follows it runs on both sides). */
void enemy_render_wallmaster_patch(unsigned char slot, unsigned char closed_hand)
{ (void)slot; (void)closed_hand; }

/* Anim_WriteItemSprites: the sprite writer (OAM on the NES, the native
 * sprite cache on the Genesis). Logs Y (item), X (slot) and the caller's
 * draw setup: [00] X, [01] Y, [04]/[05] attributes, [0C] frame, [0F] flip. */
void anim_write_item_sprites(unsigned int slot, unsigned int item_slot)
{
    eq_log_byte('I'); eq_log_byte((unsigned char)item_slot); eq_log_byte((unsigned char)slot);
    eq_log_byte(g_mem[0x00]); eq_log_byte(g_mem[0x01]); eq_log_byte(g_mem[0x04]);
    eq_log_byte(g_mem[0x05]); eq_log_byte(g_mem[0x0C]); eq_log_byte(g_mem[0x0F]);
}

/* Link_EndMoveAndAnimate_Bank4 as called from object updates (UpdateDock,
 * Pond Fairy): same 'A' record as the 6502 stub. */
void roomrom_main_link_end_move_from_object(void)
{
    eq_log_byte('A'); eq_log_byte(g_mem[0x70]); eq_log_byte(g_mem[0x84]);
}

/* Anim_WriteSprite: single-sprite writer (OAM / native cache). Logs tile,
 * slot, the object's X/Y and the caller's [03] attributes. */
void c_anim_write_sprite(unsigned int tile, unsigned int slot)
{
    eq_log_byte('S'); eq_log_byte((unsigned char)tile); eq_log_byte((unsigned char)slot);
    eq_log_byte(g_mem[0x70u + slot]); eq_log_byte(g_mem[0x84u + slot]); eq_log_byte(g_mem[0x03]);
}

/* WriteBossSprite: one boss sprite record. Logs tile, X, Y, attributes. */
void draw_write_boss_sprite(unsigned char tile, unsigned char x, unsigned char y,
                            unsigned char attr)
{
    eq_log_byte('B'); eq_log_byte(tile); eq_log_byte(x); eq_log_byte(y); eq_log_byte(attr);
}
