#ifndef GAME_OW_SCROLL_H
#define GAME_OW_SCROLL_H

/* Host scroll directions: right, left, down, up. Zero means no edge;
 * 0x80 blocks movement at an outer map edge without starting a scroll. */
unsigned char ow_scroll_edge(short x, short y, unsigned char nes_dir,
                             signed char grid, unsigned char room);
void ow_scroll_begin(unsigned char direction, unsigned char target);
/* Advances leave / prepare / scroll / enter. Returns 1 when play resumes. */
unsigned char ow_scroll_tick(short *x, short *y);
/* Native renderer stages one column on each of the first 16 prepare ticks. */
unsigned char ow_scroll_column(void); /* 0..15, or 0xff */
unsigned short ow_scroll_pixels(void);
#endif
