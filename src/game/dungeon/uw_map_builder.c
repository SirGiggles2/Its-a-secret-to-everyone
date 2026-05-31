/* uw_map_builder.c — see uw_map_builder.h for the NES references. */
#include "uw_map_builder.h"
#include "../../abi/platform_abi.h"          /* nes_ram, NES_SRAM_BASE,
                                                NES_SRAM_ROOM_FLAGS_PTR_LO/HI */
#include "../../../data/rooms/dungeons_offsets.h"  /* FoeCounts offsets */

extern const unsigned char rooms_dungeons[];

/* rooms_dungeons[] layout (data/rooms/dungeons_offsets.h). */
#define LI_BASE        0x0C00u   /* LevelInfoUW1 */
#define LI_STRIDE      0x0100u   /* 256 bytes / level */

/* Field offsets RELATIVE to the per-level FoeCounts anchor ($6BA2):
 *   rotation  $6BAB - $6BA2 = 0x09
 *   triforce  $6BAE - $6BA2 = 0x0C
 *   map mask  $6BBD - $6BA2 = 0x1B  (16 bytes) */
#define LI_ROT_REL     0x09u
#define LI_TRI_REL     0x0Cu
#define LI_MASK_REL    0x1Bu

/* Installed LevelBlock attr tables in nes_ram (byte-aligned install). */
#define LBA_A_BASE     0x687Eu
#define LBA_B_BASE     0x68FEu

/* NES MapRowMasks[row] = $80 >> row (Z_05.asm:7527). */
#define MAP_ROW_MASK(row) ((unsigned char)(0x80u >> (row)))

/* CalcOpenDoorwayMask LevelMasks (dir index 0..3 -> single bit). */
static const unsigned char k_dir_masks[4] = { 0x01u, 0x02u, 0x04u, 0x08u };

/* Blob index of the current level's FoeCounts anchor. */
static unsigned short uw_foe_anchor(unsigned char level)
{
    return (unsigned short)(LI_BASE
        + (unsigned short)(level - 1u) * LI_STRIDE
        + ROOMROM_UW_LEVELINFO_FOE_COUNTS_OFFSET[level - 1u]);
}

unsigned char uw_map_rotation(unsigned char level)
{
    if (level < 1u || level > 9u) return 0u;
    return (unsigned char)(rooms_dungeons[uw_foe_anchor(level) + LI_ROT_REL] & 0x0Fu);
}

unsigned char uw_map_triforce_room(unsigned char level)
{
    if (level < 1u || level > 9u) return 0u;
    return rooms_dungeons[uw_foe_anchor(level) + LI_TRI_REL];
}

/* NES FindDoorAttrByDoorBit (Z_05.asm:4520) collapsed to the 4 cardinal
 * door bits. Direction-bit -> which installed attr byte + nibble:
 *   up    $08 -> AttrsA bits 5-7
 *   down  $04 -> AttrsA bits 2-4
 *   left  $02 -> AttrsB bits 5-7
 *   right $01 -> AttrsB bits 2-4 */
static unsigned char uw_door_attr(unsigned char room, unsigned char dirbit)
{
    const unsigned char a = nes_ram[LBA_A_BASE + room];
    const unsigned char b = nes_ram[LBA_B_BASE + room];
    switch (dirbit) {
        case 0x08u: return (unsigned char)((a >> 5) & 7u);
        case 0x04u: return (unsigned char)((a >> 2) & 7u);
        case 0x02u: return (unsigned char)((b >> 5) & 7u);
        default:    return (unsigned char)((b >> 2) & 7u); /* $01 */
    }
}

/* Live world flags for an arbitrary room, via the savefile room-flags
 * pointer ($6BAF/$6BB0) — the path gameplay (room_get_room_flags) uses,
 * so the builder tracks the player's real exploration. */
static unsigned char uw_room_flags(unsigned char room)
{
    const unsigned short ptr =
        (unsigned short)nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_LO]
      | (unsigned short)((unsigned short)
            nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_HI] << 8);
    return nes_ram[ptr + room];
}

/* NES Submenu_WriteScanningMapRoomMark + CalcOpenDoorwayMask for one room. */
static unsigned char uw_room_glyph(unsigned char room)
{
    const unsigned char flags = uw_room_flags(room);
    /* Unvisited: OpenDoorwayMask defaults to $13 -> $13+$E2 = $F5 blank. */
    if ((flags & 0x20u) == 0u) return 0xF5u;

    /* Visited: shift the 4 cardinal doors into a 4-bit mask, MSB first
     * (up $08 / down $04 / left $02 / right $01). */
    static const unsigned char dirbit[4] = { 0x08u, 0x04u, 0x02u, 0x01u };
    static const unsigned char diridx[4] = { 3u,    2u,    1u,    0u    };
    unsigned char mask = 0u;
    unsigned char i;
    for (i = 0u; i < 4u; ++i) {
        const unsigned char attr = uw_door_attr(room, dirbit[i]);
        unsigned char is_open;
        if (attr < 4u) {
            is_open = (attr == 0u) ? 1u : 0u;          /* open vs wall */
        } else {
            is_open = (flags & k_dir_masks[diridx[i]]) ? 1u : 0u; /* opened? */
        }
        mask = (unsigned char)(((unsigned char)(mask << 1) | is_open) & 0x0Fu);
    }
    return (unsigned char)(0xE2u + mask);
}

void uw_map_build(unsigned char level, unsigned char out[8][16])
{
    unsigned char row, col, k;

    if (level < 1u || level > 9u) {
        for (row = 0u; row < 8u; ++row)
            for (col = 0u; col < 16u; ++col) out[row][col] = 0xF5u;
        return;
    }

    /* 1. Raw glyph per room (room id = row<<4 | col). */
    for (row = 0u; row < 8u; ++row)
        for (col = 0u; col < 16u; ++col)
            out[row][col] = uw_room_glyph((unsigned char)((row << 4) | col));

    /* 2. Rotate each row RIGHT by SubmenuMapRotation (Z_05.asm @Rotate). */
    {
        const unsigned char rot = uw_map_rotation(level);
        if (rot != 0u) {
            unsigned char tmp[16];
            for (row = 0u; row < 8u; ++row) {
                for (k = 0u; k < 16u; ++k)
                    tmp[(unsigned char)((k + rot) & 0x0Fu)] = out[row][k];
                for (k = 0u; k < 16u; ++k) out[row][k] = tmp[k];
            }
        }
    }

    /* 3. Mask: blank cols where SubmenuMapMask[col] & MapRowMasks[row]==0
     *    (Z_05.asm @MaskRooms). Mask read FoeCounts-anchored from the blob. */
    {
        const unsigned char *mask16 =
            &rooms_dungeons[uw_foe_anchor(level) + LI_MASK_REL];
        for (row = 0u; row < 8u; ++row)
            for (col = 0u; col < 16u; ++col)
                if ((mask16[col] & MAP_ROW_MASK(row)) == 0u)
                    out[row][col] = 0xF5u;
    }
}
