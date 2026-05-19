/* transfer_buf_drain.c — see transfer_buf_drain.h for full task header. */

#include "transfer_buf_drain.h"
#include "world_state.h"          /* TRANSFER_BUF_POS, TRANSFER_BUF_BYTE */
#include "bg_palette.h"           /* roomrom_bg_palette_nes_to_cram */
#include "render_abi.h"           /* render_cram_write_color */
#include "platform_abi.h"         /* RAM macro */

/* Maximum buffer span. NES NMI clears DynTileBuf and resets length
 * each frame; the working set in our writers stays well below $40
 * bytes (8-byte palette records, 24-byte attr records). Cap at $60
 * (96) to keep the walker bounded even if a future writer forgets
 * a terminator. */
#define TRANSFER_BUF_MAX_OFFSET 0x60u

/* NES TileBufSelector cell — Variables.inc:5 (`TileBufSelector := $14`).
 * Selectors are byte indices into TransferBufAddrs (Z_06.asm:489) so
 * valid values are even. Non-zero selector = pending static transfer. */
#define TILE_BUF_SELECTOR RAM(0x0014u)

/* ---- Static asm-side palette buffers ----
 *
 * Ported from reference/aldonunez/Z_06.asm. As more Mode N paths
 * activate on Genesis, add their TransferBufAddrs entries here and
 * extend resolve_static_buffer. Selector value = byte offset into
 * TransferBufAddrs (each entry is 2 bytes), so $2C = entry 22. */

/* Z_06.asm:813 Mode11DeadLinkPalette = selector $2C (entry 22). */
static const unsigned char k_mode11_dead_link_palette[] = {
    0x3Fu, 0x10u, 0x04u, 0x0Fu, 0x10u, 0x30u, 0x00u, 0xFFu
};

/* Map selector -> static buffer pointer + length. Returns NULL if
 * unknown (caller clears selector to avoid pile-up). */
static const unsigned char *resolve_static_buffer(unsigned char selector,
                                                  unsigned char *out_len)
{
    switch (selector) {
    case 0x2Cu:
        *out_len = (unsigned char)sizeof k_mode11_dead_link_palette;
        return k_mode11_dead_link_palette;
    default:
        *out_len = 0u;
        return (const unsigned char *)0;
    }
}

/* Process a single $3F palette record at byte offset `payload_off`
 * within whichever source the caller is walking.
 *
 * Phase R (2026-05-18 perf polish): batch contiguous CRAM writes via
 * render_cram_subrange_upload when no slot wrap occurs. Previous impl
 * looped render_cram_write_color per color (one 2-byte CRAM word per
 * call); during dead-Link palette fade or item-pickup flash storms
 * this added up to 96 calls per frame. Batched path = 1 subrange
 * upload for the whole record. Slot wrap (rare; only when slot_base +
 * count > 32) falls back to per-color path. */
static void emit_palette_record(unsigned char lo,
                                unsigned char count,
                                const unsigned char *src,
                                unsigned char src_off,
                                unsigned char src_end)
{
    unsigned char slot_base = (unsigned char)(lo & 0x1Fu);
    /* Cap count to the bytes actually available in source. */
    unsigned char src_avail = (unsigned char)((src_off < src_end)
                                              ? (src_end - src_off) : 0u);
    if (count > src_avail) count = src_avail;
    if (count == 0u) return;

    /* Fast path: no slot wrap. Convert NES->CRAM into local buffer,
     * subrange-upload once. CRAM has 64 slots (4 PALs x 16); but
     * NES palram only addresses lower 32 slots ($00..$1F). */
    if ((unsigned short)slot_base + (unsigned short)count <= 32u) {
        unsigned short cram_buf[64];  /* upper bound = NES record max */
        unsigned char i;
        for (i = 0u; i < count; i++) {
            cram_buf[i] = roomrom_bg_palette_nes_to_cram(src[src_off + i]);
        }
        render_cram_subrange_upload((unsigned short)slot_base, cram_buf, count);
        return;
    }

    /* Fallback: slot wrap requires per-slot writes (subrange would
     * stride past CRAM end). Rare in NES Z1 records. */
    {
        unsigned char i;
        for (i = 0u; i < count; i++) {
            unsigned char nes_color = src[src_off + i];
            unsigned short cram = roomrom_bg_palette_nes_to_cram(nes_color);
            unsigned short slot = (unsigned short)((slot_base + i) & 0x1Fu);
            render_cram_write_color(slot, cram);
        }
    }
}

