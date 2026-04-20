/* genesis.ld — Stage-2a linker script.
 *
 * Replaces vasm -Fbin flat-output with a real link stage. Pins the
 * three named sections from src/genesis_shell.asm into the Genesis ROM
 * address map. The output goes through m68k-elf-objcopy -O binary to
 * produce the raw ROM image; fix_checksum.py then pads + patches the
 * ROM header.
 *
 * Memory map (matches the project's current layout):
 *   ROM: $000000-$3FFFFF (4 MB)
 *     $000000-$0000FF  vectors  — 68K exception vector table
 *     $000100-$0001FF  header   — Genesis ROM header (name, checksum, etc.)
 *     $000200+         text     — boot code, transpiled banks, shims
 *
 *   RAM: $FFC000-$FFDFFF (8 KB) — C .bss / COMMON, placed ABOVE the
 *     bank window at $FF8000-$FFBFFF (see nes_io.asm:167) and BELOW
 *     the M68K stack at $FFFFFE (genesis_shell.asm:21 STACK_TOP).
 *     NES RAM shadow at $FF0000-$FF08FF is OWNED by transpiled code;
 *     C globals must not land there.
 *
 * Entry symbol is EntryPoint (src/genesis_shell.asm:186). _start is NOT
 * defined in this project.
 */

OUTPUT_FORMAT("elf32-m68k")
ENTRY(EntryPoint)

MEMORY {
    rom (rx)  : ORIGIN = 0x000000, LENGTH = 0x400000
    ram (rwx) : ORIGIN = 0xFFC000, LENGTH = 0x002000
}

SECTIONS {
    .vectors 0x000000 : {
        KEEP(*(vectors))
        KEEP(*(.vectors))
    } > rom

    .header  0x000100 : {
        KEEP(*(header))
        KEEP(*(.header))
    } > rom

    .text    0x000200 : {
        *(text)
        *(.text*)
        *(.rodata*)
    } > rom

    .bss : {
        *(.bss*)
        *(COMMON)
    } > ram

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
