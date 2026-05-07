/* UW push-block manifest lookup.
 *
 * NES authority: Z_05.asm:5461-5514 (FindAndCreatePushBlockObject)
 *                Z_04.asm:618-746 (UpdateBlock state machine)
 */

#include "uw_push_block_meta.h"
#include "../data/uw_l1q1_pushblocks.h"

unsigned char roomrom_pushblock_for_room(unsigned char level,
                                         unsigned char quest,
                                         unsigned char room_id,
                                         roomrom_pushblock_meta_t *out)
{
    unsigned char i;
    if (out == 0) return 0u;
    for (i = 0u; i < uw_l1q1_pushblocks_count; i++) {
        if (uw_l1q1_pushblocks[i].level == level &&
            uw_l1q1_pushblocks[i].quest == quest &&
            uw_l1q1_pushblocks[i].room_id == room_id) {
            out->level         = uw_l1q1_pushblocks[i].level;
            out->quest         = uw_l1q1_pushblocks[i].quest;
            out->room_id       = uw_l1q1_pushblocks[i].room_id;
            out->block_col_mt  = uw_l1q1_pushblocks[i].block_col_mt;
            out->block_row_mt  = uw_l1q1_pushblocks[i].block_row_mt;
            out->allowed_dirs  = uw_l1q1_pushblocks[i].allowed_dirs;
            out->trigger_kind  = uw_l1q1_pushblocks[i].trigger_kind;
            return 1u;
        }
    }
    return 0u;
}
