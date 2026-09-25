/* transfer_buf_drain.c — see transfer_buf_drain.h for full task header. */

#include "transfer_buf_drain.h"
#include "world_state.h"          /* TRANSFER_BUF_POS, TRANSFER_BUF_BYTE */
#include "bg_palette.h"           /* roomrom_bg_palette_nes_to_cram */
#include "render_abi.h"           /* render_cram_write_color, render_set_plane_a_word */
#include "platform_abi.h"         /* RAM macro */
#include "../../../RoomRom/src/roomrom_vram_map.h" /* ROOMROM_BG_TILE_BASE */
#include "../../../RoomRom/src/roomrom_main_state.h" /* roomrom_main_current_scene */
#include "render/ow_render.h"    /* roomrom_ow_room_render_set_tile */

/* Plane-bridge: NES PPU nametable ($2000-$2FFF) writes mapped to
 * Genesis Plane A cells. Uses bg_sparse_tile_lut[nes_tile_id][sub_pal]
 * to translate NES tile id to Genesis VRAM slot. Sub-palette is fixed
 * at 0 for text writes (cave NPC dialogue, UW person text all use
 * sub-pal 0). HUD offset = +7 plane rows for playfield region. */
extern const unsigned short bg_sparse_tile_lut[256][4];
#define PLANE_BRIDGE_HUD_ROWS  7u
#define PLANE_BRIDGE_BLANK_TILE 0u

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

/* NES nametable record decoder. PPU address ($hi:$lo) range $2000-$2FFF
 * = nametable region; each NT is 32 cols × 30 rows. NES encoding sends
 * `count` consecutive tile ids starting at the decoded (col, row).
 *
 * Genesis: write Plane A cells via render_set_plane_a_word. HUD takes
 * top 7 plane rows (Window-overlaid); playfield cells = NES row + 7.
 * NES sub-palette for text is fixed at 0 (BG_attr=0). Tile id maps
 * via bg_sparse_tile_lut[nes_tile][0]; 0xFFFF sentinel = unmapped tile
 * → write blank tile (slot 0).
 *
 * Count byte (NES Z_07.asm ContinueTransferTileBuf): bit 7 set = VRAM
 * increment 32 (vertical, +1 row per tile); bit 6 set = one source byte
 * repeated `count` times. ChangeTileObjTiles records use $82 (vertical).
 *
 * T-050: OW playfield cells (NT rows 8..29) go through
 * roomrom_ow_room_render_set_tile, which knows the active room's plane
 * slot, attribute palette, raw-tile cache and walkability. */
