/* debug_tilegrid.c — title-MODE-button-entered tile-grid debug scene.
 *
 * Mirrors the layout of the custom NES test ROM (tools/gen_chr_viewer_rom.py
 * output build/probes/chr_viewer_rom.nes) so byte-diffs across CHR banks
 * can audit every Z1 atlas (tile_id, sub_pal) combo.
 *
 * Layout (matches NES test ROM):
 *   Plane A rows  0..15  cols 0..15  — BG 16x16 tile-id grid (tile_id =
 *                                       row*16 + col), rendered via the
 *                                       sparse-LUT-resolved Genesis slot
 *                                       for the active sub_pal.
 *   Plane A everywhere else          — tile 0 (blank).
 *   SAT slots 0..63                  — 8x8 sprite grid at y=$80+, x=$00+,
 *                                       tile_id = sprite_page*64 + slot.
 *                                       8x8 or 8x16 mode per s_8x16.
 *
 * Controls:
 *   B button        cycle BG sub_pal 0..3
 *   Start           cycle sprite-page 0..3 ($00-3F .. $C0-FF)
 *   Select          toggle 8x16 sprite mode
 *   A button        no-op (Genesis atlas is unified; no bank cycle)
 *
 * Build: linked into Debug.md via TITLE_C_SOURCES in build_debug.py.
 */
#include "debug_tilegrid.h"
#include "../../abi/render_abi.h"
#include "../../../RoomRom/src/bg_sparse_chr.h"
#include "../../../RoomRom/src/atlas/items_chr_x4.h"
#include "../../../RoomRom/src/atlas/enemy_chr.h"
#include "../../../RoomRom/src/atlas/boss_chr.h"

/* Gameplay-side atlas + palette upload routines (declared here to avoid
 * pulling subsystem headers). All defined under src/game/. */
extern void roomrom_ow_room_render_upload_chr(void);
extern void roomrom_sprites_upload_chr(void);
extern void roomrom_bg_palette_load_palram_full(const unsigned char *palram32);

/* Z1 OW orig palette (matches the custom NES test ROM's PALRAM). */
extern const unsigned char g_roomrom_ow_palram[2][32];

/* SCENE_OBJ slot VRAM location: tile_base = SPR_BASE(533) + 44 = 577.
 * VRAM byte addr = 577 * 32 = 18464 = $4820 (per enemy_chr.h comment). */
#define SCENE_OBJ_VRAM_OFFSET   (577u * 32u)

/* ----- VDP / hardware addresses (Debug.md PR-2 Option F layout) ----- */
#define PLANE_A_BASE  0xC000u
/* SAT relocated to $F400 per init_video; sprite render via render_set_sprite_full
 * (it uses the SGDK SAT cache, not direct VRAM writes). */

/* ----- Controller port 1 (Genesis 6-button protocol) ----- */
#define CTRL1_DATA (*(volatile unsigned char *)0x00A10003u)
#define CTRL1_CTRL (*(volatile unsigned char *)0x00A10009u)

/* Bit positions in our consolidated joypad byte. */
#define JB_UP    0x01u
#define JB_DOWN  0x02u
#define JB_LEFT  0x04u
#define JB_RIGHT 0x08u
#define JB_B     0x10u
#define JB_C     0x20u
#define JB_A     0x40u
#define JB_START 0x80u
/* Extended (6-button) bits — collected in a second byte. */
#define JX_Z     0x01u
#define JX_Y     0x02u
#define JX_X     0x04u
#define JX_MODE  0x08u

static unsigned char s_subpal     = 0u;
static unsigned char s_sprite_page = 0u;
static unsigned char s_8x16        = 0u;
static unsigned char s_bank        = 0u;   /* 0..7 — mirrors NES bank cycle */
static unsigned char s_joy_prev    = 0u;
static unsigned char s_joyx_prev   = 0u;

/* Lua-poke driven state mirror (auto-capture probe writes here, debug
 * scene picks up changes each iteration). Addresses $FF07E0..$FF07E3:
 *   $07E0 = desired bank (0..7)
 *   $07E1 = desired sub_pal (0..3)
 *   $07E2 = desired sprite_page (0..3)
 *   $07E3 = desired 8x16 (0 or 1)
 * Set $07E4 = $AA to signal "poke pending" — scene applies + clears flag. */
#define POKE_BANK   0x07E0u
#define POKE_SUBPAL 0x07E1u
#define POKE_PAGE   0x07E2u
#define POKE_8X16   0x07E3u
#define POKE_FLAG   0x07E4u

