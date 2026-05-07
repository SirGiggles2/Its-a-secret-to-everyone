/* UW cellar pair lookup implementation.
 *
 * NES source authority: reference/aldonunez/Z_05.asm:7253-7301.
 * Slice-1 (Task 5.6) reads from generated uw_l1q1_cellar_pairs table.
 */

#include "uw_cellar_meta.h"
#include "../data/uw_l1q1_cellar_pairs.h"

unsigned char roomrom_uw_cellar_for_source(unsigned char level,
                                           unsigned char quest,
                                           unsigned char room_id,
                                           unsigned char *out_cellar)
{
    unsigned char i;
    if (out_cellar == 0) return 0u;
    for (i = 0u; i < uw_l1q1_cellar_pairs_count; i++) {
        if (uw_l1q1_cellar_pairs[i].level == level &&
            uw_l1q1_cellar_pairs[i].quest == quest &&
            uw_l1q1_cellar_pairs[i].source_room_id == room_id) {
            *out_cellar = uw_l1q1_cellar_pairs[i].cellar_room_id;
            return 1u;
        }
    }
    return 0u;
}

unsigned char roomrom_uw_cellar_source_for_cellar(unsigned char level,
                                                  unsigned char quest,
                                                  unsigned char cellar_id,
                                                  unsigned char *out_source)
{
    unsigned char i;
    if (out_source == 0) return 0u;
    for (i = 0u; i < uw_l1q1_cellar_pairs_count; i++) {
        if (uw_l1q1_cellar_pairs[i].level == level &&
            uw_l1q1_cellar_pairs[i].quest == quest &&
            uw_l1q1_cellar_pairs[i].cellar_room_id == cellar_id) {
            *out_source = uw_l1q1_cellar_pairs[i].source_room_id;
            return 1u;
        }
    }
    return 0u;
}

unsigned char roomrom_uw_room_is_cellar(unsigned char level,
                                        unsigned char quest,
                                        unsigned char room_id)
{
    unsigned char i;
    for (i = 0u; i < uw_l1q1_cellar_pairs_count; i++) {
        if (uw_l1q1_cellar_pairs[i].level == level &&
            uw_l1q1_cellar_pairs[i].quest == quest &&
            uw_l1q1_cellar_pairs[i].cellar_room_id == room_id) {
            return 1u;
        }
    }
    return 0u;
}
