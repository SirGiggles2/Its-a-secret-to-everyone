/* UW push-block manifest lookup.
 *
 * NES authority: Z_05.asm:5461-5514 (FindAndCreatePushBlockObject)
 *                Z_04.asm:618-746 (UpdateBlock state machine)
 */

#include "push_block_meta.h"
#include "../../../RoomRom/data/uw_l1q1_pushblocks.h"

unsigned char roomrom_pushblock_for_room(unsigned char level,
                                         unsigned char quest,
                                         unsigned char room_id,
                                         roomrom_pushblock_meta_t *out)
{
    unsigned char idx_plus_one;
    if (out == 0) return 0u;
    if (level >= 10u || quest >= 3u || room_id >= 128u) return 0u;
    idx_plus_one = uw_pushblock_lookup[level][quest][room_id];
    if (idx_plus_one == 0u) return 0u;
    {
        const struct uw_pushblock_meta *row =
            &uw_l1q1_pushblocks[(unsigned char)(idx_plus_one - 1u)];
        out->level = row->level;
        out->quest = row->quest;
        out->room_id = row->room_id;
        out->block_col_mt = row->block_col_mt;
        out->block_row_mt = row->block_row_mt;
        out->allowed_dirs = row->allowed_dirs;
        out->trigger_kind = row->trigger_kind;
    }
    return 1u;
}
