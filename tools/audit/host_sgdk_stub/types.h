/* Host-only SGDK stand-in (see genesis.h). */
#ifndef STUB_TYPES_H
#define STUB_TYPES_H
typedef unsigned char u8; typedef signed char s8;
typedef unsigned short u16; typedef signed short s16;
typedef unsigned int u32; typedef signed int s32;   /* 32-bit as on m68k */
typedef volatile u8 vu8; typedef volatile u16 vu16; typedef volatile u32 vu32;
typedef unsigned char bool;
#define TRUE 1
#define FALSE 0
#ifndef NULL
#define NULL ((void*)0)
#endif
typedef s16 fix16; typedef s32 fix32;
#endif