/* Walk a record-formatted byte buffer up to `len`. */
static void drain_record_buffer(const unsigned char *buf, unsigned char len)
{
    unsigned char pos = 0u;
    while (pos < len) {
        unsigned char hi = buf[pos];
        if (hi >= 0x80u) {
            break;                         /* $FF (or any neg) = end */
        }
        if ((unsigned char)(pos + 2u) >= len) {
            break;                         /* truncated header */
        }
        unsigned char lo   = buf[pos + 1u];
        unsigned char ctrl = buf[pos + 2u];
        unsigned char count = (unsigned char)(ctrl & 0x3Fu);
        if (count == 0u) {
            count = 64u;                   /* NES encoding: 0 = 64 */
        }
        if (hi == 0x3Fu) {
            emit_palette_record(lo, count, buf,
                                (unsigned char)(pos + 3u), len);
        }
        /* else $20..$2F nametable/attr: drained but not rendered yet
         * (plane-bridge pending). */
        pos = (unsigned char)(pos + 3u + count);
    }
}

/* Drain the dynamic TRANSFER_BUF at nes_ram[$0302..]. */
static void drain_dynamic_buffer(void)
{
    unsigned char end = (unsigned char)TRANSFER_BUF_POS;
    if (end == 0u) {
        return;
    }
    if (end > TRANSFER_BUF_MAX_OFFSET) {
        end = TRANSFER_BUF_MAX_OFFSET;
    }
    unsigned char pos = 0u;
    while (pos < end) {
        unsigned char hi = (unsigned char)TRANSFER_BUF_BYTE(pos);
        if (hi >= 0x80u) {
            break;
        }
        if ((unsigned char)(pos + 2u) >= end) {
            break;
        }
        unsigned char lo   = (unsigned char)TRANSFER_BUF_BYTE(pos + 1u);
        unsigned char ctrl = (unsigned char)TRANSFER_BUF_BYTE(pos + 2u);
        unsigned char count = (unsigned char)(ctrl & 0x3Fu);
        if (count == 0u) {
            count = 64u;
        }
        if (hi == 0x3Fu) {
            /* Phase R: copy payload from TRANSFER_BUF macro into local
             * buffer so emit_palette_record can batch via subrange
             * upload. Avoids duplicating the slot-wrap fallback. */
            unsigned char payload[64];
            unsigned char i;
            unsigned char copy_len = count;
            unsigned char avail = (unsigned char)((pos + 3u < end)
                                                   ? (end - pos - 3u) : 0u);
            if (copy_len > avail) copy_len = avail;
            for (i = 0u; i < copy_len; i++) {
                payload[i] = (unsigned char)TRANSFER_BUF_BYTE(pos + 3u + i);
            }
            emit_palette_record(lo, copy_len, payload, 0u, copy_len);
        }
        pos = (unsigned char)(pos + 3u + count);
    }
    TRANSFER_BUF_POS     = 0u;
    TRANSFER_BUF_BYTE(0) = 0xFFu;
}

/* Drain the static TileBufSelector path. */
static void drain_static_selector(void)
{
    unsigned char selector = (unsigned char)TILE_BUF_SELECTOR;
    if (selector == 0u) {
        return;
    }
    unsigned char len = 0u;
    const unsigned char *buf = resolve_static_buffer(selector, &len);
    if (buf != (const unsigned char *)0) {
        drain_record_buffer(buf, len);
    }
    /* Always clear selector — unknown selectors are intentionally
     * ignored (no asm-side processing on Genesis) so leaving the
     * value set would re-trigger every frame. */
    TILE_BUF_SELECTOR = 0u;
}

void transfer_buf_drain(void)
{
    drain_dynamic_buffer();
    drain_static_selector();
}