/* External atlas variant blobs (header bg_sparse_chr.h). */
extern const unsigned char bg_sparse_chr_orig_uw [17024];
extern const unsigned char bg_sparse_chr_redux_ow[17024];
extern const unsigned char bg_sparse_chr_redux_uw[17024];

/* Bank cycle matching NES test ROM (chr_viewer_rom.nes) page layout.
 * Each bank = (BG variant, SCENE_OBJ content) pair.
 *
 * NES bank order (from gen_chr_viewer_rom.py build_chr):
 *   0  Common only        -> Genesis orig_ow BG + SCENE_OBJ blank
 *   1  OW                 -> orig_ow BG + enemy_owsp SCENE_OBJ
 *   2  UW1/2/7            -> orig_uw BG + enemy_uwsp127
 *   3  UW3/5/8            -> orig_uw BG + enemy_uwsp358
 *   4  UW4/6/9            -> orig_uw BG + enemy_uwsp469
 *   5  UW1257-boss        -> orig_uw BG + boss_uwspboss1257
 *   6  UW3468-boss        -> orig_uw BG + boss_uwspboss3468
 *   7  UW9-boss (Ganon)   -> orig_uw BG + boss_uwspboss9
 *
 * (NES page 8 = Demo/title — not extracted on Genesis side, omitted.) */
static const unsigned char *bank_bg_blob(unsigned char bank) {
    return (bank >= 2u) ? bg_sparse_chr_orig_uw : bg_sparse_chr_orig_ow;
}

static const unsigned char *bank_obj_blob(unsigned char bank, unsigned short *out_bytes) {
    switch (bank) {
        case 1u: *out_bytes = ROOMROM_ATLAS_ENEMY_OWSP_BANK_BYTES;
                 return roomrom_atlas_enemy_owsp;
        case 2u: *out_bytes = ROOMROM_ATLAS_ENEMY_PER_BANK_BYTES;
                 return roomrom_atlas_enemy_uwsp127;
        case 3u: *out_bytes = ROOMROM_ATLAS_ENEMY_PER_BANK_BYTES;
                 return roomrom_atlas_enemy_uwsp358;
        case 4u: *out_bytes = ROOMROM_ATLAS_ENEMY_PER_BANK_BYTES;
                 return roomrom_atlas_enemy_uwsp469;
        case 5u: *out_bytes = ROOMROM_ATLAS_BOSS_PER_BANK_BYTES;
                 return roomrom_atlas_boss_uwspboss1257;
        case 6u: *out_bytes = ROOMROM_ATLAS_BOSS_PER_BANK_BYTES;
                 return roomrom_atlas_boss_uwspboss3468;
        case 7u: *out_bytes = ROOMROM_ATLAS_BOSS_PER_BANK_BYTES;
                 return roomrom_atlas_boss_uwspboss9;
        default: *out_bytes = 0u;  /* bank 0 Common — leave SCENE_OBJ blank */
                 return 0;
    }
}

/* Upload current bank: BG variant blob + SCENE_OBJ content. */
static void upload_bank(void) {
    /* BG variant -> VRAM BG_TILE_BASE (offset 32) */
    render_chr_upload(32u, bank_bg_blob(s_bank), BG_SPARSE_BLOB_BYTES);
    /* SCENE_OBJ content -> VRAM offset 577*32 = $4820 */
    unsigned short obj_bytes;
    const unsigned char *obj_blob = bank_obj_blob(s_bank, &obj_bytes);
    if (obj_blob != 0 && obj_bytes != 0) {
        render_chr_upload((unsigned short)SCENE_OBJ_VRAM_OFFSET,
                          obj_blob, obj_bytes);
    }
}

/* Tiny delay to settle TH transitions on controller port. */
static inline void joy_settle(void) {
    volatile unsigned char i;
    for (i = 0; i < 8u; i++) { /* spin */ }
}

/* Genesis 6-button read. Returns base 3-button bits in *base
 * (active-high, bit positions per JB_* above) and extended bits in *ext.
 * Protocol: cycle TH high/low several times; on the 4th TH=0 read, bits
 * 3-0 are 0 for 6-button (or controller absent); on the next TH=1 read,
 * bits 3-0 = MODE, X, Y, Z in some order. We mask + invert per Sega doc. */
