/* Auto-derived (verified 2026-05-07) per-level FoeCounts anchor offset
 * within each 256-byte LevelInfoUW{N} block. NES Z1 convention: the
 * FoeCounts byte pattern (03 05 06 08) appears at a different position
 * in each level's LevelInfo block; everything else is fixed-rel.
 *
 * Verification command (records identical values):
 *   python3 -c "..." (see build/probes/ph5/task_5_6/nes_ground_truth.md)
 *
 * Indexed by (level - 1). */

#include "dungeons_offsets.h"

const unsigned char ROOMROM_UW_LEVELINFO_FOE_COUNTS_OFFSET[9] = {
    0x20u,  /* L1 */
    0x1Cu,  /* L2 */
    0x18u,  /* L3 */
    0x14u,  /* L4 */
    0x10u,  /* L5 */
    0x0Cu,  /* L6 */
    0x08u,  /* L7 */
    0x04u,  /* L8 */
    0x00u,  /* L9 */
};