static void emit_nametable_record(unsigned char hi,
                                  unsigned char lo,
                                  unsigned char ctrl,
                                  unsigned char count,
                                  const unsigned char *src,
                                  unsigned char src_off,
                                  unsigned char src_end)
{
    const unsigned char vertical = (unsigned char)(ctrl & 0x80u);
    const unsigned char repeat   = (unsigned char)(ctrl & 0x40u);
    const unsigned char ow = (roomrom_main_current_scene() == ROOMROM_MAIN_SCENE_OW);
    /* PPU addr = ((hi & 0x0F) << 8) | lo; range $0000..$03FF = NT0 cells. */
    unsigned short ppu_off = (unsigned short)(((hi & 0x0Fu) << 8) | lo);
    /* Only NT0 cells (offset 0..$3BF) addressable here; attribute table
     * ($3C0-$3FF) skipped (separate attr-format record, NES handles
     * via different path). Wrap-out checked. */
    if (ppu_off >= 0x3C0u) {
        return;
    }
    unsigned char nes_row  = (unsigned char)(ppu_off >> 5);   /* /32 */
    unsigned char nes_col  = (unsigned char)(ppu_off & 0x1Fu);/* mod 32 */
    /* OW/UW dynamic transfers carry PLAYFIELD-RELATIVE rows -> +7 HUD bridge.
     * CAVE NPC-dialogue transfers carry SCREEN-ABSOLUTE NT rows (line 1 =
     * $21A4 = row 13), so the +7 double-counts the HUD and dropped the text
     * ~2 rows below NES (Gen row 15/20 vs NES rows 13/14). Map the absolute
     * NT row straight to the Plane A row for caves. Byte-verified vs NES
     * golden (tools/parity/cave_golden). */
    unsigned char plane_row =
        (roomrom_main_current_scene() == ROOMROM_MAIN_SCENE_CAVE)
            ? nes_row
            : (unsigned char)(nes_row + PLANE_BRIDGE_HUD_ROWS);

    unsigned char src_avail = (unsigned char)((src_off < src_end)
                                              ? (src_end - src_off) : 0u);
    if (repeat) {
        if (src_avail == 0u) return;
    } else if (count > src_avail) {
        count = src_avail;
    }

    unsigned char i;
    for (i = 0u; i < count; i++) {
        unsigned char nes_tile = src[src_off + (repeat ? 0u : i)];
        unsigned char cell_row = (unsigned char)(nes_row + (vertical ? i : 0u));
        unsigned char cell_col = (unsigned char)(nes_col + (vertical ? 0u : i));
        if (ow && cell_row >= 8u && cell_row < 30u && cell_col < 32u &&
            roomrom_ow_room_render_set_tile(cell_col,
                                            (unsigned char)(cell_row - 8u),
                                            nes_tile)) {
            continue;
        }
        unsigned short raw_slot = bg_sparse_tile_lut[nes_tile][0];
        /* Mirror tile_word() (ow_render.c): VRAM tile = ROOMROM_BG_TILE_BASE
         * + sparse slot; unmapped (0xFFFF) -> blank tile 0. The original
         * code wrote the raw slot WITHOUT the +BG_BASE bias, so every text
         * glyph rendered one VRAM tile too low -> garbled cave NPC + UW
         * person text (chars + columns were correct; only the tile base was
         * missing). Byte-verified: Gen Plane A row held slots $48/$6D/$6A...
         * = I/T/S = "IT'S DANGEROUS" but displayed shifted by -1 tile. */
        unsigned short tile = (raw_slot == 0xFFFFu)
            ? (unsigned short)PLANE_BRIDGE_BLANK_TILE
            : (unsigned short)(ROOMROM_BG_TILE_BASE + raw_slot);
        unsigned short col = (unsigned short)cell_col;
        /* Wrap col within plane width (64). */
        col = (unsigned short)(col & 0x3Fu);
        render_set_plane_a_word(col,
                                (unsigned short)(plane_row + (vertical ? i : 0u)),
                                tile);
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
        } else if (hi >= 0x20u && hi <= 0x2Fu) {
            emit_nametable_record(hi, lo, ctrl, count, buf,
                                  (unsigned char)(pos + 3u), len);
        }
        pos = (unsigned char)(pos + 3u + ((ctrl & 0x40u) ? 1u : count));
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
        if (hi == 0x3Fu || (hi >= 0x20u && hi <= 0x2Fu)) {
            /* Copy payload from TRANSFER_BUF macro into local buffer
             * so the per-record emitter can index it as a flat array
             * (avoids duplicating wrap/avail logic between dynamic
             * and static drain paths). */
            unsigned char payload[64];
            unsigned char i;
            unsigned char copy_len = (ctrl & 0x40u) ? 1u : count;
            unsigned char avail = (unsigned char)((pos + 3u < end)
                                                   ? (end - pos - 3u) : 0u);
            if (copy_len > avail) copy_len = avail;
            for (i = 0u; i < copy_len; i++) {
                payload[i] = (unsigned char)TRANSFER_BUF_BYTE(pos + 3u + i);
            }
            if (hi == 0x3Fu) {
                if ((ctrl & 0x40u) && copy_len == 1u) {
                    for (i = 1u; i < count; i++) payload[i] = payload[0];
                    copy_len = count;
                }
                emit_palette_record(lo, copy_len, payload, 0u, copy_len);
            } else {
                emit_nametable_record(hi, lo, ctrl, count, payload, 0u, copy_len);
            }
        }
        pos = (unsigned char)(pos + 3u + ((ctrl & 0x40u) ? 1u : count));
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