static void joy_read6(unsigned char *base, unsigned char *ext) {
    unsigned char b = 0u, x = 0u;
    unsigned char th0_first, th1_first, th0_second, th1_second;

    /* Cycle 1: TH=1 idle, TH=0, TH=1 — collects 3-button state. */
    CTRL1_DATA = 0x40u; joy_settle();
    CTRL1_DATA = 0x00u; joy_settle();
    th0_first = (unsigned char)(~CTRL1_DATA);    /* active-high mask */
    CTRL1_DATA = 0x40u; joy_settle();
    th1_first = (unsigned char)(~CTRL1_DATA);

    /* Cycle 2 (6-button extension): TH=0, TH=1 — 4th read gives extended bits. */
    CTRL1_DATA = 0x00u; joy_settle();
    th0_second = (unsigned char)(~CTRL1_DATA);   /* if 6-btn, bits 3-0 = 0000 */
    CTRL1_DATA = 0x40u; joy_settle();
    th1_second = (unsigned char)(~CTRL1_DATA);   /* if 6-btn, bits 3-0 = M/X/Y/Z */

    /* Idle */
    CTRL1_DATA = 0x40u; joy_settle();

    /* th0_first bits: bit5=Start, bit4=A. (3-btn TH=0 reading)
     * th1_first bits: bit5=C, bit4=B, bit3=R, bit2=L, bit1=D, bit0=U. */
    if (th0_first & 0x20u) b |= JB_START;
    if (th0_first & 0x10u) b |= JB_A;
    if (th1_first & 0x20u) b |= JB_C;
    if (th1_first & 0x10u) b |= JB_B;
    if (th1_first & 0x08u) b |= JB_RIGHT;
    if (th1_first & 0x04u) b |= JB_LEFT;
    if (th1_first & 0x02u) b |= JB_DOWN;
    if (th1_first & 0x01u) b |= JB_UP;

    /* 6-button detection: in 6-btn mode, th0_second bits 3-0 = 0000. If any
     * are 1, controller is 3-button (or absent) — return ext=0. Otherwise
     * th1_second bits 3-0 carry MODE/X/Y/Z (Sega docs use bit3=MODE bit2=X
     * bit1=Y bit0=Z but vendors differ; we treat bit0 of any set lower-
     * nibble as our "MODE-or-equivalent" trigger and let user discover). */
    if ((th0_second & 0x0Fu) == 0u) {
        /* 6-button: parse extended buttons. */
        if (th1_second & 0x08u) x |= JX_MODE;
        if (th1_second & 0x04u) x |= JX_X;
        if (th1_second & 0x02u) x |= JX_Y;
        if (th1_second & 0x01u) x |= JX_Z;
    }
    *base = b;
    *ext  = x;
}

/* Convenience: 3-button read (for cases where MODE not needed). */
static unsigned char joy_read3(void) {
    unsigned char base, ext;
    joy_read6(&base, &ext);
    return base;
}

/* Fill plane A with the 16x16 BG tile-id grid for the current sub_pal.
 * Cell (row*32 + col) for row<16, col<16 = sparse-LUT-resolved tile slot
 * for NES tile_id (row*16 + col) at s_subpal. Outside the grid = tile 1000
 * (unallocated headroom slot, all-zero pixels = backdrop = black). */
