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

/* Full intro sequence per NES timing reference:
 *   1. Fade-in 255 frames: CRAM ramps black -> target palette.
 *   2. Scroll-in: story enters from bottom at 0.5 px/frame, until story
 *      top reaches top-of-screen (scroll=224, ~448 frames; user-cited
 *      f1040 -> f1445 = 405 frames is approximate).
 *   3. Hold 260 frames at story-top-at-top.
 *   4. Scroll-off: continue at 0.5 px/frame, GAP_ROWS blank, then
 *      treasures.
 *
 * Content stream (used by fetch_row / streamed into plane during scroll):
 *   rows [0, PRE_BLANK_ROWS)   : pre-blank (off-screen above story init)
 *   rows [PRE_BLANK, PRE_BLANK+30) : story
 *   rows [..., +GAP_ROWS)      : blank gap
 *   rows [..., +treasures_rows): treasures
 *
 * PRE_BLANK=28 chosen so initial plane[0..27] = blank (nothing visible)
 * and plane[28..31] holds story rows 0..3 (just below screen, ready to
 * scroll up). */
#define PRE_BLANK_ROWS 28u
#define GAP_ROWS 6
#define FADE_FRAMES 255u
#define STORY_HOLD_FRAMES 260u
#define STORY_SCROLL_TARGET 216u  /* story top stops 1 row below top of screen */

