/* transfer_buf_drain.c — see transfer_buf_drain.h for full task header. */

#include "transfer_buf_drain.h"
#include "world_state.h"          /* TRANSFER_BUF_POS, TRANSFER_BUF_BYTE */
#include "bg_palette.h"           /* roomrom_bg_palette_nes_to_cram */
#include "render_abi.h"           /* render_cram_write_color */

/* Maximum buffer span. NES NMI clears DynTileBuf and resets length
 * each frame; the working set in our writers stays well below $40
 * bytes (8-byte palette records, 24-byte attr records). Cap at $60
 * (96) to keep the walker bounded even if a future writer forgets
 * a terminator. */
#define TRANSFER_BUF_MAX_OFFSET 0x60u

void transfer_buf_drain(void)
{
    unsigned char end = (unsigned char)TRANSFER_BUF_POS;
    if (end == 0u) {
        return;                            /* nothing committed */
    }
    if (end > TRANSFER_BUF_MAX_OFFSET) {
        end = TRANSFER_BUF_MAX_OFFSET;
    }

    unsigned char pos = 0u;
    while (pos < end) {
        unsigned char hi = (unsigned char)TRANSFER_BUF_BYTE(pos);
        if (hi >= 0x80u) {
            break;                         /* $FF (or any neg) = end */
        }
        if ((unsigned char)(pos + 2u) >= end) {
            break;                         /* truncated header */
        }
        unsigned char lo   = (unsigned char)TRANSFER_BUF_BYTE(pos + 1u);
        unsigned char ctrl = (unsigned char)TRANSFER_BUF_BYTE(pos + 2u);
        unsigned char count = (unsigned char)(ctrl & 0x3Fu);
        if (count == 0u) {
            count = 64u;                   /* NES encoding: 0 = 64 */
        }

        if (hi == 0x3Fu) {
            /* Palette write: stream NES color bytes to CRAM slot
             * (lo & $1F) .. (lo & $1F) + count - 1. */
            unsigned char slot_base = (unsigned char)(lo & 0x1Fu);
            unsigned char i;
            for (i = 0u; i < count; i++) {
                if ((unsigned char)(pos + 3u + i) >= end) {
                    break;                 /* truncated payload */
                }
                unsigned char nes_color =
                    (unsigned char)TRANSFER_BUF_BYTE(pos + 3u + i);
                unsigned short cram =
                    roomrom_bg_palette_nes_to_cram(nes_color);
                unsigned short slot =
                    (unsigned short)((slot_base + i) & 0x1Fu);
                render_cram_write_color(slot, cram);
            }
        }
        /* else: nametable / attr write ($20..$2F). Drained but not
         * rendered yet — pending plane-write bridge. */

        pos = (unsigned char)(pos + 3u + count);
    }

    TRANSFER_BUF_POS     = 0u;
    TRANSFER_BUF_BYTE(0) = 0xFFu;          /* sentinel */
}