#define BLANK_TILE 1000u
static void redraw_bg(void) {
    /* Fill BOTH planes with blank-headroom tile. Plane A pixel 0 is
     * transparent and reveals Plane B underneath; if Plane B still holds
     * title art the screen looks tiled. Clear both. */
    unsigned short blank_attr = RENDER_TILE_ATTR_FULL(RENDER_PAL0, 0, 0, 0, BLANK_TILE);
    render_plane_fill(PLANE_A_BASE, blank_attr, 32u * 32u);
    render_plane_fill(0xE000u,      blank_attr, 32u * 32u);  /* Plane B */

    /* Reset scroll registers — title may have left VSRAM/HSCROLL non-zero
     * so our "row 0" lands mid-screen. VSRAM slot 0 = plane-A vertical;
     * HSCROLL table at $FC00 (or wherever VDP reg 13 points) holds plane
     * horizontal scroll. Write 0 to both to anchor at top-left. */
    /* VSRAM write to slot 0 (plane A vscroll = 0): */
    *((volatile unsigned long *)0xC00004) = 0x40000010UL;
    *((volatile unsigned short *)0xC00000) = 0x0000;
    /* VSRAM slot 2 (plane B vscroll = 0): */
    *((volatile unsigned long *)0xC00004) = 0x40020010UL;
    *((volatile unsigned short *)0xC00000) = 0x0000;
    /* HSCROLL table base $FC00, first long = plane A + plane B hscroll = 0: */
    *((volatile unsigned long *)0xC00004) = 0x7C000003UL;  /* VRAM write $FC00 */
    *((volatile unsigned long *)0xC00000) = 0x00000000UL;

    unsigned short row, col;
    unsigned short cells[16];
    for (row = 0; row < 16u; row++) {
        for (col = 0; col < 16u; col++) {
            unsigned short tile_id = (unsigned short)(row * 16u + col);
            unsigned short slot = bg_sparse_tile_lut[tile_id][s_subpal];
            unsigned short attr;
            if (slot == 0xFFFFu) {
                attr = RENDER_TILE_ATTR_FULL(RENDER_PAL0, 0, 0, 0, BLANK_TILE);
            } else {
                /* sparse_lut returns SLOT INDEX (0-based into atlas). Real
                 * VRAM tile = ROOMROM_BG_TILE_BASE (1) + slot. Per ow_render.c:295
                 * tile_word: return (ROOMROM_BG_TILE_BASE + slot). */
                unsigned short vram_tile = (unsigned short)(1u + slot);
                attr = RENDER_TILE_ATTR_FULL(RENDER_PAL0, 0, 0, 0, vram_tile);
            }
            cells[col] = attr;
        }
        render_plane_a_write_row(row, cells, 16u);
    }
}

/* Populate SAT 0..63 with 8x8 sprite grid. Slot S shows sprite tile
 * (s_sprite_page * 64 + S) in current sub_pal, at y=$80 + (S>>3)*16,
 * x=(S&7)*16. Slots 64..79 = link=0 terminator. */
/* SAT VRAM base. Title context sets VDP reg 5 = $7C (debug_enter_title in
 * src/debug/a4_probe_main.c:99) -> SAT at $F800. Gameplay context relocates
 * to $F400. We enter debug from title so use $F800. */
#define SAT_VRAM_BASE 0xF800u

static void redraw_sat(void) {
    /* Direct VRAM SAT write bypassing SGDK SAT cache + DMA queue. The
     * native intro context doesn't run SGDK VBlank handler so the queue
     * is never drained — sprites set via render_set_sprite_full never
     * land. Direct VDP writes are synchronous + immediately visible. */
    unsigned char slot;
    render_vram_open_write(SAT_VRAM_BASE);
    for (slot = 0u; slot < 80u; slot++) {
        if (slot < 64u) {
            /* Genesis sprite atlas tile_base = 533. NES sprite tile_id N
             * -> Genesis VRAM tile slot 533 + N. */
            unsigned short tile = (unsigned short)(533u + s_sprite_page * 64u + slot);
            unsigned short y = (unsigned short)(0x80u + ((slot >> 3) * 16u) + 0x80u);
            unsigned short x = (unsigned short)((slot & 7u) * 16u + 0x80u);
            unsigned short size_link = (s_8x16 ? RENDER_SPRITE_SIZE(1, 2)
                                                : RENDER_SPRITE_SIZE(1, 1)) << 8;
            size_link |= (slot < 63u) ? (slot + 1u) : 0u;
            unsigned short attr = RENDER_TILE_ATTR_FULL(RENDER_PAL1 + s_subpal,
                                                        0, 0, 0, tile);
            *((volatile unsigned short *)0xC00000) = y;
            *((volatile unsigned short *)0xC00000) = size_link;
            *((volatile unsigned short *)0xC00000) = attr;
            *((volatile unsigned short *)0xC00000) = x;
        } else {
            /* Clear leftover title sprites in slots 64..79. */
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
        }
    }
}

/* Edge-detect helper: returns non-zero if `mask` bit is set in curr but
 * not in prev. */
static unsigned char edge(unsigned char curr, unsigned char prev,
                          unsigned char mask) {
    return (unsigned char)((curr & mask) & ~(prev & mask));
}

