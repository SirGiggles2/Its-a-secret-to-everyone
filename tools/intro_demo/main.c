/* intro_demo/main.c — standalone story + item-showcase scroll demo.
 *
 * Sequence (loops forever, no input):
 *   1. Story scroll  — intro_story_tilemap, 30 rows, scrolls upward
 *   2. Showcase scroll — intro_showcase_tilemap, 30 rows, follows immediately
 *   3. Loop back to (1)
 *
 * Pure Genesis hardware. No NES emulation, no shell, no transpile. */

#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

extern const unsigned char  intro_common_bg_chr[];
extern const unsigned long  intro_common_bg_chr_size;
extern const unsigned char  intro_font_chr[];      /* DemoBackgroundPatterns */
extern const unsigned long  intro_font_chr_size;
extern const unsigned char  intro_sprite_chr[];    /* Common+Demo sprite CHR */
extern const unsigned long  intro_sprite_chr_size;
extern const unsigned char  intro_misc_chr[];      /* CommonMiscPatterns ($F2-$FF BG tiles) */
extern const unsigned long  intro_misc_chr_size;
extern const unsigned char  intro_punct_chr[];     /* Custom comma + apostrophe (Gen tiles 512-513) */
extern const unsigned long  intro_punct_chr_size;
extern const unsigned char  intro_blink_chr[];     /* Heart/container/triforce/rupee, color-shifted */
extern const unsigned long  intro_blink_chr_size;
extern const unsigned short intro_demo_palette_cycles[14][12];  /* Z_02 DemoPhase0Subphase1 */
extern const unsigned char  intro_demo_palette_delays[14];
extern const unsigned short intro_combined_palette[64];
extern const unsigned short intro_story_tilemap_rows;
extern const unsigned short intro_story_tilemap[];
extern const unsigned short intro_showcase_tilemap_rows;
extern const unsigned short intro_showcase_tilemap[];
extern const unsigned short intro_treasures_tilemap_rows;
extern const unsigned short intro_treasures_tilemap[];

#define PLANE_A_BASE 0xC000u

static void vram_write_open(unsigned short dst) {
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(dst & 0x3FFF) << 16)
                  | ((dst >> 14) & 0x0003);
}

static void vram_upload(const unsigned char *src, unsigned long bytes,
                        unsigned short dst) {
    const unsigned short *p = (const unsigned short *)src;
    unsigned long words = bytes >> 1;
    vram_write_open(dst);
    while (words--) VDP_DATA_WORD = *p++;
}

static void cram_upload(const unsigned short *src, unsigned short count) {
    VDP_CTRL_LONG = 0xC0000000UL;
    while (count--) VDP_DATA_WORD = *src++;
}

/* Write a single CRAM word at the given palette slot index (0..63). */
static void cram_write_one(unsigned short slot, unsigned short value) {
    unsigned long addr = (unsigned long)slot * 2u;
    VDP_CTRL_LONG = 0xC0000000UL
                  | ((addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
    VDP_DATA_WORD = value;
}

static void vsram_set0(unsigned short value) {
    VDP_CTRL_LONG = 0x40000010UL;
    VDP_DATA_WORD = value;
}

static void write_row(unsigned short row, const unsigned short *cells) {
    unsigned short addr = (unsigned short)(PLANE_A_BASE + row * 64);
    vram_write_open(addr);
    for (int i = 0; i < 32; i++) VDP_DATA_WORD = cells[i];
}

static void write_blank_row(unsigned short row) {
    unsigned short addr = (unsigned short)(PLANE_A_BASE + row * 64);
    vram_write_open(addr);
    for (int i = 0; i < 32; i++) VDP_DATA_WORD = 0x0024;
}

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));   /* skip if currently in VBlank */
    while (!(VDP_CTRL_WORD & 0x0008));   /* wait for VBlank to begin */
}

static void vram_clear(void) {
    vram_write_open(0x0000);
    for (unsigned long i = 0; i < 32768; i++) VDP_DATA_WORD = 0x0000;
}

static void plane_fill_blank(unsigned short base) {
    vram_write_open(base);
    for (unsigned short i = 0; i < 32 * 32; i++) VDP_DATA_WORD = 0x0024;
}

/* Sequence (post-fade simulation): story hold 260 frames -> scroll up ->
 * GAP_ROWS blank between story and treasures -> treasures -> bottom pause
 * -> loop. NES reference: story stop f1445->f1705 = 260 frames hold; gap
 * measured ~6 rows from f1830 (treasures appear) vs f1705 (scroll-off
 * start) = 125 frames * 0.5 px/frame = 62 px ~= 7 rows; use 6 to overlap
 * a touch. */
#define GAP_ROWS 6
#define STORY_HOLD_FRAMES 260u

