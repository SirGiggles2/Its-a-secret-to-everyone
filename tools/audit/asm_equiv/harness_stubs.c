/* Host side of tools/audit/asm_equiv: NES RAM buffer and the callee stubs
 * shared with the 6502 side (asm_equiv.py emits the same stubs in 6502).
 * Memory map (both sides): $0000-$07FF NES RAM, $6000 log index,
 * $6001 GetCollidingTileMoving call index, $6100.. log bytes,
 * $6200/$6300/$6400 per-call tile / [00] / [01] results. */
#include <string.h>

unsigned char g_mem[0x8000];
volatile unsigned char *nes_ram = g_mem;

#define LOG_IDX  0x6000u
#define CALL_IDX 0x6001u
#define LOG_BUF  0x6100u

static void log_byte(unsigned char v)
{
    g_mem[LOG_BUF + g_mem[LOG_IDX]] = v;
    g_mem[LOG_IDX] = (unsigned char)(g_mem[LOG_IDX] + 1u);
}

/* GetCollidingTileMoving stub: logs X, [0F], ObjX,X, ObjY,X; returns the
 * call's preset tile into ObjCollidedTile,X and the preset [00]/[01]. */
unsigned char collision_get_colliding_tile_moving_nes(unsigned int slot)
{
    unsigned char k = g_mem[CALL_IDX];
    unsigned char t = g_mem[0x6200u + k];
    log_byte('G'); log_byte((unsigned char)slot); log_byte(g_mem[0x0F]);
    log_byte(g_mem[0x70u + slot]); log_byte(g_mem[0x84u + slot]);
    g_mem[0x049Eu + slot] = t;
    g_mem[0x00] = g_mem[0x6300u + k];
    g_mem[0x01] = g_mem[0x6400u + k];
    g_mem[CALL_IDX] = (unsigned char)(k + 1u);
    return t;
}

/* Anim_WriteStaticItemSpritesWithAttributes stub: A, X, Y, [00], [01], [0F]. */
void draw_static_item_sprites(unsigned char attrs, unsigned int slot,
                              unsigned int item_slot)
{
    log_byte('D'); log_byte(attrs); log_byte((unsigned char)slot);
    log_byte((unsigned char)item_slot);
    log_byte(g_mem[0x00]); log_byte(g_mem[0x01]); log_byte(g_mem[0x0F]);
}

/* AnimateObjectWalking stub. */
void sprite_animate_object_walking(unsigned int slot)
{
    log_byte('W'); log_byte((unsigned char)slot);
}

/* Link_EndMoveAndAnimate_Bank4 stub (Genesis: Link owner in main.c). */
void roomrom_main_link_end_move_from_object(void) { log_byte('L'); }
/* Genesis-only typed-state syncs: no NES RAM effect in the harness
 * (ObjDir is authoritative in NES RAM here; on the Genesis the face mirror
 * writes the same value). The scroll request is Genesis integration. */
void roomrom_main_link_sync_from_nes(void) { }
void nes_ram_sync_link_face(void) { }
void roomrom_main_ow_scroll_from_object(void) { }

/* Entry points. */
extern void link_ladder_check(void);
extern void link_ladder_draw(void);
extern void link_ladder_end_move(void);
extern void world_update_dock(unsigned int slot);

void eq_check_ladder(void) { link_ladder_check(); }
void eq_draw_ladder(void) { link_ladder_draw(); }
void eq_end_move(void) { link_ladder_end_move(); }
void eq_dock(unsigned int slot) { world_update_dock(slot); }
