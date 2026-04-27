/* intro_demo.ld — minimal Genesis link script for standalone story demo. */

OUTPUT_FORMAT("elf32-m68k")
ENTRY(EntryPoint)

MEMORY {
    rom (rx)  : ORIGIN = 0x000000, LENGTH = 0x080000
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
