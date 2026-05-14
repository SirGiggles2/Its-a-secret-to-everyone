/* UW push-block manifest accessor (RoomRom-side).
 *
 * NES source: reference/aldonunez/Z_05.asm:FindAndCreatePushBlockObject
 *             (5461-5514). For each room, the pushable block is the
 *             first $B0 tile found scanning BG row 10 left-to-right.
 *
 * Slice-1: L1Q1 only.
 */

#ifndef ROOMROM_UW_PUSH_BLOCK_META_H
#define ROOMROM_UW_PUSH_BLOCK_META_H

typedef struct {
    unsigned char level;
    unsigned char quest;
    unsigned char room_id;
    unsigned char block_col_mt;   /* 0..15 */
    unsigned char block_row_mt;   /* 0..10 */
    unsigned char allowed_dirs;   /* bit0=N bit1=S bit2=W bit3=E */
    unsigned char trigger_kind;   /* 0=collision 1=stair 2=door */
} roomrom_pushblock_meta_t;

/* Returns 1 + writes *out if `room_id` has a pushable block in
 * `(level, quest)`. Slice-1 manifest: L1Q1 only. */
unsigned char roomrom_pushblock_for_room(unsigned char level,
                                         unsigned char quest,
                                         unsigned char room_id,
                                         roomrom_pushblock_meta_t *out);

#endif /* ROOMROM_UW_PUSH_BLOCK_META_H */
