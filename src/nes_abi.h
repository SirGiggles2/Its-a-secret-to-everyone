/* nes_abi.h — minimal C-side interface to the NES-RAM shadow region
 * that transpiled asm uses via A4-relative addressing.
 *
 * The boot shell (src/genesis_shell.asm near line 354) loads
 *     lea     (NES_RAM_BASE).l,A4       ; $FF0000
 * before any C function runs. All C translation units are compiled
 * with -ffixed-a4, which reserves A4 globally so gcc never clobbers
 * it. The net effect: `nes_ram[offset]` compiles to `move.b (off,A4)`
 * — the same addressing mode the transpiled asm uses.
 *
 * No stdint.h (SGDK vendored toolchain ships no GCC builtin headers).
 * Primitive C types on m68k-elf:
 *   unsigned char  8
 *   unsigned short 16
 *   unsigned int   32
 *   unsigned long  32
 */
#ifndef NES_ABI_H
#define NES_ABI_H

#ifdef __cplusplus
extern "C" {
#endif

register volatile unsigned char *nes_ram asm("a4");

#define RAM(off) (nes_ram[(off)])

/* Slot-indexed accessor: NES RAM offsets are often base + slot (with
 * slot 0..11 for objects). Same encoding as transpiled `(off,A4,D2.W)`.
 */
#define OBJ(off, slot) (nes_ram[(off) + (slot)])

/* NES-RAM offsets used by the walker / MoveObject path. Kept in one
 * place so a bank migration or data-layout change only edits here.
 * Values match the asm comments at tools/transpile_6502.py:5260-5269
 * and the P48 body below it.
 */
#define NES_OBJ_DIR         0x000F
#define NES_POS_GRID_LIMIT  0x010E
#define NES_NEG_GRID_LIMIT  0x010F
#define NES_OBJ_X           0x0070
#define NES_OBJ_Y           0x0084
#define NES_OBJ_GRID_OFFSET 0x0394
#define NES_OBJ_POS_FRAC    0x03A8
#define NES_OBJ_QSPD_FRAC   0x03BC

#ifdef __cplusplus
}
#endif

#endif /* NES_ABI_H */
