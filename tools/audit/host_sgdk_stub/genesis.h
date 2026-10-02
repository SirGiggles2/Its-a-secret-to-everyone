/* Host-only SGDK stand-in for tools/audit/host_link_check.py when the SGDK
 * tree (sgdk/inc) is absent, e.g. a Linux cloud session. Types, the
 * constants the Debug.md sources use, and UNPROTOTYPED declarations of the
 * SGDK calls (any arguments; return type only). Never part of a ROM build:
 * values here are not checked against SGDK. */
#ifndef STUB_GENESIS_H
#define STUB_GENESIS_H
#include "types.h"
#define BUTTON_UP 0x0001
#define BUTTON_DOWN 0x0002
#define BUTTON_LEFT 0x0004
#define BUTTON_RIGHT 0x0008
#define BUTTON_A 0x0040
#define BUTTON_B 0x0010
#define BUTTON_C 0x0020
#define BUTTON_START 0x0080
#define BUTTON_X 0x0400
#define BUTTON_Y 0x0200
#define BUTTON_Z 0x0100
#define BUTTON_MODE 0x0800
#define JOY_1 0
#define JOY_2 1
#define DMA 1
#define DMA_QUEUE 2
#define CPU 0
#define BG_A 0
#define BG_B 1
#define WINDOW 2
#define PAL0 0
#define PAL1 1
#define PAL2 2
#define PAL3 3
#define TILE_ATTR_FULL(p,pr,fv,fh,i) ((u16)((((pr)&1)<<15)|(((p)&3)<<13)|(((fv)&1)<<12)|(((fh)&1)<<11)|((i)&0x7FF)))
#define TILE_ATTR(p,pr,fv,fh) TILE_ATTR_FULL(p,pr,fv,fh,0)
#define SPRITE_SIZE(w,h) ((((w)-1)<<2)|((h)-1))
#define TILE_USER_INDEX 16
#define HSCROLL_PLANE 0
#define VSCROLL_PLANE 0
#define HSCROLL_TILE 2
#define VSCROLL_COLUMN 1
#define HSCROLL_LINE 3
#define GFX_DATA_PORT 0xC00000
#define GFX_CTRL_PORT 0xC00004
typedef struct { s16 y; union { struct { u8 size; u8 link; }; u16 size_link; }; u16 attribut; s16 x; } VDPSprite;
extern vu32 vtimer;
extern VDPSprite vdpSpriteCache[80];
#define DMA_VRAM 0
#define DMA_CRAM 1
#define DMA_VSRAM 2
#define VDP_WINDOW 2
/* SGDK calls used by the sources (unprototyped on purpose). */
void DMA_doDma(); void DMA_doVRamCopy(); void DMA_doVRamFill();
bool DMA_queueDma(); bool DMA_queueDmaFast(); void DMA_waitCompletion();
u16  JOY_readJoypad();
void SRAM_disable(); void SRAM_enable(); void SRAM_enableRO();
u8   SRAM_readByte(); void SRAM_writeByte();
void SYS_disableInts(); void SYS_enableInts(); void SYS_doVBlankProcess();
void SYS_setVIntCallback();
void VDP_clearTileMapRect(); void VDP_fillTileData(); u16 VDP_getWindowAddress();
void VDP_loadTileData(); void VDP_setBGAAddress(); void VDP_setBGBAddress();
void VDP_setHScrollTableAddress(); void VDP_setHorizontalScroll();
void VDP_setHorizontalScrollVSync(); void VDP_setPlaneSize();
void VDP_setScreenWidth256(); void VDP_setScrollingMode(); void VDP_setSpriteFull();
void VDP_setSpriteListAddress(); void VDP_setSpritePosition(); void VDP_setTileMapXY();
void VDP_setVerticalScroll(); void VDP_setVerticalScrollVSync();
void VDP_setWindowAddress(); void VDP_setWindowOnBottom(); void VDP_setWindowOnTop();
void VDP_updateSprites();
extern u16 windowWidth; extern u16 windowWidthSft;
#endif
