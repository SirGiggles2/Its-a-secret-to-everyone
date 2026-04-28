/* src/intro_story.c
 *
 * Story + items runtime extracted verbatim from pre-phase-machine
 * main.c (commit f246e71d). Preserves scroll-in, hold, scroll-off,
 * end pause, and item flash behavior. The fade-in step from the old
 * main.c is removed; the title phase already left the screen black
 * and PHASE_STORY_LOAD snaps the story palette in.
 *
 * IMPORTANT: heart-flash CRAM slots (pal 2 / pal 3 slots 9-11) get
 * clobbered by the title fade-out. intro_story_load() restores
 * them along with the combined palette upload.
 */
#include "intro_story.h"

#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

/* m_song_loop_pending in audio_driver.asm — set to 1 by tick_sq1.song_ended
 * each time the song script reads its $00 loop opcode. End-of-scroll
 * hold polls this so the snap-back to title syncs with the music loop. */
#define M_SONG_LOOP_PENDING (*(volatile unsigned char *)0x00FFE02B)

extern const unsigned char  intro_common_bg_chr[];
extern const unsigned long  intro_common_bg_chr_size;
extern const unsigned char  intro_font_chr[];
extern const unsigned long  intro_font_chr_size;
extern const unsigned char  intro_sprite_chr[];
extern const unsigned long  intro_sprite_chr_size;
extern const unsigned char  intro_misc_chr[];
extern const unsigned long  intro_misc_chr_size;
extern const unsigned char  intro_punct_chr[];
extern const unsigned long  intro_punct_chr_size;
extern const unsigned char  intro_blink_chr[];
extern const unsigned long  intro_blink_chr_size;
extern const unsigned short intro_combined_palette[64];
extern const unsigned short intro_story_tilemap_rows;
extern const unsigned short intro_story_tilemap[];
extern const unsigned short intro_treasures_tilemap_rows;
extern const unsigned short intro_treasures_tilemap[];

#define PRE_BLANK_ROWS       28u
#define GAP_ROWS             6
#define STORY_HOLD_FRAMES    260u
#define STORY_SCROLL_TARGET  216u
#define PLANE_A_BASE         0xC000u

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

static void plane_fill_blank(unsigned short base) {
    vram_write_open(base);
    for (unsigned short i = 0; i < 32 * 32; i++) VDP_DATA_WORD = 0x0024;
}

static void vram_clear(void) {
    vram_write_open(0x0000);
    for (unsigned long i = 0; i < 32768; i++) VDP_DATA_WORD = 0x0000;
}

static const unsigned short *fetch_row(unsigned short n) {
    if (n < PRE_BLANK_ROWS) return 0;
    n = (unsigned short)(n - PRE_BLANK_ROWS);
    if (n < intro_story_tilemap_rows)
        return &intro_story_tilemap[n * 32];
    n = (unsigned short)(n - intro_story_tilemap_rows);
    if (n < GAP_ROWS) return 0;
    n = (unsigned short)(n - GAP_ROWS);
    if (n < intro_treasures_tilemap_rows)
        return &intro_treasures_tilemap[n * 32];
    return 0;
}

/* Item visibility windows — compile-time constants. */
#define HEART_VIS_START    345uL
#define HEART_VIS_END      576uL
#define FAIRY_VIS_START    417uL
#define FAIRY_VIS_END      648uL
#define RUPEE_VIS_START    481uL
#define RUPEE_VIS_END      712uL
#define TRIFORCE_VIS_START 1513uL
#define TRIFORCE_VIS_END   1744uL

/* Persistent state across intro_story_step(). All initialized to 0 (BSS);
 * non-zero initial values are written by intro_story_load() to keep the
 * linker .data section empty (linker script has no .data). */
static unsigned short s_total_rows;
static unsigned short s_scroll;
static unsigned short s_last_row;
static unsigned short s_next_source_row;
static unsigned short s_story_hold;
static unsigned char  s_story_hold_armed;
static unsigned short s_end_pause;
static unsigned char  s_end_pause_armed;
static unsigned long  s_total_pixels;
static unsigned long  s_pixel_count;
static unsigned char  s_tick;
static unsigned char  s_at_end;
static unsigned long  s_end_pause_threshold;

