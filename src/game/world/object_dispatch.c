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

void object_move_object(unsigned short slot)
{
    /* NES source: reference/aldonunez/Z_07.asm:MoveObject.
     * Drained C: src/oracle/world/object_runtime.c:objrt_move_object.
     * Coverage: FULL. Stance: EXTEND (cache intermediate quarter steps).
     * No call or interrupt-visible publication occurs inside this loop. */
    /* NES MoveObject. Drain at object_runtime.c:8-72.
     *
     * Sets per-frame grid limits (slot 0 = Link uses tighter $08/$F8;
     * other slots use $10/$F0), then for each of 4 axes (right/left/
     * down/up) advances the object's fractional position by its
     * speed and steps the integer X/Y by 1 on overflow/underflow.
     * Grid offset clamps stepping at room cell boundaries (matches
     * NES_POS_GRID_LIMIT / NES_NEG_GRID_LIMIT).
     *
     * NES uses 4 separate code paths (one per direction bit) that
     * each test the same fraction-overflow / grid-clamp pattern;
     * drain mirrors with `if/else if` chain. Native ports the chain
     * directly. */
    unsigned char pos_limit, neg_limit;
    if (slot == 0u) {
        pos_limit = 0x08u;
        neg_limit = 0xF8u;
    } else {
        pos_limit = 0x10u;
        neg_limit = 0xF0u;
    }
    RAM(NES_POS_GRID_LIMIT) = pos_limit;
    RAM(NES_NEG_GRID_LIMIT) = neg_limit;

    const unsigned char dir = (unsigned char)RAM(NES_OBJ_DIR);
    if (dir == 0u) {
        return;
    }

    /* MoveObject applies quarter speed four times. Keep each intermediate
     * fraction/grid/position in registers; no other routine can observe it
     * until this call returns. Preserve direction priority and 8-bit wrap. */
    const unsigned char positive = (unsigned char)((dir & 0x01u) ||
        (!(dir & 0x03u) && (dir & 0x04u)));
    const unsigned short axis = (dir & 0x03u) ? NES_OBJ_X : NES_OBJ_Y;
    const unsigned char speed = (unsigned char)OBJ(NES_OBJ_QSPD_FRAC, slot);
    unsigned char frac = (unsigned char)OBJ(NES_OBJ_POS_FRAC, slot);
    unsigned char grid = (unsigned char)OBJ(NES_OBJ_GRID_OFFSET, slot);
    unsigned char pos = (unsigned char)OBJ(axis, slot);
    for (unsigned int i = 0u; i < 4u; ++i) {
        const unsigned char old_frac = frac;
        unsigned char step;
        if (positive) {
            frac = (unsigned char)(frac + speed);
            step = (unsigned char)(frac < old_frac);
        } else {
            step = (unsigned char)(old_frac < speed);
            frac = (unsigned char)(frac - speed);
        }
        if (grid == pos_limit || grid == neg_limit) step = 0u;
        grid = (unsigned char)(positive ? grid + step : grid - step);
        pos = (unsigned char)(positive ? pos + step : pos - step);
    }
    OBJ(NES_OBJ_POS_FRAC, slot) = frac;
    OBJ(NES_OBJ_GRID_OFFSET, slot) = grid;
    OBJ(axis, slot) = pos;
}

unsigned int object_add_q_speed_to_position_fraction(unsigned int slot)
{
    /* NES AddQSpeedToPositionFraction (Z_01.asm:3470). drain at
     * object_runtime.c:115-124. Adds quarter-speed to position
     * fraction; on carry, advances grid offset by one. Returns
     * CARRY_SET if the integer step happened (carry survived the
     * grid-limit clear). */
    const unsigned int sum =
        (unsigned int)RAM(NES_OBJ_POS_FRAC + slot) +
        (unsigned int)RAM(NES_OBJ_QSPD_FRAC + slot);
    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)sum;
    unsigned int carry = (sum >> 8) & 0x01u;
    const unsigned char grid = (unsigned char)RAM(NES_OBJ_GRID_OFFSET + slot);
    if (grid == RAM(NES_POS_GRID_LIMIT) ||
        grid == RAM(NES_NEG_GRID_LIMIT)) {
        carry = 0u;
    }
    RAM(NES_OBJ_GRID_OFFSET + slot) =
        (unsigned char)(grid + (unsigned char)carry);
    return carry ? CARRY_SET : 0u;
}

unsigned int object_sub_q_speed_from_position_fraction(unsigned int slot)
{
    /* NES SubQSpeedFromPositionFraction. drain at object_runtime.c:126.
     * Returns the NES carry: CARRY_SET when no pixel step (no borrow, or
     * grid offset at a limit: the NES forces C=1 there), 0 on a step.
     * T-171 asm_equiv: the drain returned 0 at the limit (a step). */
    const unsigned int frac    = (unsigned int)RAM(NES_OBJ_POS_FRAC + slot);
    const unsigned int sub_val = (unsigned int)RAM(NES_OBJ_QSPD_FRAC + slot);
    const unsigned int borrow  = (frac < sub_val) ? 1u : 0u;
    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)(frac - sub_val);
    const unsigned char grid = (unsigned char)RAM(NES_OBJ_GRID_OFFSET + slot);
    if (grid == RAM(NES_POS_GRID_LIMIT) ||
        grid == RAM(NES_NEG_GRID_LIMIT)) {
        return CARRY_SET;
    }
    RAM(NES_OBJ_GRID_OFFSET + slot) =
        (unsigned char)(grid - (unsigned char)borrow);
    return borrow ? 0u : CARRY_SET;
}

void object_move_shot(unsigned char direction, unsigned int slot)
{
    /* NES MoveShot. drain at object_runtime.c:138-152. Move a shot
     * (arrow/boomerang) with collision-sensitive grid-offset
     * accounting:
     *   - First check bound_by_room_with_dir; zero result = bound
     *     killed direction => set NES_SHOT_COLLISION_FLAG = $80, return.
     *   - Otherwise: save grid offset, zero it, run move_object,
     *     observe the new grid offset. If no collision was flagged,
     *     merge old + new (continuing motion); else restore saved
     *     (collision halts motion at the boundary). */
    const unsigned char dir_result =
        object_bound_by_room_with_dir(direction, slot);
    if (dir_result == 0u) {
        RAM(NES_SHOT_COLLISION_FLAG) = 0x80u;
        return;
    }
    const unsigned char saved_offset =
        (unsigned char)RAM(NES_OBJ_GRID_OFFSET + slot);
    RAM(NES_OBJ_GRID_OFFSET + slot) = 0u;
    object_move_object((unsigned short)slot);
    const unsigned char new_offset =
        (unsigned char)RAM(NES_OBJ_GRID_OFFSET + slot);
    if (RAM(NES_SHOT_COLLISION_FLAG) == 0u) {
        RAM(NES_OBJ_GRID_OFFSET + slot) =
            (unsigned char)(saved_offset + new_offset);
    } else {
        RAM(NES_OBJ_GRID_OFFSET + slot) = saved_offset;
    }
}
