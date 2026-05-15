/* level_info_install.c — install NES Z1 per-level SRAM tables.
 *
 * NES source: PRG-ROM holds 6 attribute sub-tables (A..F, 128 bytes
 *             each = 768 total) per "level block" plus a 256-byte
 *             LevelInfo block that contains FoeCounts + assorted
 *             per-level constants. Real NES cart starts with these
 *             pre-populated in SRAM ($687E..$6C7D). On power-up the
 *             InitSaveRam check at Z_05.asm:7375 only clears RAM
 *             from $6530..$6FFF when the sentinel is wrong; otherwise
 *             it leaves the PRG-loaded tables intact.
 *
 *             Our Genesis port never wrote those tables, so every
 *             consumer reading $697E (LBA_C), $69FE (LBA_D), or
 *             $6BA2 (FoeCounts) saw zeros — enemy_room_load_objects
 *             returned 0 and ObjType[1..count] stayed empty.
 *
 * Drained C:  NONE (PRG->SRAM copy not part of any drained body).
 * Stance:     GREENFIELD — substrate fix. Per Drain Rule D1,
 *             tools/audit/drain_coverage.json has no candidate row
 *             for the level-info loader.
 *
 * Data already ships in repo:
 *   data/rooms/overworld.c  rooms_overworld[]  (LevelBlock + LevelInfo OW)
 *   data/rooms/dungeons.c   rooms_dungeons[]   (4 LevelBlocks UW + 9 LevelInfo UW)
 *
 * NES SRAM layout (per Variables.inc):
 *   $687E .. $68FD   LevelBlockAttrsA (128 bytes)
 *   $68FE .. $697D   LevelBlockAttrsB
 *   $697E .. $69FD   LevelBlockAttrsC
 *   $69FE .. $6A7D   LevelBlockAttrsD
 *   $6A7E .. $6AFD   LevelBlockAttrsE
 *   $6AFE .. $6B7D   LevelBlockAttrsF
 *   $6B7E .. $6C7D   LevelInfo  (256 bytes)
 *     +0x24 = FoeCounts ($6BA2) — first byte of LevelInfo_FoeCounts.
 *
 * Source-blob layout (matches NES SRAM exactly):
 *   rooms_overworld[0..767]    = LevelBlock (6 sub-tables)
 *   rooms_overworld[768..1023] = LevelInfo
 *   rooms_dungeons[0..767]      = LevelBlockUW1Q1
 *   rooms_dungeons[768..1535]   = LevelBlockUW2Q1
 *   rooms_dungeons[1536..2303]  = LevelBlockUW1Q2
 *   rooms_dungeons[2304..3071]  = LevelBlockUW2Q2
 *   rooms_dungeons[3072 + (level-1)*256 .. +255] = LevelInfoUW<level>
 *
 * NES Z_05.asm InitMode2Load (Z_06.asm:202) applies per-quest patches
 * AFTER the base block lands; those patches are PER-QUEST replacement
 * of specific bytes (see LevelBlockAttrsBQ2Replacement{Offsets,Values}).
 * We pick the pre-patched LevelBlockUW{N}Q{Q} block directly per quest
 * — no patch step needed for L1-L6 / L7-L9.
 */

#include "level_info_install.h"
#include "platform_abi.h"

extern const unsigned char rooms_overworld[];
extern const unsigned char rooms_dungeons[];

/* NES SRAM addresses per Variables.inc. */
#define NES_LBA_A_BASE          0x687Eu
#define NES_LBA_BLOCK_BYTES     768u
#define NES_LEVEL_INFO_BASE     0x6B7Eu
#define NES_LEVEL_INFO_BYTES    256u

/* Blob offsets per data/rooms/MANIFEST.json. */
#define BLOB_OW_LEVELBLOCK_OFF  0u
#define BLOB_OW_LEVELINFO_OFF   768u

#define BLOB_UW_BLOCK_BYTES     768u
#define BLOB_UW_LEVELINFO_BASE  3072u
#define BLOB_UW_LEVELINFO_STRIDE 256u

static void copy_to_nes_ram(unsigned short dst_nes_addr,
                            const unsigned char *src,
                            unsigned int bytes)
{
    unsigned int i;
    for (i = 0u; i < bytes; ++i) {
        nes_ram[dst_nes_addr + i] = src[i];
    }
}

void level_info_install_ow(void)
{
    copy_to_nes_ram(NES_LBA_A_BASE,
                    &rooms_overworld[BLOB_OW_LEVELBLOCK_OFF],
                    NES_LBA_BLOCK_BYTES);
    copy_to_nes_ram(NES_LEVEL_INFO_BASE,
                    &rooms_overworld[BLOB_OW_LEVELINFO_OFF],
                    NES_LEVEL_INFO_BYTES);
}

void level_info_install_uw(unsigned char level, unsigned char quest)
{
    /* Dungeons blob layout:
     *   L1-L6 Q1 = block 0 (offset 0)
     *   L7-L9 Q1 = block 1 (offset 768)
     *   L1-L6 Q2 = block 2 (offset 1536)
     *   L7-L9 Q2 = block 3 (offset 2304)
     * level: 1..9, quest: 1 or 2. Clamp out-of-range to L1Q1. */
    unsigned int block_off;
    if (level == 0u || level > 9u) level = 1u;
    if (quest == 0u || quest > 2u) quest = 1u;

    if (quest == 1u) {
        block_off = (level <= 6u) ? 0u : BLOB_UW_BLOCK_BYTES;
    } else {
        block_off = (level <= 6u) ? (2u * BLOB_UW_BLOCK_BYTES)
                                  : (3u * BLOB_UW_BLOCK_BYTES);
    }
    copy_to_nes_ram(NES_LBA_A_BASE,
                    &rooms_dungeons[block_off],
                    NES_LBA_BLOCK_BYTES);

    /* LevelInfoUW<level> at base 3072 + (level-1)*256. */
    unsigned int info_off = BLOB_UW_LEVELINFO_BASE +
                            ((unsigned int)(level - 1u)) * BLOB_UW_LEVELINFO_STRIDE;
    copy_to_nes_ram(NES_LEVEL_INFO_BASE,
                    &rooms_dungeons[info_off],
                    NES_LEVEL_INFO_BYTES);
}
