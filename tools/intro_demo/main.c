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

/* Sequence: story -> blank gap (~NES black-fade duration, 12 rows) -> treasures
 * -> bottom pause -> loop. With combined CRAM, no palette swap needed. */
#define GAP_ROWS 12

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

    /* Combined palette: slots 0-3 = story BG palettes; slots 4-7 = NES
     * sprite palettes. Story tiles use slots 0-3; item icons use 4-7
     * (sprite CHR was re-encoded with color_shift=4). */
    cram_upload(intro_combined_palette, 64);

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
        unsigned short story_pause = 250;
        unsigned short end_pause = 0;
        unsigned char  end_pause_armed = 0;

        /* Pixels of total scroll before we reset:
         * = total_rows * 8 + 32 * 8  (content + visible window)
         * Use a 16-bit counter that wraps naturally; track the row index
         * via integer division. */
        unsigned long total_pixels = (unsigned long)total_rows * 8u + 32u * 8u;
        unsigned long pixel_count = 0;

        unsigned char tick = 0;

        /* End-pause threshold: when scroll has advanced enough that the
         * TRIFORCE + "PLEASE LOOK UP" rows have settled into the visible
         * window, hold for ~180 frames (NES-measured 3 sec). */
        unsigned long end_pause_threshold =
            (unsigned long)(total_rows - 28) * 8u;

        for (;;) {
            wait_vblank();
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
            }
        }
    }
    return 0;
}
