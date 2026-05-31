/* uw_map_builder.c — see uw_map_builder.h for the NES references.
 *
 * Data is self-contained (src/game/dungeon/uw_map_data.{c,h}, captured live
 * from NES SRAM) — NOT data/rooms/dungeons.c, whose LevelBlockAttrs regen
 * diverges from live NES. Visited state is read live from the savefile
 * room-flags pointer (the path gameplay uses), so the map tracks real
 * exploration. */
#include "uw_map_builder.h"
#include "uw_map_data.h"
#include "../../abi/platform_abi.h"   /* nes_ram, NES_SRAM_BASE,
                                        NES_SRAM_ROOM_FLAGS_PTR_LO/HI */

/* NES MapRowMasks[row] = $80 >> row (Z_05.asm:7527). */
#define MAP_ROW_MASK(row) ((unsigned char)(0x80u >> (row)))

/* CalcOpenDoorwayMask LevelMasks (dir index 0..3 -> single bit). */
static const unsigned char k_dir_masks[4] = { 0x01u, 0x02u, 0x04u, 0x08u };

unsigned char uw_map_rotation(unsigned char level)
{
    if (level < 1u || level > 9u) return 0u;
    return (unsigned char)(k_uw_map_rot[level] & 0x0Fu);
}

unsigned char uw_map_triforce_room(unsigned char level)
{
    if (level < 1u || level > 9u) return 0u;
    return k_uw_map_tri[level];
}

/* NES FindDoorAttrByDoorBit (Z_05.asm:4520) collapsed to the 4 cardinal
 * door bits, reading the live-NES-captured door block for this level:
 *   up    $08 -> AttrsA bits 5-7
 *   down  $04 -> AttrsA bits 2-4
 *   left  $02 -> AttrsB bits 5-7
 *   right $01 -> AttrsB bits 2-4 */
static unsigned char uw_door_attr(unsigned char level, unsigned char room,
                                  unsigned char dirbit)
{
    const unsigned char blk = UW_DOOR_BLOCK(level);
    const unsigned char a = k_uw_door_a[blk][room];
    const unsigned char b = k_uw_door_b[blk][room];
    switch (dirbit) {
        case 0x08u: return (unsigned char)((a >> 5) & 7u);
        case 0x04u: return (unsigned char)((a >> 2) & 7u);
        case 0x02u: return (unsigned char)((b >> 5) & 7u);
        default:    return (unsigned char)((b >> 2) & 7u); /* $01 */
    }
}

/* Live world flags for an arbitrary room, via the savefile room-flags
 * pointer ($6BAF/$6BB0) — the path gameplay (room_get_room_flags) uses. */
static unsigned char uw_room_flags(unsigned char room)
{
    const unsigned short ptr =
        (unsigned short)nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_LO]
      | (unsigned short)((unsigned short)
            nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_HI] << 8);
    return nes_ram[(unsigned short)(ptr + room)];
}

/* NES Submenu_WriteScanningMapRoomMark + CalcOpenDoorwayMask for one room. */
static unsigned char uw_room_glyph(unsigned char level, unsigned char room)
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
        const unsigned char attr = uw_door_attr(level, room, dirbit[i]);
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
            out[row][col] = uw_room_glyph(level, (unsigned char)((row << 4) | col));

    /* 2. Rotate each row RIGHT by SubmenuMapRotation (Z_05.asm @Rotate). */
    {
        const unsigned char rot = (unsigned char)(k_uw_map_rot[level] & 0x0Fu);
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
     *    (Z_05.asm @MaskRooms). */
    {
        const unsigned char *mask16 = k_uw_map_mask[level];
        for (row = 0u; row < 8u; ++row)
            for (col = 0u; col < 16u; ++col)
                if ((mask16[col] & MAP_ROW_MASK(row)) == 0u)
                    out[row][col] = 0xF5u;
    }
}
