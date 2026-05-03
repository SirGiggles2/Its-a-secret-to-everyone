/* object_dispatch.c — native object subsystem dispatch (Phase 4).
 *
 * Phase 4 first port: bound_direction_horizontally + _vertically +
 * bound_by_room + bound_by_room_with_dir. Pure C, no shims.
 * Drain MATCH per Gate 1 finding 4_2n.
 */

#include "object_dispatch.h"
#include "platform_abi.h"  /* RAM, OBJ, NES_OBJ_*, NES_BOUND_* */

/* NES inline helper ResetMovingDir (Z_01.asm; small inline body):
 *   if NES_OBJ_DIR ($0F) & dir_bit: NES_OBJ_DIR = 0
 *
 * NES BoundDirectionReturn:  TYA / AND $0F / BEQ exit / JMP ResetMovingDir
 * Y holds the dir-bit reference being tested ($02 for left, $01 for
 * right, $08 for up, $04 for down). drain encapsulates as
 * `objrt_reset_moving_dir_if_mask`. */
static inline void object_reset_moving_dir_if_mask(unsigned char dir_bit)
{
    if (RAM(NES_OBJ_DIR) & dir_bit) {
        RAM(NES_OBJ_DIR) = 0u;
    }
}

void object_bound_direction_horizontally(unsigned int slot)
{
    /* NES BoundDirectionHorizontally (Z_01.asm:3312). drain at
     * src/oracle/world/object_runtime.c:74-87. */
    const unsigned char x = (unsigned char)RAM(NES_OBJ_X + slot);
    RAM(NES_TMP0) = x;

    /* For non-Link objects in slot >= $0D or type == $5C (boomerang),
     * shift collision-test X by +$0B for the left-bound test. */
    if (slot != 0u &&
        (slot >= 0x0Du || RAM(NES_OBJ_TYPE + slot) == 0x5Cu)) {
        RAM(NES_TMP0) = (unsigned char)(x + 0x0Bu);
    }

    /* Left bound. */
    if (RAM(NES_TMP0) < RAM(NES_BOUND_LEFT)) {
        object_reset_moving_dir_if_mask(2u);  /* $02 = left direction */
        return;
    }

    /* For non-Link objects in slot >= $0D or type == $5C, shift back
     * by -$17 to test the right side. (NES does +$0B then -$17 = net
     * -$0C from original x.) */
    if (slot != 0u &&
        (slot >= 0x0Du || RAM(NES_OBJ_TYPE + slot) == 0x5Cu)) {
        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x17u);
    }

    /* Right bound. */
    if (RAM(NES_TMP0) >= RAM(NES_BOUND_RIGHT)) {
        object_reset_moving_dir_if_mask(1u);  /* $01 = right direction */
    }
}

void object_bound_direction_vertically(unsigned int slot)
{
    /* NES BoundDirectionVertically (Z_01.asm:3382). drain at
     * object_runtime.c:89-102. Same shape as horizontal but on Y axis
     * with $0F (top) / $21 (bottom) shifts and $08 (up) / $04 (down)
     * direction bits. */
    const unsigned char y = (unsigned char)RAM(NES_OBJ_Y + slot);
    RAM(NES_TMP0) = y;

    if (slot != 0u &&
        (slot >= 0x0Du || RAM(NES_OBJ_TYPE + slot) == 0x5Cu)) {
        RAM(NES_TMP0) = (unsigned char)(y + 0x0Fu);
    }

    if (RAM(NES_TMP0) < RAM(NES_BOUND_TOP)) {
        object_reset_moving_dir_if_mask(8u);  /* $08 = up direction */
        return;
    }

    if (slot != 0u &&
        (slot >= 0x0Du || RAM(NES_OBJ_TYPE + slot) == 0x5Cu)) {
        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x21u);
    }

    if (RAM(NES_TMP0) >= RAM(NES_BOUND_BOTTOM)) {
        object_reset_moving_dir_if_mask(4u);  /* $04 = down direction */
    }
}

unsigned char object_bound_by_room(unsigned int slot)
{
    /* NES BoundByRoom (Z_01.asm:3457):
     *   JSR BoundDirectionHorizontally
     *   JSR BoundDirectionVertically
     *   LDA $0F   ; NES_OBJ_DIR after both clears
     *   RTS */
    object_bound_direction_horizontally(slot);
    object_bound_direction_vertically(slot);
    return (unsigned char)RAM(NES_OBJ_DIR);
}

unsigned char object_bound_by_room_with_dir(unsigned char direction,
                                            unsigned int slot)
{
    /* NES sets $0F = direction before JSR BoundByRoom; drain wrapper
     * at object_runtime.c:110 captures that pattern. */
    RAM(NES_OBJ_DIR) = direction;
    return object_bound_by_room(slot);
}