static const unsigned short *fetch_row(unsigned short n) {
    if (n < PRE_BLANK_ROWS) return 0;        /* pre-blank padding */
    n = (unsigned short)(n - PRE_BLANK_ROWS);
    if (n < intro_story_tilemap_rows)
        return &intro_story_tilemap[n * 32];
    n = (unsigned short)(n - intro_story_tilemap_rows);
    if (n < GAP_ROWS) return 0;              /* blank gap between story and treasures */
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

    /* Build target palette in RAM: combined palette + heart/rupee/triforce
     * flash colors (NES sprite pal 1 in pal2[9..11], NES sprite pal 2 in
     * pal3[9..11]). Used both for fade ramp source and final state. */
    static unsigned short target_pal[64];
    {
        unsigned short i;
        for (i = 0; i < 64; i++) target_pal[i] = intro_combined_palette[i];
        target_pal[2*16 + 9]  = 0x0C02;
        target_pal[2*16 + 10] = 0x0E88;
        target_pal[2*16 + 11] = 0x0EEE;
        target_pal[3*16 + 9]  = 0x002C;
        target_pal[3*16 + 10] = 0x008E;
        target_pal[3*16 + 11] = 0x0EEE;
    }

    /* CRAM starts all black for fade-in. */
    {
        VDP_CTRL_LONG = 0xC0000000UL;
        unsigned short i;
        for (i = 0; i < 64; i++) VDP_DATA_WORD = 0x0000;
    }

    /* Initial plane fill + first 32 stream rows pre-written.
     * fetch_row(0..27) = blank (pre-blank padding); fetch_row(28..31) =
     * story rows 0..3 (parked just below the visible window, ready to
     * scroll up at scroll>=1). */
    plane_fill_blank(0xC000);
    plane_fill_blank(0xE000);

    {
        unsigned short r;
        for (r = 0; r < 32; r++) {
            const unsigned short *src = fetch_row(r);
            if (src) write_row(r, src);
            else write_blank_row(r);
        }
    }

    vsram_set0(0);
    VDP_CTRL_WORD = 0x8174;   /* display ON (CRAM black -> screen black) */

    /* Fade-in: stepped CRAM ramp using bit-mask approach (avoids 32-bit
     * multiply, no libgcc available). 4 levels over FADE_FRAMES vblanks:
     *   level 0 (0..63 frames):    mask 0x0000  (all black)
     *   level 1 (64..127):         mask 0x0888  (top bit per channel)
     *   level 2 (128..191):        mask 0x0CCC  (top 2 bits)
     *   level 3 (192..254):        mask 0x0EEE  (all 3 bits = full)
     * NES uses PPU emphasis bits (also stepped); 4 levels visually fine. */
    {
        static const unsigned short fade_masks[4] = {
            0x0000u, 0x0888u, 0x0CCCu, 0x0EEEu
        };
        unsigned short level;
        for (level = 0; level < 4u; level++) {
            unsigned short mask = fade_masks[level];
            /* Apply this level: write CRAM with target & mask. */
            VDP_CTRL_LONG = 0xC0000000UL;
            unsigned short i;
            for (i = 0; i < 64; i++) VDP_DATA_WORD = (unsigned short)(target_pal[i] & mask);
            /* Hold for FADE_FRAMES/4 vblanks. */
            unsigned short level_frames = (unsigned short)(FADE_FRAMES / 4u);
            while (level_frames--) {
                while ( (VDP_CTRL_WORD & 0x0008));
                while (!(VDP_CTRL_WORD & 0x0008));
            }
        }
        /* Snap to final target. */
        VDP_CTRL_LONG = 0xC0000000UL;
        unsigned short i;
        for (i = 0; i < 64; i++) VDP_DATA_WORD = target_pal[i];
    }

    /* Total source content = pre-blank + story + gap + treasures rows.
     * After all rows scrolled past + visible region cleared = restart. */
    {
        unsigned short total_rows = (unsigned short)(PRE_BLANK_ROWS
                                                   + intro_story_tilemap_rows
                                                   + GAP_ROWS
                                                   + intro_treasures_tilemap_rows);
        unsigned short scroll = 0;
        unsigned short last_row = 0;
        unsigned short next_source_row = 32u;     /* first 32 stream rows pre-written */
        unsigned short story_hold = 0;
        unsigned char  story_hold_armed = 0;
        unsigned short end_pause = 0;
        unsigned char  end_pause_armed = 0;

        unsigned long total_pixels = (unsigned long)total_rows * 8u + 32u * 8u;
        unsigned long pixel_count = 0;

        unsigned char tick = 0;

        /* Item visibility windows for content stream with PRE_BLANK=28,
         * GAP_ROWS=6:
         *   Heart    treasures row 7   -> content 71  -> plane[7]  y=56
         *   Fairy    treasures row 16  -> content 80  -> plane[16] y=128
         *   Rupee    treasures row 24  -> content 88  -> plane[24] y=192
         *   Triforce treasures row 153 -> content 217 -> plane[25] y=200
         *            (bot wraps to plane[26] y=208)
         * Visible scroll range = (plane_y - scroll) mod 256 in [0, 223]
         * intersected with the scroll range during which plane row holds
         * the item content. Heart/rupee top in plane[N], bot plane[N+1].
         * Triforce mirrored 4-cell at cols 15-16 of plane[25]/[26]. */
        unsigned long heart_visible_start = 345u;
        unsigned long heart_visible_end   = 576u;
        unsigned long fairy_visible_start = 417u;
        unsigned long fairy_visible_end   = 648u;
        unsigned long rupee_visible_start = 481u;
        unsigned long rupee_visible_end   = 712u;
        unsigned long triforce_visible_start = 1513u;
        unsigned long triforce_visible_end   = 1744u;
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
                        /* heart top: plane[7] col 8 = $C1D0; bot: plane[8] = $C210 */
                        vram_write_open(0xC1D0u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 514u);
                        vram_write_open(0xC210u);
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
                        /* rupee top: plane[24] col 8 = $C610; bot: plane[25] = $C650 */
                        vram_write_open(0xC610u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 520u);
                        vram_write_open(0xC650u);
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
                        /* fairy top: plane[16] col 8 = $C410; bot: plane[17] = $C450 */
                        vram_write_open(0xC410u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | top_tile);
                        vram_write_open(0xC450u);
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
                        /* Triforce top plane[25], bot plane[26], cols 15-16.
                         * plane[25] col 15 = $C65E, col 16 = $C660
                         * plane[26] col 15 = $C69E, col 16 = $C6A0 */
                        vram_write_open(0xC65Eu);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 518u);
                        vram_write_open(0xC660u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 518u | hflip);
                        vram_write_open(0xC69Eu);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 519u);
                        vram_write_open(0xC6A0u);
                        VDP_DATA_WORD = (unsigned short)(pal_field | 519u | hflip);
                    }
                }
            }

            /* Story scroll-in -> hold transition: when scroll first reaches
             * STORY_SCROLL_TARGET (story top at top of screen), hold for
             * STORY_HOLD_FRAMES. Matches NES f1445 -> f1705 pause. */
            if (!story_hold_armed && pixel_count >= STORY_SCROLL_TARGET) {
                story_hold = STORY_HOLD_FRAMES;
                story_hold_armed = 1;
            }
            if (story_hold) { story_hold--; continue; }
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

            /* Restart cycle: re-write first 32 stream rows to plane,
             * reset counters. (Skips fade-in on loop — instant restart.) */
            if (pixel_count >= total_pixels) {
                unsigned short r;
                for (r = 0; r < 32; r++) {
                    const unsigned short *src = fetch_row(r);
                    if (src) write_row(r, src);
                    else write_blank_row(r);
                }
                vsram_set0(0);
                scroll = 0;
                last_row = 0;
                next_source_row = 32u;
                pixel_count = 0;
                story_hold = 0;
                story_hold_armed = 0;
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