void debug_tilegrid_main(void) {
    /* Sentinel write so a RAM Watch on $FF07F5 confirms entry. */
    *((volatile unsigned char *)0xFF07F5) = 0xDB;

    /* Upload gameplay atlas to VRAM — title context has only title CHR,
     * so bg_sparse_tile_lut slots point at title art unless we load the
     * gameplay atlas. Match what scene_load does during gameplay init. */
    roomrom_ow_room_render_upload_chr();   /* BG sparse atlas (532 tiles) */
    roomrom_sprites_upload_chr();          /* SPR common + ITEM atlas */
    roomrom_bg_palette_load_palram_full(g_roomrom_ow_palram[0]);  /* orig OW */

    /* Ensure CRAM[0] (global backdrop / PAL0 entry 0) is black. */
    *((volatile unsigned long *)0xC00004) = 0xC0000000UL;
    *((volatile unsigned short *)0xC00000) = 0x0000;

    /* Synchronously write 32 zero bytes to VRAM tile slot 1000 ($7D00).
     * Direct CPU write — bypasses DMA queue so result is visible before
     * we render plane A. This becomes our guaranteed-blank tile for fill. */
    {
        /* VDP CTRL formula for VRAM write at addr A:
         *   ctrl = (0x40000000 | ((A & 0x3FFF) << 16) | ((A & 0xC000) >> 14))
         * For A = $7D00:
         *   addr_lo = $7D00 & 0x3FFF = $3D00
         *   addr_hi = ($7D00 & 0xC000) >> 14 = 1
         *   ctrl    = 0x40000000 | (0x3D00 << 16) | 0x00000001 = 0x7D000001 ? wrong
         * Cleaner: use render_vram_open_write helper. */
        render_vram_open_write((unsigned short)(1000u * 32u));
        unsigned short i;
        for (i = 0; i < 16u; i++) {
            *((volatile unsigned short *)0xC00000) = 0x0000;
        }
    }

    redraw_bg();
    redraw_sat();

    /* Sentinel so probe can detect debug scene is live. */
    *((volatile unsigned char *)(0x00FF0000UL + POKE_FLAG)) = 0x00u;

    for (;;) {
        /* Lua-poke path: if probe wrote $FF07E4 = $AA, apply $FF07E0..3
         * state and clear flag. Mirrors button-press behavior but skips
         * edge-detect timing. Uses direct $FFxxxx addresses (no nes_ram
         * mirror struct in scope). */
        volatile unsigned char *flag = (volatile unsigned char *)(0x00FF0000UL + POKE_FLAG);
        if (*flag == 0xAAu) {
            volatile unsigned char *bank   = (volatile unsigned char *)(0x00FF0000UL + POKE_BANK);
            volatile unsigned char *subpal = (volatile unsigned char *)(0x00FF0000UL + POKE_SUBPAL);
            volatile unsigned char *page   = (volatile unsigned char *)(0x00FF0000UL + POKE_PAGE);
            volatile unsigned char *m8x16  = (volatile unsigned char *)(0x00FF0000UL + POKE_8X16);
            s_bank        = *bank   & 0x07u;
            s_subpal      = *subpal & 0x03u;
            s_sprite_page = *page   & 0x03u;
            s_8x16        = *m8x16  & 0x01u;
            upload_bank();
            redraw_bg();
            redraw_sat();
            *flag = 0x00u;   /* ack */
        }

        unsigned char base, ext;
        joy_read6(&base, &ext);

        /* A button -> cycle 8-bank state machine matching NES test ROM. */
        if (edge(base, s_joy_prev, JB_A)) {
            s_bank = (unsigned char)((s_bank + 1u) & 0x07u);
            upload_bank();
            redraw_bg();
            redraw_sat();
        }
        /* B button -> cycle sub_pal (mirrors NES B). */
        if (edge(base, s_joy_prev, JB_B)) {
            s_subpal = (unsigned char)((s_subpal + 1u) & 0x03u);
            redraw_bg();
            redraw_sat();
        }
        /* Start -> cycle sprite-page (mirrors NES Start). */
        if (edge(base, s_joy_prev, JB_START)) {
            s_sprite_page = (unsigned char)((s_sprite_page + 1u) & 0x03u);
            redraw_sat();
        }
        /* C button -> toggle 8x16 (Genesis has no Select; C is the
         * 3-button-safe alternative). Mirrors NES Select. */
        if (edge(base, s_joy_prev, JB_C)) {
            s_8x16 ^= 1u;
            redraw_sat();
        }

        s_joy_prev  = base;
        s_joyx_prev = ext;

        /* Spin a few frames between polls so SGDK DMA / SAT updates land. */
        volatile unsigned short i;
        for (i = 0u; i < 200u; i++) { /* idle */ }
    }
}
