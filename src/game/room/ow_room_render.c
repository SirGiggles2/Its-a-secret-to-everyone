#include "ow_room_render.h"
#include "render_abi.h"

extern const unsigned char rooms_overworld[3090];
extern const unsigned char overworld_bg_chr[4160];

#define OW_ATTRS_D_OFFSET    384
#define OW_LAYOUTS_OFFSET    1166
#define OW_HEAP_BLOB_OFFSET  2126

/* PrimarySquaresOW from Z_05.asm line 5731 */
static const unsigned char s_primary_squares[56] = {
    0x24,0x6F,0xF3,0xFA,0x98,0x90,0x8F,0x95,
    0x8E,0x90,0x74,0x76,0xF3,0x24,0x26,0x89,
    0x03,0x04,0x70,0xC8,0xBC,0x8D,0x8F,0x93,
    0x95,0xC4,0xCE,0xD8,0xB0,0xB4,0xAA,0xAC,
    0xB8,0x9C,0xA6,0x9A,0xA2,0xA0,0xE5,0xE6,
    0xE7,0xE8,0xE9,0xEA,0xC0,0xE0,0x78,0x7A,
    0x7E,0x80,0xCC,0xD0,0xD4,0xDC,0x89,0x84
};

/* SecondarySquaresOW from Z_05.asm line 5740 */
static const unsigned char s_secondary_squares[64] = {
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
    0xF3,0xF3,0xF3,0xF3,0xFA,0xFA,0xFA,0xFA,
    0x98,0x95,0x26,0x26,0x90,0x95,0x90,0x95,
    0x8F,0x90,0x8F,0x90,0x95,0x96,0x95,0x96,
    0x8E,0x93,0x90,0x95,0x90,0x95,0x92,0x97,
    0x74,0x74,0x75,0x75,0x76,0x77,0x76,0x77,
    0xF3,0x24,0xF3,0x24,0x24,0x24,0x24,0x24,
    0x26,0x26,0x26,0x26,0x89,0x88,0x8B,0x88
};

/* Heap byte offsets from data/rooms/MANIFEST.json "ow_heap_offsets" */
static const unsigned short s_heap_offsets[16] = {
    0,53,102,168,236,286,346,405,464,526,591,660,721,775,841,893
};

static void write_square(unsigned char col, unsigned char row,
                         unsigned char tile_tl, unsigned char tile_bl,
                         unsigned char tile_tr, unsigned char tile_br)
{
    unsigned short pc = (unsigned short)(col * 2);
    unsigned short pr = (unsigned short)(row * 2 + 2);
    unsigned short w;

    w = (tile_tl < 130) ? (unsigned short)tile_tl : 0u;
    render_set_plane_a_word(pc,     pr,     w);
    w = (tile_bl < 130) ? (unsigned short)tile_bl : 0u;
    render_set_plane_a_word(pc,     pr + 1, w);
    w = (tile_tr < 130) ? (unsigned short)tile_tr : 0u;
    render_set_plane_a_word(pc + 1, pr,     w);
    w = (tile_br < 130) ? (unsigned short)tile_br : 0u;
    render_set_plane_a_word(pc + 1, pr + 1, w);
}

void ow_room_render_upload_chr(void)
{
    render_chr_upload(0x0000, overworld_bg_chr, 4160);
}

void ow_room_render_fill_plane_a(unsigned char room_id)
{
    unsigned char unique_id;
    const unsigned char *col_dirs;
    unsigned char col;

    unique_id = rooms_overworld[OW_ATTRS_D_OFFSET + room_id] & 0x3F;
    col_dirs  = &rooms_overworld[OW_LAYOUTS_OFFSET + (unsigned short)unique_id * 16];

    for (col = 0; col < 16; col++) {
        unsigned char desc       = col_dirs[col];
        unsigned char heap_idx   = (desc >> 4) & 0x0F;
        unsigned char col_in_heap = desc & 0x0F;
        const unsigned char *heap_ptr;
        unsigned short y;
        unsigned char cols_found;
        unsigned char row;
        unsigned char repeat_state;

        heap_ptr = &rooms_overworld[OW_HEAP_BLOB_OFFSET + s_heap_offsets[heap_idx]];

        y = 0;
        cols_found = col_in_heap;
        while (1) {
            if (heap_ptr[y] & 0x80) {
                if (cols_found == 0) break;
                cols_found--;
            }
            y++;
        }
        heap_ptr += y;

        row = 0;
        repeat_state = 0;
        while (row < 11) {
            unsigned char sq_byte = heap_ptr[0];
            unsigned char sq_idx  = sq_byte & 0x3F;
            unsigned char tile_tl, tile_bl, tile_tr, tile_br;

            if (sq_idx >= 0x10) {
                unsigned char p = s_primary_squares[sq_idx];
                tile_tl = p;
                tile_bl = p + 1;
                tile_tr = p + 2;
                tile_br = p + 3;
            } else {
                unsigned char b = (unsigned char)(sq_idx * 4);
                tile_tl = s_secondary_squares[b];
                tile_bl = s_secondary_squares[b + 1];
                tile_tr = s_secondary_squares[b + 2];
                tile_br = s_secondary_squares[b + 3];
            }

            write_square(col, row, tile_tl, tile_bl, tile_tr, tile_br);
            row++;

            if (sq_byte & 0x40) {
                repeat_state ^= 0x40;
                if (repeat_state != 0) continue;
            }
            heap_ptr++;
        }
    }
}