static const unsigned short *fetch_row(unsigned short n) {
    if (n < intro_story_tilemap_rows)
        return &intro_story_tilemap[n * 32];
    n = (unsigned short)(n - intro_story_tilemap_rows);
    if (n < GAP_ROWS) return 0;   /* blank gap between story and treasures */
    n = (unsigned short)(n - GAP_ROWS);
    if (n < intro_treasures_tilemap_rows)
        return &intro_treasures_tilemap[n * 32];
    return 0;   /* blank tail */
}

int main(void) {
    vram_clear();

    /* CHR uploads. */
    vram_upload(intro_common_bg_chr, intro_common_bg_chr_size, 0x0000);
    vram_upload(intro_font_chr,      intro_font_chr_size,      0x0E00);
    /* Sprite CHR -> Genesis tiles 256-511 at VRAM $2000. Used for icons in
     * the treasures scroll. Cell tile-index field is 11 bits so tiles 256+
     * are addressable. */
    vram_upload(intro_sprite_chr,    intro_sprite_chr_size,    0x2000);

    /* Misc CHR -> Genesis tiles 242-255 at VRAM $1E40 (= 242*32). Holds
     * NES BG pattern tiles $F2-$FF (CommonMiscPatterns). 8x16-mode items
     * with odd tile numbers (e.g. HEART tile $F3) reference these via the
     * BG-pattern-table side. */
    vram_upload(intro_misc_chr,      intro_misc_chr_size,      0x1E40);

    /* Custom punctuation tiles (comma, apostrophe) -> Gen tile 512 at VRAM $4000.
     * Used by GameCube-version story scroll text. */
    vram_upload(intro_punct_chr,     intro_punct_chr_size,     0x4000);

    /* Blink CHR (heart $F2/$F3, container $68/$69, triforce $6E/$6F,
     * rupee $32/$33) re-encoded with color_shift=8 -> Gen tiles 514-521
     * at VRAM $4040. Pixels reference pal slots 8-11; only this region
     * animates, isolating flash from non-flashing items at slots 4-7.
     * Container/triforce currently unused (future work).
     *   514/515: heart top/bot
     *   516/517: container top/bot (reserved)
     *   518/519: triforce top/bot (reserved)
     *   520/521: rupee top/bot */
    vram_upload(intro_blink_chr,     intro_blink_chr_size,     0x4040);

    /* Combined palette: slots 0-3 = story BG palettes; slots 4-7 = NES
     * sprite palettes. Story tiles use slots 0-3; item icons use 4-7
     * (sprite CHR was re-encoded with color_shift=4). */
    cram_upload(intro_combined_palette, 64);

    /* Heart-flash colors. NES Z_07.asm:878 DrawItemBySlot @Flash flips
     * the heart sprite's palette index between NES sprite pal 1 (blue)
     * and sprite pal 2 (red) every 8 frames (FrameCounter bit 3).
     * Phase-1 PALRAM (palram_2050) shows:
     *   sprite pal 1: $00 $02 $22 $30 = backdrop, blue, lt-blue, white
     *   sprite pal 2: $00 $16 $27 $30 = backdrop, red, orange, white
     * Heart art (intro_blink_chr.c, color_shift=8) references slots 9-11
     * of cell's palette. Load NES sprite pal 1 colors into pal2[9..11]
     * and NES sprite pal 2 colors into pal3[9..11]. Animation toggles the
     * heart cell's palette field 2<->3 each 8 frames; CRAM stays static. */
    cram_write_one((unsigned short)(2*16 + 9),  0x0C02);
    cram_write_one((unsigned short)(2*16 + 10), 0x0E88);
    cram_write_one((unsigned short)(2*16 + 11), 0x0EEE);
    cram_write_one((unsigned short)(3*16 + 9),  0x002C);
    cram_write_one((unsigned short)(3*16 + 10), 0x008E);
    cram_write_one((unsigned short)(3*16 + 11), 0x0EEE);

    /* Initial plane fills + story rows pre-written. */
    plane_fill_blank(0xC000);
    plane_fill_blank(0xE000);

    {
        unsigned short rows = intro_story_tilemap_rows < 32
                              ? intro_story_tilemap_rows : 32;
        unsigned short r;
        for (r = 0; r < rows; r++) {
            write_row(r, &intro_story_tilemap[r * 32]);
        }
    }

    vsram_set0(0);
    VDP_CTRL_WORD = 0x8174;   /* display ON */

    /* Total source content = story + showcase (60 rows for our data).
     * After all rows scrolled past + visible region cleared = restart. */
    {
        unsigned short total_rows = (unsigned short)(intro_story_tilemap_rows
                                                   + GAP_ROWS
                                                   + intro_treasures_tilemap_rows);
        unsigned short scroll = 0;
        unsigned short last_row = 0;
        unsigned short next_source_row = (unsigned short)intro_story_tilemap_rows;
        unsigned short story_pause = STORY_HOLD_FRAMES;
        unsigned short end_pause = 0;
        unsigned char  end_pause_armed = 0;

        /* Pixels of total scroll before we reset:
         * = total_rows * 8 + 32 * 8  (content + visible window)
         * Use a 16-bit counter that wraps naturally; track the row index
         * via integer division. */
        unsigned long total_pixels = (unsigned long)total_rows * 8u + 32u * 8u;
        unsigned long pixel_count = 0;

        unsigned char tick = 0;

        /* Item visibility windows are derived from each item's content
         * row (= story_rows + GAP_ROWS + treasures_row). With GAP_ROWS=6:
         *   Heart    treasures row 7  -> content 43 -> plane[13] y=104
         *   Fairy    treasures row 16 -> content 52 -> plane[22] y=176
         *   Rupee    treasures row 24 -> content 60 -> plane[30] y=240
         *   Triforce treasures row 153 -> content 189 -> plane[31] y=248
         *            (bot wraps to plane[0] y=0)
         * Visible scroll range = (plane_y - scroll) mod 256 in [0, 223]
         * intersected with the scroll range during which plane row holds
         * the item content. */
        unsigned long heart_visible_start = 137u;
        unsigned long heart_visible_end   = 368u;
        unsigned long fairy_visible_start = 209u;
        unsigned long fairy_visible_end   = 440u;
        unsigned long rupee_visible_start = 273u;
        unsigned long rupee_visible_end   = 504u;
        unsigned long triforce_visible_start = 1305u;
        unsigned long triforce_visible_end   = 1536u;
        /* NES Z_07.asm:888 @Flash: palette toggles via FrameCounter
         * bit 3 — 8 frames pal 1 (blue), 8 frames pal 2 (red), repeat.
         * Each item animates independently (separate counters since
         * they may overlap on screen during scroll). */
        unsigned char heart_frame_counter = 0;
        unsigned char heart_last_pal_bit  = 0xFF;
        unsigned char rupee_frame_counter = 0;
        unsigned char rupee_last_pal_bit  = 0xFF;
        unsigned char triforce_frame_counter = 0;
        unsigned char triforce_last_pal_bit  = 0xFF;
        unsigned char fairy_frame_counter = 0;
        unsigned char fairy_last_frame_bit = 0xFF;

        /* End-pause threshold: when scroll has advanced enough that the
         * TRIFORCE + "PLEASE LOOK UP" rows have settled into the visible
         * window, hold for ~180 frames (NES-measured 3 sec). */
        unsigned long end_pause_threshold =
            (unsigned long)(total_rows - 28) * 8u;

        for (;;) {
            wait_vblank();

            /* Item flash: NES Z_07 toggles flashing-item sprite palette
             * index each 8 frames (FrameCounter bit 3). Replicate by
             * rewriting the cell's palette field 2<->3. Pal 2 slots 9-11
             * hold NES sprite pal 1 (blue); pal 3 slots 9-11 hold NES
             * sprite pal 2 (red). Heart and rupee animate independently. */
            {
                /* Strict-less for end: anim fires every vblank, but the
                 * scroll-write that clears plane row of heart fires only
                 * on tick=1 frames. Using <= lets anim fire AFTER the
                 * scroll-write same boundary, leaving heart in plane to
                 * show again when plane wraps. <= would re-stamp heart. */
                unsigned char heart_visible =
                    (pixel_count >= heart_visible_start)
                    && (pixel_count < heart_visible_end);
                if (heart_visible) {
                    heart_frame_counter++;
                    unsigned char pal_bit = (heart_frame_counter >> 3) & 1u;
                    if (pal_bit != heart_last_pal_bit) {
                        heart_last_pal_bit = pal_bit;
                        unsigned short pal_field = pal_bit ? (3u << 13)
                                                           : (2u << 13);
                        /* heart top: plane[13] col 8 = $C350; bot: plane[14] = $C390 */
                        vram_write_open(0xC350u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 514u);
                        vram_write_open(0xC390u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 515u);
                    }
                }
                unsigned char rupee_visible =
                    (pixel_count >= rupee_visible_start)
                    && (pixel_count < rupee_visible_end);
                if (rupee_visible) {
                    rupee_frame_counter++;
                    unsigned char pal_bit = (rupee_frame_counter >> 3) & 1u;
                    if (pal_bit != rupee_last_pal_bit) {
                        rupee_last_pal_bit = pal_bit;
                        unsigned short pal_field = pal_bit ? (3u << 13)
                                                           : (2u << 13);
                        /* rupee top: plane[30] col 8 = $C790; bot: plane[31] = $C7D0 */
                        vram_write_open(0xC790u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 520u);
                        vram_write_open(0xC7D0u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 521u);
                    }
                }
                /* Fairy frame swap (NES Z_02 AnimateStationaryFairy):
                 * tile $50/$51 <-> $52/$53 every 4 frames. Cell pal stays
                 * at 3 (NES sprite pal 2 = red). */
                unsigned char fairy_visible =
                    (pixel_count >= fairy_visible_start)
                    && (pixel_count < fairy_visible_end);
                if (fairy_visible) {
                    fairy_frame_counter++;
                    unsigned char frame_bit = (fairy_frame_counter >> 2) & 1u;
                    if (frame_bit != fairy_last_frame_bit) {
                        fairy_last_frame_bit = frame_bit;
                        unsigned short pal_field = (3u << 13);
                        unsigned short top_tile = frame_bit ? 338u : 336u;
                        unsigned short bot_tile = frame_bit ? 339u : 337u;
                        /* fairy top: plane[22] col 8 = $C590; bot: $C5D0 */
                        vram_write_open(0xC590u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | top_tile);
                        vram_write_open(0xC5D0u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | bot_tile);
                    }
                }
                unsigned char triforce_visible =
                    (pixel_count >= triforce_visible_start)
                    && (pixel_count < triforce_visible_end);
                if (triforce_visible) {
                    triforce_frame_counter++;
                    unsigned char pal_bit = (triforce_frame_counter >> 3) & 1u;
                    if (pal_bit != triforce_last_pal_bit) {
                        triforce_last_pal_bit = pal_bit;
                        unsigned short pal_field = pal_bit ? (3u << 13)
                                                           : (2u << 13);
                        unsigned short hflip = (unsigned short)(1u << 11);
                        /* Triforce top in plane[31], bot wraps to plane[0].
                         * plane[31] col 15 = $C7DE, col 16 = $C7E0
                         * plane[0]  col 15 = $C01E, col 16 = $C020 */
                        vram_write_open(0xC7DEu);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 518u);
                        vram_write_open(0xC7E0u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 518u | hflip);
                        vram_write_open(0xC01Eu);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 519u);
                        vram_write_open(0xC020u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 519u | hflip);
                    }
                }
            }

            /* Initial story pause: hold scroll at 0 so the reader can read
             * the story before it starts scrolling up. NES = ~250 frames. */
            if (story_pause) { story_pause--; continue; }
            /* End-pause: hold TRIFORCE/manual on screen briefly. */
            if (end_pause) { end_pause--; continue; }
            /* Arm end-pause when scroll first reaches threshold. */
            if (!end_pause_armed && pixel_count >= end_pause_threshold) {
                end_pause = 180;
                end_pause_armed = 1;
                continue;
            }
            /* NES rate = 0.5 px/frame. Advance scroll only every other frame. */
            tick ^= 1;
            if (!tick) continue;
            scroll++;
            pixel_count++;
            vsram_set0(scroll);

            /* Row-boundary detection: every 8 px, a new source row enters. */
            unsigned short new_row = (unsigned short)(pixel_count >> 3);
            if (new_row != last_row) {
                unsigned short plane_row = (unsigned short)(last_row & 31u);
                const unsigned short *src = fetch_row(next_source_row);
                if (src) {
                    write_row(plane_row, src);
                } else {
                    write_blank_row(plane_row);
                }
                next_source_row++;
                last_row = new_row;
            }

            /* Restart cycle: rewrite story to plane, reset counters. */
            if (pixel_count >= total_pixels) {
                unsigned short rows = intro_story_tilemap_rows < 32
                                      ? intro_story_tilemap_rows : 32;
                unsigned short r;
                for (r = 0; r < rows; r++) {
                    write_row(r, &intro_story_tilemap[r * 32]);
                }
                /* Fill remaining plane rows with blank. */
                for (r = rows; r < 32; r++) write_blank_row(r);
                vsram_set0(0);
                scroll = 0;
                last_row = 0;
                next_source_row = (unsigned short)intro_story_tilemap_rows;
                pixel_count = 0;
                story_pause = 250;
                end_pause = 0;
                end_pause_armed = 0;
                /* Reset flash counters; CRAM stays — pal2/pal3 hold
                 * static blue/red. Cells will be redrawn by scroll
                 * when items re-enter and palette field will toggle. */
                heart_frame_counter = 0;
                heart_last_pal_bit  = 0xFF;
                rupee_frame_counter = 0;
                rupee_last_pal_bit  = 0xFF;
                triforce_frame_counter = 0;
                triforce_last_pal_bit  = 0xFF;
                fairy_frame_counter = 0;
                fairy_last_frame_bit = 0xFF;
            }
        }
    }
    return 0;
}
