/* c_runtime.c — Stage 2b smoke-test C translation unit.
 *
 * Proves the m68k-elf-gcc toolchain integration works end-to-end:
 * vasm assembles the shell, gcc compiles this, ld links both into
 * one ELF, objcopy flattens to ROM.
 *
 * The counter lives in .bss — linker script pins .bss to $FFC000+
 * (above the $FF8000 bank window, below the M68K stack at $FFFFFE).
 * NES RAM at $FF0000-$FF08FF is OFF-LIMITS; the original Stage-2b
 * draft wrote directly to $FF1100 which collides with CTL1_LATCH
 * (nes_io.asm:1776). This version lets the linker choose the
 * address so the collision can't come back.
 *
 * stdint.h intentionally NOT included — the vendored SGDK toolchain
 * omits GCC builtin headers. Types are declared inline; on m68k-elf
 * unsigned int is 32 bits.
 */

#include "c_runtime.h"

volatile unsigned int c_probe_counter;

void c_probe_tick(void) {
    c_probe_counter += 1;
}
