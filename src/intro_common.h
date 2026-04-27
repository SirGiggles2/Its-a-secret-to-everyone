#ifndef INTRO_COMMON_H
#define INTRO_COMMON_H
#ifdef __cplusplus
extern "C" {
#endif
extern unsigned char g_intro_takeover;
unsigned char intro_should_take_over(void);
void intro_story_tick(void);
void vdp_set_mode_v32(void);
void vdp_set_mode_v64(void);
void vdp_dma_to_vram(unsigned long src, unsigned short dst, unsigned short len);
void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                             const unsigned short *cells);
void vdp_set_vscroll(unsigned short value);
void vdp_load_cram(const unsigned short *src, unsigned short count);
#ifdef __cplusplus
}
#endif
#endif
