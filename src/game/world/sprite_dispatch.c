/* sprite_dispatch.c — native sprite subsystem dispatch (Phase 4).
 *
 * Drain MATCH per finding 4_3n. Inlines core helper
 * `z01_reset_cur_sprite_index` (NES Z_01.asm:3095) per NES semantics
 * to keep src/game/ free of transpile shims.
 */

#include "sprite_dispatch.h"
#include "platform_abi.h"      /* RAM */
#include "room_state.h"        /* ROOM_OAM_BYTE */
#include "enemy_state.h"       /* ENEMY_PLAYER_OBJ_X */
#include "sprite_state.h"      /* OAM_SPRITE_ATTR */

/* NES RollingSpriteIndex = $0341. Wrap value = $28 (40 slots). */
#define ROLLING_SPRITE_INDEX_ADDR 0x0341u
#define ROLLING_SPRITE_INDEX_WRAP 0x28u

/* Inline equivalent of NES ResetCurSpriteIndex (Z_01.asm:3095):
 *   LDA #$00 / STA RollingSpriteIndex / RTS */
static inline void sprite_reset_cur_sprite_index_inline(void)
{
    RAM(ROLLING_SPRITE_INDEX_ADDR) = 0u;
}

void sprite_cycle_cur_sprite_index(void)
{
    /* drain: idx = RAM($0341) + 1; if idx == $28 reset; else store. */
    const unsigned char idx =
        (unsigned char)(RAM(ROLLING_SPRITE_INDEX_ADDR) + 1u);
    if (idx == ROLLING_SPRITE_INDEX_WRAP) {
        sprite_reset_cur_sprite_index_inline();
    } else {
        RAM(ROLLING_SPRITE_INDEX_ADDR) = idx;
    }
}

unsigned char sprite_cycle_sprite_index_in_a(unsigned char idx)
{
    /* drain: same as cycle_cur_sprite_index but seed from `idx` param
     * and return the new value. */
    idx = (unsigned char)(idx + 1u);
    if (idx == ROLLING_SPRITE_INDEX_WRAP) {
        sprite_reset_cur_sprite_index_inline();
        return 0u;
    }
    RAM(ROLLING_SPRITE_INDEX_ADDR) = idx;
    return idx;
}

void sprite_hide_object_sprites(void)
{
    /* drain (sprite_runtime.c:29-36): write $F8 (off-screen Y) to
     * OAM Y-byte of slots 24..63 (offsets 96..255 step 4). Then bump
     * high-priority OAM cursor at $0342 via cycle_sprite_index_in_a. */
    unsigned char d2 = 96u;
    do {
        ROOM_OAM_BYTE(d2) = 0xF8u;
        d2 = (unsigned char)(d2 + 4u);
    } while (d2 != 0u);  /* wraps to 0 after 256 → exit */
    RAM(0x0342) = sprite_cycle_sprite_index_in_a((unsigned char)RAM(0x0342));
}

void sprite_show_link_sprites_behind_horizontal_doors(void)
{
    /* drain (sprite_runtime.c:38-61) — see drain comment for full
     * background explanation. NES Z_01.asm:1594-ish.
     *
     * If Link's left edge (link_x) or right edge (link_x + 8) is in
     * the "off-side" range ($00..$0F or $E9..$FF), set OAM attr bit
     * $20 on the corresponding Link sprite slot (18 = left half,
     * 19 = right half) to drop priority below high-prio BG. */
    const unsigned char link_x  = (unsigned char)ENEMY_PLAYER_OBJ_X;
    const unsigned char x_left  = link_x;
    const unsigned char x_right = (unsigned char)(link_x + 8u);

    if (x_left < 0x10u || x_left >= 0xE9u) {
        OAM_SPRITE_ATTR(18) = (uint8_t)(OAM_SPRITE_ATTR(18) | 0x20u);
    }
    if (x_right < 0x10u || x_right >= 0xE9u) {
        OAM_SPRITE_ATTR(19) = (uint8_t)(OAM_SPRITE_ATTR(19) | 0x20u);
    }
}