static unsigned char s_heart_frame_counter;
static unsigned char s_heart_last_pal_bit;
static unsigned char s_rupee_frame_counter;
static unsigned char s_rupee_last_pal_bit;
static unsigned char s_triforce_frame_counter;
static unsigned char s_triforce_last_pal_bit;
static unsigned char s_fairy_frame_counter;
static unsigned char s_fairy_last_frame_bit;

static void reset_counters(void) {
    s_scroll = 0;
    s_last_row = 0;
    s_next_source_row = 32u;
    s_pixel_count = 0;
    s_story_hold = 0;
    s_story_hold_armed = 0;
    s_end_pause = 0;
    s_end_pause_armed = 0;
    s_tick = 0;
    s_at_end = 0;
    s_heart_frame_counter = 0;
    s_heart_last_pal_bit  = 0xFF;
    s_rupee_frame_counter = 0;
    s_rupee_last_pal_bit  = 0xFF;
    s_triforce_frame_counter = 0;
    s_triforce_last_pal_bit  = 0xFF;
    s_fairy_frame_counter = 0;
    s_fairy_last_frame_bit = 0xFF;
}

void intro_story_load(void) {
    /* Display off during full re-upload. */
    VDP_CTRL_WORD = 0x8134;

    vram_clear();

    vram_upload(intro_common_bg_chr, intro_common_bg_chr_size, 0x0000);
    vram_upload(intro_font_chr,      intro_font_chr_size,      0x0E00);
    vram_upload(intro_sprite_chr,    intro_sprite_chr_size,    0x2000);
    vram_upload(intro_misc_chr,      intro_misc_chr_size,      0x1E40);
    vram_upload(intro_punct_chr,     intro_punct_chr_size,     0x4000);
    vram_upload(intro_blink_chr,     intro_blink_chr_size,     0x4040);

    /* Clear sprite list left over from title phase. Set sprite 0 to
     * Y=0 (off-screen) and link=0 (terminate). Genesis sprite table
     * lives at VRAM $F800 per boot.asm reg 5 = $7C. */
    vram_write_open(0xF800u);
    VDP_DATA_WORD = 0;     /* Y = 0 */
    VDP_DATA_WORD = 0;     /* size + link */
    VDP_DATA_WORD = 0;     /* attr/tile */
    VDP_DATA_WORD = 0;     /* X */

    /* CRAM: combined palette + heart-flash slot restoration (title fade
     * clobbered all 64 slots so we must rewrite). */
    cram_upload(intro_combined_palette, 64);
    cram_write_one((unsigned short)(2*16 + 9),  0x0C02);
    cram_write_one((unsigned short)(2*16 + 10), 0x0E88);
    cram_write_one((unsigned short)(2*16 + 11), 0x0EEE);
    cram_write_one((unsigned short)(3*16 + 9),  0x002C);
    cram_write_one((unsigned short)(3*16 + 10), 0x008E);
    cram_write_one((unsigned short)(3*16 + 11), 0x0EEE);

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

    s_total_rows = (unsigned short)(PRE_BLANK_ROWS
                                  + intro_story_tilemap_rows
                                  + GAP_ROWS
                                  + intro_treasures_tilemap_rows);
    s_total_pixels = (unsigned long)s_total_rows * 8u + 32u * 8u;
    /* Hold position: last 24 rows visible. 28 left MAP/COMPASS at the top
     * of the viewport; 24 scrolls them off so the held screen shows just
     * Triforce + sign + Link. */
    s_end_pause_threshold = (unsigned long)(s_total_rows - 24) * 8u;
    reset_counters();

    vsram_set0(0);
    VDP_CTRL_WORD = 0x8174;
}

