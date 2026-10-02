/* Callee stubs for the T-056 specs (ladder, raft); the 6502 side has the
 * same stubs in specs.py (STUBS_T056_ASM). See harness_core.c for the map. */
extern unsigned char g_mem[];
void eq_log_byte(unsigned char v);

/* GetCollidingTileMoving: logs X, [0F], ObjX,X, ObjY,X; returns the call's
 * preset tile into ObjCollidedTile,X and the preset [00]/[01]. */
unsigned char collision_get_colliding_tile_moving_nes(unsigned int slot)
{
    unsigned char k = g_mem[0x5001];
    unsigned char t = g_mem[0x5200u + k];
    eq_log_byte('G'); eq_log_byte((unsigned char)slot); eq_log_byte(g_mem[0x0F]);
    eq_log_byte(g_mem[0x70u + slot]); eq_log_byte(g_mem[0x84u + slot]);
    g_mem[0x049Eu + slot] = t;
    g_mem[0x00] = g_mem[0x5300u + k];
    g_mem[0x01] = g_mem[0x5400u + k];
    g_mem[0x5001] = (unsigned char)(k + 1u);
    return t;
}

/* Anim_WriteStaticItemSpritesWithAttributes: A, X, Y, [00], [01], [0F]. */
void draw_static_item_sprites(unsigned char attrs, unsigned int slot,
                              unsigned int item_slot)
{
    eq_log_byte('D'); eq_log_byte(attrs); eq_log_byte((unsigned char)slot);
    eq_log_byte((unsigned char)item_slot);
    eq_log_byte(g_mem[0x00]); eq_log_byte(g_mem[0x01]); eq_log_byte(g_mem[0x0F]);
}

void sprite_animate_object_walking(unsigned int slot)
{
    eq_log_byte('W'); eq_log_byte((unsigned char)slot);
}

/* Link_EndMoveAndAnimate_Bank4 (Genesis: Link owner in main.c). */
void roomrom_main_link_end_move_from_object(void) { eq_log_byte('L'); }
/* Genesis-only typed-state syncs and the scroll request: no NES RAM effect
 * here (ObjDir is authoritative in NES RAM; the face mirror writes the same
 * value on the Genesis). */
void roomrom_main_link_sync_from_nes(void) { }
void nes_ram_sync_link_face(void) { }
void roomrom_main_ow_scroll_from_object(void) { }
