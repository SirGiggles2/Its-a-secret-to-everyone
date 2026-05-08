    .text
    .globl main
    .globl combined_debug_set_a4
    .globl combined_debug_get_a4
    .globl combined_debug_main_after_a4

main:
    lea 0x00FF8000,%a4
    jmp combined_debug_main_after_a4

combined_debug_set_a4:
    lea 0x00FF8000,%a4
    rts

combined_debug_get_a4:
    move.l %a4,%d0
    rts