void intro_story_step(void) {
    if (s_at_end) return;

    /* Item flash anims. */
    {
        unsigned char heart_visible =
            (s_pixel_count >= HEART_VIS_START)
            && (s_pixel_count < HEART_VIS_END);
        if (heart_visible) {
            s_heart_frame_counter++;
            unsigned char pal_bit = (s_heart_frame_counter >> 3) & 1u;
            if (pal_bit != s_heart_last_pal_bit) {
                s_heart_last_pal_bit = pal_bit;
                unsigned short pal_field = pal_bit ? (3u << 13) : (2u << 13);
                vram_write_open(0xC1D0u);
                VDP_DATA_WORD = (unsigned short)(pal_field | 514u);
                vram_write_open(0xC210u);
                VDP_DATA_WORD = (unsigned short)(pal_field | 515u);
            }
        }
        unsigned char rupee_visible =
            (s_pixel_count >= RUPEE_VIS_START)
            && (s_pixel_count < RUPEE_VIS_END);
        if (rupee_visible) {
            s_rupee_frame_counter++;
            unsigned char pal_bit = (s_rupee_frame_counter >> 3) & 1u;
            if (pal_bit != s_rupee_last_pal_bit) {
                s_rupee_last_pal_bit = pal_bit;
                unsigned short pal_field = pal_bit ? (3u << 13) : (2u << 13);
                vram_write_open(0xC610u);
                VDP_DATA_WORD = (unsigned short)(pal_field | 520u);
                vram_write_open(0xC650u);
                VDP_DATA_WORD = (unsigned short)(pal_field | 521u);
            }
        }
        unsigned char fairy_visible =
            (s_pixel_count >= FAIRY_VIS_START)
            && (s_pixel_count < FAIRY_VIS_END);
        if (fairy_visible) {
            s_fairy_frame_counter++;
            unsigned char frame_bit = (s_fairy_frame_counter >> 2) & 1u;
            if (frame_bit != s_fairy_last_frame_bit) {
                s_fairy_last_frame_bit = frame_bit;
                unsigned short pal_field = (3u << 13);
                unsigned short top_tile = frame_bit ? 338u : 336u;
                unsigned short bot_tile = frame_bit ? 339u : 337u;
                vram_write_open(0xC410u);
                VDP_DATA_WORD = (unsigned short)(pal_field | top_tile);
                vram_write_open(0xC450u);
                VDP_DATA_WORD = (unsigned short)(pal_field | bot_tile);
            }
        }
        unsigned char triforce_visible =
            (s_pixel_count >= TRIFORCE_VIS_START)
            && (s_pixel_count < TRIFORCE_VIS_END);
        if (triforce_visible) {
            s_triforce_frame_counter++;
            unsigned char pal_bit = (s_triforce_frame_counter >> 3) & 1u;
            if (pal_bit != s_triforce_last_pal_bit) {
                s_triforce_last_pal_bit = pal_bit;
                unsigned short pal_field = pal_bit ? (3u << 13) : (2u << 13);
                unsigned short hflip = (unsigned short)(1u << 11);
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

    /* Story scroll-in -> hold transition. */
    if (!s_story_hold_armed && s_pixel_count >= STORY_SCROLL_TARGET) {
        s_story_hold = STORY_HOLD_FRAMES;
        s_story_hold_armed = 1;
    }
    if (s_story_hold) { s_story_hold--; return; }

    /* End-of-scroll hold: when the last 28 rows are visible (Link sprite +
     * Triforce + manual sign), pause indefinitely until the song completes
     * a full loop, then snap back to title. Music engine sets
     * m_song_loop_pending in tick_sq1.song_ended. */
    if (!s_end_pause_armed && s_pixel_count >= s_end_pause_threshold) {
        s_end_pause_armed = 1;
        M_SONG_LOOP_PENDING = 0;   /* arm: clear flag, wait for next loop */
        return;
    }
    if (s_end_pause_armed) {
        if (M_SONG_LOOP_PENDING) {
            s_at_end = 1;          /* song looped — flip back to title */
        }
        return;                    /* hold viewport either way */
    }

    /* NES rate = 0.5 px/frame. */
    s_tick ^= 1;
    if (!s_tick) return;
    s_scroll++;
    s_pixel_count++;
    vsram_set0(s_scroll);

    /* Row-boundary detection. */
    unsigned short new_row = (unsigned short)(s_pixel_count >> 3);
    if (new_row != s_last_row) {
        unsigned short plane_row = (unsigned short)(s_last_row & 31u);
        const unsigned short *src = fetch_row(s_next_source_row);
        if (src) write_row(plane_row, src);
        else     write_blank_row(plane_row);
        s_next_source_row++;
        s_last_row = new_row;
    }

    /* Reached end of content? Signal phase machine to loop to title. */
    if (s_pixel_count >= s_total_pixels) {
        s_at_end = 1;
    }
}

unsigned char intro_story_at_end(void) {
    return s_at_end;
}

void intro_story_clear_end(void) {
    s_at_end = 0;
}
